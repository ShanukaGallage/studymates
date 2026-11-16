const assert = require('node:assert/strict');
const test = require('node:test');

const {
  RoomCreationEligibilityError,
  verifyRoomCreationEligibility,
} = require('../lib/room-creation-eligibility.js');

const uid = 'user-1';
const subgroupId = 'subgroup-1';
const sigId = 'sig-1';

function makeTransaction(documents) {
  const reads = [];
  const writes = [];
  const firestore = {
    doc(path) {
      return { path };
    },
  };
  const transaction = {
    async get(reference) {
      reads.push(reference.path);
      const data = documents[reference.path];
      return {
        exists: data !== undefined,
        data: () => data,
      };
    },
    set(...args) {
      writes.push(['set', ...args]);
    },
    update(...args) {
      writes.push(['update', ...args]);
    },
    delete(...args) {
      writes.push(['delete', ...args]);
    },
  };
  return { firestore, transaction, reads, writes };
}

function eligibleDocuments(overrides = {}) {
  return {
    [`subgroups/${subgroupId}`]: {
      sigId,
      status: 'active',
    },
    [`sigs/${sigId}`]: {
      status: 'active',
      ownerId: 'owner-1',
    },
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

function expectEligibilityError(promise, code) {
  return assert.rejects(
    promise,
    (error) =>
      error instanceof RoomCreationEligibilityError && error.code === code,
  );
}

test('allows an active SIG and subgroup member using all four M2 paths', async () => {
  const context = makeTransaction(eligibleDocuments());
  const result = await verifyRoomCreationEligibility({
    ...context,
    uid,
    subgroupId,
  });

  assert.deepEqual(result, { sigId });
  assert.deepEqual(context.reads, [
    `subgroups/${subgroupId}`,
    `sigs/${sigId}`,
    `sigs/${sigId}/members/${uid}`,
    `subgroups/${subgroupId}/members/${uid}`,
  ]);
  assert.deepEqual(context.writes, []);
});

test('allows the SIG owner without a SIG membership document', async () => {
  const documents = eligibleDocuments({
    [`sigs/${sigId}`]: { status: 'active', ownerId: uid },
  });
  delete documents[`sigs/${sigId}/members/${uid}`];
  const context = makeTransaction(documents);

  assert.deepEqual(
    await verifyRoomCreationEligibility({ ...context, uid, subgroupId }),
    { sigId },
  );
  assert.deepEqual(context.writes, []);
});

test('rejects missing or inactive SIG and subgroup documents', async (t) => {
  const cases = [
    ['missing subgroup', {}, 'membership-required'],
    [
      'closed subgroup',
      { [`subgroups/${subgroupId}`]: { sigId, status: 'closed' } },
      'membership-required',
    ],
    ['missing SIG', { [`sigs/${sigId}`]: undefined }, 'membership-required'],
    [
      'closed SIG',
      { [`sigs/${sigId}`]: { status: 'closed', ownerId: 'owner-1' } },
      'membership-required',
    ],
  ];
  for (const [name, overrides, code] of cases) {
    await t.test(name, async () => {
      const documents = eligibleDocuments(overrides);
      if (name === 'missing subgroup') delete documents[`subgroups/${subgroupId}`];
      if (name === 'missing SIG') delete documents[`sigs/${sigId}`];
      const context = makeTransaction(documents);
      await expectEligibilityError(
        verifyRoomCreationEligibility({ ...context, uid, subgroupId }),
        code,
      );
      assert.deepEqual(context.writes, []);
    });
  }
});

test('rejects memberships that are missing, removalPending or left', async (t) => {
  for (const [path, label] of [
    [`sigs/${sigId}/members/${uid}`, 'SIG'],
    [`subgroups/${subgroupId}/members/${uid}`, 'subgroup'],
  ]) {
    for (const status of [undefined, 'removalPending', 'left']) {
      await t.test(`${label} membership status ${status ?? 'missing'}`, async () => {
        const documents = eligibleDocuments();
        if (status === undefined) {
          delete documents[path];
        } else {
          documents[path] = { userId: uid, sigId, status };
        }
        const context = makeTransaction(documents);
        await expectEligibilityError(
          verifyRoomCreationEligibility({ ...context, uid, subgroupId }),
          'membership-required',
        );
        assert.deepEqual(context.writes, []);
      });
    }
  }
});

test('rejects inconsistent subgroup membership and malformed M2 data safely', async (t) => {
  const cases = [
    [
      'membership identity mismatch',
      { [`subgroups/${subgroupId}/members/${uid}`]: { userId: 'other', sigId, status: 'active' } },
    ],
    [
      'membership parent SIG mismatch',
      { [`subgroups/${subgroupId}/members/${uid}`]: { userId: uid, sigId: 'other-sig', status: 'active' } },
    ],
    [
      'subgroup parent SIG missing',
      { [`subgroups/${subgroupId}`]: { status: 'active' } },
    ],
    [
      'invalid membership status',
      { [`subgroups/${subgroupId}/members/${uid}`]: { userId: uid, sigId, status: 'pending' } },
    ],
  ];
  for (const [name, overrides] of cases) {
    await t.test(name, async () => {
      const context = makeTransaction(eligibleDocuments(overrides));
      await expectEligibilityError(
        verifyRoomCreationEligibility({ ...context, uid, subgroupId }),
        'unavailable',
      );
      assert.deepEqual(context.writes, []);
    });
  }
});

test('an owner with an existing removalPending SIG membership is rejected', async () => {
  const context = makeTransaction(
    eligibleDocuments({
      [`sigs/${sigId}`]: { status: 'active', ownerId: uid },
      [`sigs/${sigId}/members/${uid}`]: {
        userId: uid,
        sigId,
        status: 'removalPending',
      },
    }),
  );

  await expectEligibilityError(
    verifyRoomCreationEligibility({ ...context, uid, subgroupId }),
    'membership-required',
  );
  assert.deepEqual(context.writes, []);
});

test('rejects missing authenticated UID and invalid subgroup path segments', async (t) => {
  const context = makeTransaction(eligibleDocuments());
  await t.test('missing UID', async () => {
    await expectEligibilityError(
      verifyRoomCreationEligibility({ ...context, uid: '  ', subgroupId }),
      'unauthenticated',
    );
  });
  await t.test('subgroup ID with slash', async () => {
    await expectEligibilityError(
      verifyRoomCreationEligibility({ ...context, uid, subgroupId: 'x/y' }),
      'invalid-argument',
    );
  });
  assert.deepEqual(context.reads, []);
});