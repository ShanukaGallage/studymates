const assert = require('node:assert/strict');
const test = require('node:test');
const { Timestamp } = require('firebase-admin/firestore');

const { createRoomDocument } = require('../lib/create-room-document.js');

function makeFirestore({ createError, documents = {} } = {}) {
  const reads = [];
  const writes = [];
  const roomReference = {
    id: 'auto-generated-room-id',
    path: 'subgroups/subgroup-a/rooms/auto-generated-room-id',
  };
  const transaction = {
    async get(reference) {
      reads.push(reference.path);
      const data = documents[reference.path];
      return { exists: data !== undefined, data: () => data };
    },
    create(reference, data) {
      if (createError) throw createError;
      writes.push({ reference, data });
    },
  };
  const firestore = {
    doc(path) {
      return { path };
    },
    collection(path) {
      assert.equal(path, 'subgroups/subgroup-a/rooms');
      return { doc: () => roomReference };
    },
    async runTransaction(callback) {
      return callback(transaction);
    },
  };
  return { firestore, transaction, roomReference, reads, writes };
}

const request = { subgroupId: 'subgroup-a', title: 'Study room' };
const uid = 'authenticated-user-7';

test('creates and returns a waiting room using the Firestore-generated ID', async () => {
  const context = makeFirestore();
  let eligibilityTransaction;
  const room = await createRoomDocument(
    { firestore: context.firestore, request, uid },
    async (input) => {
      eligibilityTransaction = input.transaction;
      assert.equal(input.firestore, context.firestore);
      assert.equal(input.uid, uid);
      assert.equal(input.subgroupId, request.subgroupId);
      return { sigId: 'sig-a' };
    },
  );

  assert.equal(eligibilityTransaction, context.transaction);
  assert.equal(context.writes.length, 1);
  assert.equal(context.writes[0].reference, context.roomReference);
  assert.equal(
    context.writes[0].reference.path,
    'subgroups/subgroup-a/rooms/auto-generated-room-id',
  );
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
  assert.equal(room.roomId, 'auto-generated-room-id');
  assert.equal(room.subgroupId, request.subgroupId);
  assert.equal(room.title, request.title);
  assert.equal(room.status, 'waiting');
  assert.equal(room.createdAt instanceof Timestamp, true);
  assert.equal(room.updatedAt instanceof Timestamp, true);
  assert.equal(room.createdAt.toMillis(), room.updatedAt.toMillis());
  assert.deepEqual(room, context.writes[0].data);
});

test('sets createdBy and hostUid only from the authenticated UID', async () => {
  const context = makeFirestore();
  const room = await createRoomDocument(
    { firestore: context.firestore, request, uid },
    async () => ({ sigId: 'sig-a' }),
  );

  assert.equal(room.createdBy, uid);
  assert.equal(room.hostUid, uid);
  assert.equal(Object.hasOwn(room, 'userId'), false);
  assert.equal(Object.hasOwn(room, 'hostUidFromRequest'), false);
});

test('default M2 verifier reads membership and creates the room in one transaction', async () => {
  const context = makeFirestore({
    documents: {
      'subgroups/subgroup-a': { sigId: 'sig-a', status: 'active' },
      'sigs/sig-a': { status: 'active', ownerId: 'owner-a' },
      [`sigs/sig-a/members/${uid}`]: {
        userId: uid,
        sigId: 'sig-a',
        status: 'active',
      },
      [`subgroups/subgroup-a/members/${uid}`]: {
        userId: uid,
        sigId: 'sig-a',
        status: 'active',
      },
    },
  });

  await createRoomDocument({ firestore: context.firestore, request, uid });

  assert.deepEqual(context.reads, [
    'subgroups/subgroup-a',
    'sigs/sig-a',
    `sigs/sig-a/members/${uid}`,
    `subgroups/subgroup-a/members/${uid}`,
  ]);
  assert.equal(context.writes.length, 1);
  assert.equal(context.writes[0].reference, context.roomReference);
});

test('does not write when trusted membership verification rejects the user', async () => {
  const context = makeFirestore();
  const failure = new Error('membership-required');

  await assert.rejects(
    createRoomDocument(
      { firestore: context.firestore, request, uid },
      async () => {
        throw failure;
      },
    ),
    failure,
  );
  assert.deepEqual(context.writes, []);
});

test('propagates Firestore transaction write failures', async () => {
  const failure = new Error('transaction write failed');
  const context = makeFirestore({ createError: failure });

  await assert.rejects(
    createRoomDocument(
      { firestore: context.firestore, request, uid },
      async () => ({ sigId: 'sig-a' }),
    ),
    failure,
  );
  assert.deepEqual(context.writes, []);
});

test('rejects invalid identity or room input before starting a transaction', async () => {
  for (const [input, message] of [
    [{ subgroupId: 'bad/path', title: 'Study room' }, /subgroupId/],
    [{ subgroupId: 'subgroup-a', title: '   ' }, /title/],
  ]) {
    const context = makeFirestore();
    await assert.rejects(
      createRoomDocument(
        { firestore: context.firestore, request: input, uid },
        async () => ({ sigId: 'sig-a' }),
      ),
      message,
    );
    assert.deepEqual(context.writes, []);
  }

  const context = makeFirestore();
  await assert.rejects(
    createRoomDocument(
      { firestore: context.firestore, request, uid: '' },
      async () => ({ sigId: 'sig-a' }),
    ),
    /authenticated UID/,
  );
  assert.deepEqual(context.writes, []);
});
