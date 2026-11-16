import assert from 'node:assert/strict';

const project = 'studymates-dev';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const root = `http://${firestoreHost}/v1/projects/${project}/databases/(default)/documents`;
const name = path => `projects/${project}/databases/(default)/documents/${path}`;
const run = crypto.randomUUID();

function values(data) {
  return Object.fromEntries(Object.entries(data).map(([key, value]) => [
    key,
    value instanceof Date ? { timestampValue: value.toISOString() }
      : typeof value === 'boolean' ? { booleanValue: value }
      : typeof value === 'number' ? { integerValue: String(value) }
      : { stringValue: value },
  ]));
}

function write(path, data, serverFields = []) {
  return {
    update: { name: name(path), fields: values(data) },
    ...(serverFields.length
      ? { updateTransforms: serverFields.map(fieldPath => ({
          fieldPath, setToServerValue: 'REQUEST_TIME',
        })) }
      : {}),
  };
}

function patch(path, data, serverFields = []) {
  return {
    ...write(path, data, serverFields),
    updateMask: { fieldPaths: Object.keys(data) },
  };
}

async function request(url, token, method = 'GET', body) {
  const response = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  return { status: response.status, body: await response.json().catch(() => null) };
}

async function commit(token, writes) {
  return request(`${root}:commit`, token, 'POST', { writes });
}

async function allow(label, token, writes) {
  const result = await commit(token, writes);
  assert.equal(result.status, 200, `${label}: ${JSON.stringify(result.body)}`);
  console.log('PASS', label);
}

async function deny(label, token, writes) {
  const result = await commit(token, writes);
  assert.equal(result.status, 403, `${label}: ${JSON.stringify(result.body)}`);
  console.log('PASS', label);
}

async function user(label) {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: `${label}-${run}@example.test`,
        password: 'study-rules-test',
        returnSecureToken: true,
      }),
    },
  );
  const data = await response.json();
  assert.equal(response.status, 200, JSON.stringify(data));
  return { uid: data.localId, token: data.idToken };
}

const a = await user('a');
const b = await user('b');
const outsider = await user('outside');
const subgroupId = `sg-${run}`;
const sigId = `sig-${run}`;
const roomId = `room-${run}`;
const roomPath = `subgroups/${subgroupId}/rooms/${roomId}`;
const seatPath = `${roomPath}/seats/seat-1`;
const claimPath = uid => `activeSeatClaims/${uid}`;

// Emulator-owner writes seed state; clients must use trusted callables for rooms and seats.
await allow('seed authorized memberships', 'owner', [
  write(`sigs/${sigId}`, { ownerId: a.uid, status: 'active', membershipRevision: 0 }),
  write(`subgroups/${subgroupId}`, { sigId, status: 'active', name: 'Rules topic' }),
  ...[a, b].flatMap(account => [
    write(`sigs/${sigId}/members/${account.uid}`, {
      userId: account.uid, sigId, status: 'active',
    }),
    write(`subgroups/${subgroupId}/members/${account.uid}`, {
      userId: account.uid, sigId, status: 'active',
    }),
  ]),
  ...[a, b, outsider].map(account =>
    write(`users/${account.uid}`, { displayName: account.uid, avatarId: 'default' }),
  ),
]);

const roomWrites = [
  write(roomPath, {
    roomId, subgroupId, sigId, title: 'Rules room',
    createdBy: a.uid, hostUid: a.uid, status: 'waiting',
  }, ['createdAt', 'updatedAt']),
  write(`roomDirectory/${roomId}`, { subgroupId, sigId }),
  ...Array.from({ length: 6 }, (_, index) =>
    write(`${roomPath}/seats/seat-${index + 1}`, {
      seatId: `seat-${index + 1}`, status: 'available',
    }),
  ),
];
await deny('non-member cannot create a room', outsider.token, roomWrites);
await deny('member client room creation is server-only', a.token, roomWrites);
await allow('emulator seeds room and six seats', 'owner', roomWrites);
await deny('client room-directory creation is denied', a.token, [
  write(`roomDirectory/${roomId}-client`, { subgroupId, sigId }),
]);

function claim(account, claimId = 'claim-a', seatId = 'seat-1') {
  const leaseExpiresAt = new Date(Date.now() + 115000);
  return [
    write(`${roomPath}/seats/${seatId}`, {
      seatId, status: 'occupied', userId: account.uid, claimId,
      leaseExpiresAt, displayName: account.uid, avatarId: 'default',
    }, ['claimedAt', 'lastRenewedAt']),
    write(claimPath(account.uid), {
      userId: account.uid, subgroupId, roomId, seatId, claimId, leaseExpiresAt,
    }),
  ];
}

await deny('paired client seat and claim writes are server-only', a.token, claim(a));
await deny('client seat creation is denied', a.token, [claim(a, 'claim-a', 'seat-7')[0]]);
await deny('client seat update is denied', a.token, [claim(a)[0]]);
await deny('client active-claim creation is denied', a.token, [claim(a)[1]]);
await deny('another learner cannot steal a seat', b.token, claim(b, 'claim-b'));
await deny('same user cannot claim a second seat from a client', a.token, claim(a, 'claim-second', 'seat-2'));
await deny('arbitrary lease extension is denied', a.token, [
  write(seatPath, {
    seatId: 'seat-1', status: 'occupied', userId: a.uid, claimId: 'claim-a',
    leaseExpiresAt: new Date(Date.now() + 9999999), displayName: a.uid, avatarId: 'default',
  }, ['claimedAt', 'lastRenewedAt']),
]);
await deny('client release and claim deletion are server-only', a.token, [
  write(seatPath, { seatId: 'seat-1', status: 'available' }),
  { delete: name(claimPath(a.uid)) },
]);

