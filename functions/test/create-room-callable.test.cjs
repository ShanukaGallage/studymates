const assert = require('node:assert/strict');
const test = require('node:test');
const { HttpsError } = require('firebase-functions/v2/https');
const { Timestamp } = require('firebase-admin/firestore');

const { createRoomCallableHandler } = require('../lib/create-room-callable.js');

const uid = 'authenticated-user-7';
const subgroupId = 'subgroup-a';
const sigId = 'sig-a';

function makeDocuments(overrides = {}) {
  return {
    [`subgroups/${subgroupId}`]: { sigId, status: 'active' },
    [`sigs/${sigId}`]: { status: 'active', ownerId: 'owner-a' },
    [`sigs/${sigId}/members/${uid}`]: {
      userId: uid,
      sigId,
      status: 'active',
    },
    [`subgroups/${subgroupId}/members/${uid}`]: {
      userId: uid,
      sigId,
      status: 'active',
    },
    ...overrides,
  };
}

function makeFirestore(documents = makeDocuments()) {
  const reads = [];
  const writes = [];
  const roomRef = {
    id: 'generated-room-id',
    path: `subgroups/${subgroupId}/rooms/generated-room-id`,
  };
  const pendingWrites = [];
  const transaction = {
    async get(reference) {
      reads.push(reference.path);
      const data = documents[reference.path];
      return { exists: data !== undefined, data: () => data };
    },
    create(reference, data) {
      pendingWrites.push({ reference, data, transaction });
    },
  };
  const firestore = {
    doc(path) {
      return { path };
    },
    collection(path) {
      assert.equal(path, `subgroups/${subgroupId}/rooms`);
      return { doc: () => roomRef };
    },
    async runTransaction(callback) {
      const result = await callback(transaction);
      writes.push(...pendingWrites);
      return result;
    },
  };
  return { firestore, reads, writes, roomRef, transaction };
}

function callableRequest(data = { subgroupId, title: 'Study room' }, authUid = uid) {
  return {
    data,
    auth: authUid === null ? null : { uid: authUid, token: {} },
  };
}

async function assertCallableError(handler, request, code) {
  await assert.rejects(
    handler(request),
    (error) => error instanceof HttpsError && error.code === code,
  );
}

test('rejects unauthenticated requests before accessing Firestore', async () => {
  const context = makeFirestore();
  await assertCallableError(
    createRoomCallableHandler(context.firestore),
    callableRequest({ subgroupId, title: 'Study room' }, null),
    'unauthenticated',
  );
  assert.deepEqual(context.reads, []);
  assert.deepEqual(context.writes, []);
});

test('rejects missing or invalid subgroup IDs', async (t) => {
  for (const [name, data] of [
    ['missing subgroup ID', { title: 'Study room' }],
    ['empty subgroup ID', { subgroupId: '  ', title: 'Study room' }],
    ['path injection', { subgroupId: 'sig/subgroup', title: 'Study room' }],
  ]) {
    await t.test(name, async () => {
      const context = makeFirestore();
      await assertCallableError(
        createRoomCallableHandler(context.firestore),
        callableRequest(data),
        'invalid-argument',
      );
      assert.deepEqual(context.reads, []);
      assert.deepEqual(context.writes, []);
    });
  }
});

test('rejects missing, empty or invalid titles and unexpected identity fields', async (t) => {
  for (const [name, data] of [
    ['missing title', { subgroupId }],
    ['empty title', { subgroupId, title: '  ' }],
    ['non-string title', { subgroupId, title: 4 }],
    ['client identity', { subgroupId, title: 'Study room', userId: 'forged' }],
  ]) {
    await t.test(name, async () => {
      const context = makeFirestore();
      await assertCallableError(
        createRoomCallableHandler(context.firestore),
        callableRequest(data),
        'invalid-argument',
      );
      assert.deepEqual(context.reads, []);
      assert.deepEqual(context.writes, []);
    });
  }
});

test('rejects missing SIG or subgroup membership without writing documents', async () => {
  const documents = makeDocuments();
  delete documents[`sigs/${sigId}/members/${uid}`];
  const context = makeFirestore(documents);

  await assertCallableError(
    createRoomCallableHandler(context.firestore),
    callableRequest(),
    'permission-denied',
  );
  assert.deepEqual(context.writes, []);
});

