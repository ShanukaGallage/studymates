const assert = require('node:assert/strict');
const { test } = require('node:test');
const admin = require('firebase-admin');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const projectId = process.env.GCLOUD_PROJECT || 'studymates-dev';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5002';
const run = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
const app = admin.initializeApp({ projectId }, `seat-test-${run}`);
const db = getFirestore(app);
const auth = label => fetch(
  `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
  { method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: `${label}-${run}@example.test`, password: 'study-test-password', returnSecureToken: true }) },
).then(async response => {
  const body = await response.json();
  assert.equal(response.status, 200, JSON.stringify(body));
  return { uid: body.localId, token: body.idToken };
});

async function call(name, user, data) {
  const response = await fetch(`http://${functionsHost}/${projectId}/us-central1/${name}`, {
    method: 'POST', headers: { authorization: `Bearer ${user.token}`, 'content-type': 'application/json' },
    body: JSON.stringify({ data }),
  });
  const body = await response.json();
  return { status: response.status, body: body.result ?? body.error };
}

test('callable room and seat operations enforce auth, membership, leases, and ownership', async t => {
  t.after(async () => { await app.delete(); });
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Run with Firestore emulator');
  const [alice, bob, outsider] = await Promise.all([auth('alice'), auth('bob'), auth('outsider')]);
  const noAuth = await fetch(`http://${functionsHost}/${projectId}/us-central1/claimSeat`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ data: { subgroupId: 'missing', roomId: 'missing', seatId: 'seat-1' } }),
  });
  assert.ok([400, 401].includes(noAuth.status));
  const sigId = `sig-${run}`;
  const subgroupId = `sg-${run}`;
  await db.doc(`sigs/${sigId}`).set({ ownerId: `owner-${run}`, status: 'active' });
  await db.doc(`subgroups/${subgroupId}`).set({ sigId, status: 'active' });
  for (const user of [alice, bob]) {
    await db.doc(`users/${user.uid}`).set({ displayName: user.uid, avatarId: 'default' });
    await db.doc(`sigs/${sigId}/members/${user.uid}`).set({ userId: user.uid, sigId, status: 'active' });
    await db.doc(`subgroups/${subgroupId}/members/${user.uid}`).set({ userId: user.uid, sigId, status: 'active' });
  }

  const spoof = await call('createRoom', { ...alice, uid: 'ignored' }, { subgroupId, title: 'Spoof', userId: bob.uid });
  assert.equal(spoof.status, 400);
  const created = await call('createRoom', alice, { subgroupId, title: 'Callable room' });
  assert.equal(created.status, 200, JSON.stringify(created.body));
  const roomId = created.body.roomId;
  const path = `subgroups/${subgroupId}/rooms/${roomId}`;
  assert.equal((await db.doc(path).get()).get('createdBy'), alice.uid);
  assert.equal((await db.doc(`roomDirectory/${roomId}`).get()).exists, true);
  assert.equal((await db.doc(`${path}/seats/seat-6`).get()).exists, true);

  const valid = await call('claimSeat', alice, { subgroupId, roomId, seatId: 'seat-1' });
  assert.equal(valid.status, 200, JSON.stringify(valid.body));
  assert.equal(valid.body.claimedAt < valid.body.leaseExpiresAt, true);
  assert.ok(valid.body.leaseExpiresAt - valid.body.claimedAt <= 120000);
  const markerPath = `activeSeatClaims/${alice.uid}`;
  const marker = await db.doc(markerPath).get();
  assert.equal(marker.get('claimId'), valid.body.claimId);

  assert.equal((await call('claimSeat', bob, { subgroupId, roomId, seatId: 'seat-1' })).status, 429);
  assert.equal((await call('claimSeat', bob, { subgroupId, roomId, seatId: 'seat-2' })).status, 200);
  assert.equal((await call('claimSeat', bob, { subgroupId, roomId, seatId: 'seat-3' })).status, 409);
  assert.equal((await call('releaseSeat', bob, {
    subgroupId, roomId, seatId: 'seat-1', expectedClaimId: valid.body.claimId,
  })).status, 400);
  assert.equal((await call('claimSeat', outsider, { subgroupId, roomId, seatId: 'seat-3' })).status, 403);
  assert.equal((await call('claimSeat', alice, { subgroupId, roomId, seatId: 'seat-4', uid: bob.uid })).status, 400);

  const lease = await call('renewSeat', alice, {
    subgroupId, roomId, seatId: 'seat-1', expectedClaimId: valid.body.claimId,
  });
  assert.equal(lease.status, 200, JSON.stringify(lease.body));
  assert.equal((await db.doc(markerPath).get()).get('leaseExpiresAt').toMillis(), lease.body.leaseExpiresAt);
  const release = await call('releaseSeat', alice, {
    subgroupId, roomId, seatId: 'seat-1', expectedClaimId: valid.body.claimId,
  });
  assert.equal(release.status, 200, JSON.stringify(release.body));
  assert.equal((await db.doc(markerPath).get()).exists, false);
  assert.equal((await db.doc(`${path}/seats/seat-1`).get()).get('status'), 'available');

  await call('releaseSeat', bob, { subgroupId, roomId, seatId: 'seat-2', expectedClaimId: (await db.doc(`activeSeatClaims/${bob.uid}`).get()).get('claimId') });
  const expiredClaim = 'expired-owner-claim';
  const expiredAt = Timestamp.fromMillis(Date.now() - 1000);
  await db.doc(`${path}/seats/seat-2`).set({ seatId: 'seat-2', status: 'occupied', userId: bob.uid, claimId: expiredClaim, leaseExpiresAt: expiredAt });
  await db.doc(`activeSeatClaims/${bob.uid}`).set({ userId: bob.uid, subgroupId, roomId, seatId: 'seat-2', claimId: expiredClaim, leaseExpiresAt: expiredAt });
  const reclaimed = await call('claimSeat', alice, { subgroupId, roomId, seatId: 'seat-2' });
  assert.equal(reclaimed.status, 200, JSON.stringify(reclaimed.body));
  assert.equal((await db.doc(`activeSeatClaims/${bob.uid}`).get()).exists, false);
  await call('releaseSeat', alice, { subgroupId, roomId, seatId: 'seat-2', expectedClaimId: reclaimed.body.claimId });

  const otherSig = `other-sig-${run}`;
  await db.doc(`sigs/${otherSig}`).set({ ownerId: `owner-${run}`, status: 'active' });
  await db.doc(`subgroups/${subgroupId}`).update({ sigId: otherSig });
  assert.equal((await call('claimSeat', alice, { subgroupId, roomId, seatId: 'seat-4' })).status, 403);
  await db.doc(`subgroups/${subgroupId}`).update({ sigId });

  await db.doc(`sigs/${sigId}/members/${bob.uid}`).update({ status: 'left' });
  assert.equal((await call('claimSeat', bob, { subgroupId, roomId, seatId: 'seat-4' })).status, 403);
  await db.doc(`sigs/${sigId}/members/${bob.uid}`).update({ status: 'removalPending' });
  assert.equal((await call('claimSeat', bob, { subgroupId, roomId, seatId: 'seat-4' })).status, 403);
  await db.doc(`subgroups/${subgroupId}`).update({ status: 'closed' });
  assert.equal((await call('claimSeat', alice, { subgroupId, roomId, seatId: 'seat-4' })).status, 403);
  await db.doc(`subgroups/${subgroupId}`).update({ status: 'active' });
  await db.doc(path).update({ status: 'closed' });
  assert.equal((await call('claimSeat', alice, { subgroupId, roomId, seatId: 'seat-4' })).status, 400);

});