const closedRoomId = `closed-${run}`;
const closedRoomPath = `subgroups/${subgroupId}/rooms/${closedRoomId}`;
await allow('seed closed room fixture', 'owner', [
  write(closedRoomPath, {
    roomId: closedRoomId, subgroupId, sigId, title: 'Closed room',
    createdBy: a.uid, hostUid: a.uid, status: 'closed',
  }, ['createdAt', 'updatedAt']),
]);
await deny('closed room cannot be reopened by its host', a.token, [
  patch(closedRoomPath, { status: 'active', sessionId: `reopen-${run}` }, ['updatedAt']),
]);

// Seed a valid occupied seat and paired claim for the session-rule checks below.
await allow('emulator seeds paired seat claim', 'owner', claim(a, 'session-claim'));
assert.notEqual((await request(`${root}/${roomPath}/seats/seat-2`, a.token)).status, 403);
assert.notEqual((await request(`${root}/roomDirectory/${roomId}`, a.token)).status, 403);
assert.notEqual((await request(`${root}/${claimPath(a.uid)}`, a.token)).status, 403);
assert.equal((await request(`${root}/${claimPath(a.uid)}`, b.token)).status, 403);
console.log('PASS discovery reads remain available and claim markers remain private');

await deny('fabricated completion is denied', a.token, [
  write(`users/${a.uid}/completions/fake`, {
    recordId: 'fake', userId: a.uid, sessionId: 'fake', goalText: 'fake',
    creditedSeconds: 99999, timerStatus: 'completed',
    goalOutcome: 'completed', isDemo: false,
  }, ['endedAt']),
]);
await deny('private history is not writable by another user', b.token, [
  write(`users/${a.uid}/completions/fake`, { userId: a.uid }),
]);

const sessionId = `session-${run}`;
const activePath = `users/${a.uid}/activeSession/current`;
await allow('host starts immutable shared demo with own participation', a.token, [
  write(`roomSessions/${sessionId}`, {
    sessionId, roomId, subgroupId, hostUid: a.uid,
    roomTitle: 'Rules room', isDemo: true,
  }, ['startsAt']),
  patch(roomPath, { sessionId, status: 'active' }, ['updatedAt']),
  write(activePath, {
    sessionId, roomId, subgroupId, seatId: 'seat-1',
    claimId: 'session-claim', userId: a.uid, goalText: 'Finish one task',
  }, ['joinedAt']),
]);
await deny('active participation prevents client seat release', a.token, [
  write(seatPath, { seatId: 'seat-1', status: 'available' }),
  { delete: name(claimPath(a.uid)) },
]);

const completion = {
  recordId: sessionId, sessionId, userId: a.uid,
  goalText: 'Finish one task', creditedSeconds: 0, timerStatus: 'endedEarly',
  goalOutcome: 'unfinished', isDemo: true,
};
const completionPath = `users/${a.uid}/completions/${sessionId}`;
await deny('inflated session credit is rejected', a.token, [
  write(completionPath, { ...completion, creditedSeconds: 99999 }, ['endedAt']),
  { delete: name(activePath) },
]);
await deny('demo cannot become normal progress', a.token, [
  write(completionPath, { ...completion, isDemo: false }, ['endedAt']),
  { delete: name(activePath) },
]);
await deny('early exit cannot claim a completed timer', a.token, [
  write(completionPath, { ...completion, timerStatus: 'completed' }, ['endedAt']),
  { delete: name(activePath) },
]);
await allow('completion and participation removal commit together', a.token, [
  write(completionPath, completion, ['endedAt']),
  { delete: name(activePath) },
]);
await deny('saved completion cannot be overwritten or duplicated', a.token, [
  write(completionPath, completion, ['endedAt']),
]);
await deny('saved participant cannot rejoin the same cycle', a.token, [
  write(activePath, {
    sessionId, roomId, subgroupId, seatId: 'seat-1',
    claimId: 'session-claim', userId: a.uid, goalText: 'Repeat',
  }, ['joinedAt']),
]);
assert.equal((await request(`${root}/${completionPath}`, b.token)).status, 403);
console.log('PASS private completion read rejected');

await deny('client release after saving remains server-only', a.token, [
  write(seatPath, { seatId: 'seat-1', status: 'available' }),
  { delete: name(claimPath(a.uid)) },
]);
const race = await Promise.all([
  commit(a.token, claim(a, 'race-a')),
  commit(b.token, claim(b, 'race-b')),
]);
assert.ok(race.every(result => [403, 409].includes(result.status)));
const unchangedSeat = await request(`${root}/${roomPath}/seats/seat-1`, a.token);
assert.equal(unchangedSeat.body.fields.status.stringValue, 'occupied');
assert.equal(unchangedSeat.body.fields.userId.stringValue, a.uid);
assert.equal(unchangedSeat.body.fields.claimId.stringValue, 'session-claim');
assert.equal((await request(`${root}/${claimPath(a.uid)}`, a.token)).body.fields.claimId.stringValue, 'session-claim');
assert.equal((await request(`${root}/${claimPath(b.uid)}`, b.token)).status, 404);
console.log('PASS concurrent client seat claims are rejected without changing seat or claim state');
console.log('All room, session, completion, and server-only security checks passed');