test('rejects inactive SIG and subgroup', async (t) => {
  for (const [name, path, data] of [
    ['inactive SIG', `sigs/${sigId}`, { status: 'closed', ownerId: 'owner-a' }],
    [
      'inactive subgroup',
      `subgroups/${subgroupId}`,
      { sigId, status: 'closed' },
    ],
  ]) {
    await t.test(name, async () => {
      const context = makeFirestore(makeDocuments({ [path]: data }));
      await assertCallableError(
        createRoomCallableHandler(context.firestore),
        callableRequest(),
        'permission-denied',
      );
      assert.deepEqual(context.writes, []);
    });
  }
});

test('checks membership against the subgroup actual parent SIG', async () => {
  const documents = makeDocuments({
    [`subgroups/${subgroupId}`]: { sigId: 'sig-b', status: 'active' },
    'sigs/sig-b': { status: 'active', ownerId: 'owner-b' },
  });
  const context = makeFirestore(documents);

  await assertCallableError(
    createRoomCallableHandler(context.firestore),
    callableRequest(),
    'permission-denied',
  );
  assert.ok(context.reads.includes('sigs/sig-b'));
  assert.ok(context.reads.includes(`sigs/sig-b/members/${uid}`));
  assert.deepEqual(context.writes, []);
});

test('rejects removalPending SIG or subgroup membership', async (t) => {
  for (const [name, path] of [
    ['SIG membership', `sigs/${sigId}/members/${uid}`],
    ['subgroup membership', `subgroups/${subgroupId}/members/${uid}`],
  ]) {
    await t.test(name, async () => {
      const context = makeFirestore(
        makeDocuments({
          [path]: { userId: uid, sigId, status: 'removalPending' },
        }),
      );
      await assertCallableError(
        createRoomCallableHandler(context.firestore),
        callableRequest(),
        'permission-denied',
      );
      assert.deepEqual(context.writes, []);
    });
  }
});

test('creates a room and six available seats atomically using authenticated UID', async () => {
  const context = makeFirestore();
  const result = await createRoomCallableHandler(context.firestore)(
    callableRequest({ subgroupId, title: '  Study room  ' }),
  );

  assert.equal(result.roomId, 'generated-room-id');
  assert.equal(result.createdBy, uid);
  assert.equal(result.hostUid, uid);
  assert.equal(context.writes.length, 7);
  assert.deepEqual(context.writes.map(({ reference }) => reference.path), [
    context.roomRef.path,
    ...[1, 2, 3, 4, 5, 6].map(
      (number) => `${context.roomRef.path}/seats/seat-${number}`,
    ),
  ]);
  assert.deepEqual(Object.keys(context.writes[0].data), [
    'roomId',
    'subgroupId',
    'title',
    'createdBy',
    'hostUid',
    'status',
    'createdAt',
    'updatedAt',
  ]);
  assert.equal(context.writes[0].data.createdBy, uid);
  assert.equal(context.writes[0].data.hostUid, uid);
  assert.deepEqual(
    context.writes.slice(1).map(({ data }) => data),
    [1, 2, 3, 4, 5, 6].map((number) => ({
      seatId: `seat-${number}`,
      status: 'available',
      userId: null,
      claimedAt: null,
      leaseExpiresAt: null,
      lastRenewedAt: null,
    })),
  );
  assert.equal(
    context.writes.every(({ transaction }) => transaction === context.transaction),
    true,
  );
  assert.equal(context.writes[0].data.createdAt instanceof Timestamp, true);
});

test('maps unavailable membership verification without exposing internal details', async () => {
  const context = makeFirestore({
    ...makeDocuments(),
    [`subgroups/${subgroupId}`]: { sigId, status: 'active' },
  });
  // A structurally malformed parent document is an unavailable verification.
  context.firestore.runTransaction = async (callback) => {
    const tx = {
      async get(reference) {
        const path = reference.path;
        const data = path === `subgroups/${subgroupId}`
          ? { sigId, status: 'active' }
          : path === `sigs/${sigId}`
            ? { status: 'active' }
            : makeDocuments()[path];
        return { exists: data !== undefined, data: () => data };
      },
      create() {
        throw new Error('must not write');
      },
    };
    return callback(tx);
  };

  await assert.rejects(
    createRoomCallableHandler(context.firestore)(callableRequest()),
    (error) =>
      error instanceof HttpsError &&
      error.code === 'unavailable' &&
      !error.message.includes('ownerId'),
  );
});
