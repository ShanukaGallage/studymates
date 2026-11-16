import assert from 'node:assert/strict';

const projectId = 'studymates-dev';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
const authUrl = `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`;
const firestoreUrl = `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents`;
const documentName = (path) => `projects/${projectId}/databases/(default)/documents/${path}`;
const now = new Date().toISOString();

function value(value) {
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number') return { integerValue: String(value) };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  throw new TypeError(`Unsupported Firestore test value: ${value}`);
}

function fields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, entry]) => [key, value(entry)]));
}

function update(path, data, mask = Object.keys(data), exists = true) {
  return {
    update: { name: documentName(path), fields: fields(data) },
    updateMask: { fieldPaths: mask },
    currentDocument: { exists },
  };
}

async function request(url, { token, method = 'GET', body } = {}) {
  const response = await fetch(url, {
    method,
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const payload = await response.json().catch(() => null);
  return { response, payload };
}

async function createUser(label) {
  const { response, payload } = await request(authUrl, {
    method: 'POST',
    body: {
      email: `${label}-${crypto.randomUUID()}@example.test`,
      password: 'membership-rules-test-password',
      returnSecureToken: true,
    },
  });
  assert.equal(response.status, 200, JSON.stringify(payload));
  return { uid: payload.localId, token: payload.idToken };
}

async function commit(token, writes) {
  return request(`${firestoreUrl}:commit`, {
    token,
    method: 'POST',
    body: { writes },
  });
}

async function mustAllow(label, token, writes) {
  const { response, payload } = await commit(token, writes);
  assert.equal(response.status, 200, `${label} should be allowed: ${JSON.stringify(payload)}`);
  console.log(`PASS ${label}`);
}

async function mustDeny(label, token, writes) {
  const { response, payload } = await commit(token, writes);
  assert.equal(response.status, 403, `${label} should be denied: ${JSON.stringify(payload)}`);
  console.log(`PASS ${label}`);
}

async function runMembershipRulesTests() {
const runId = crypto.randomUUID();
const sigId = `sig-revision-test-${runId}`;
const subgroupId = `group-revision-test-${runId}`;
const owner = await createUser('owner');
const member = await createUser('member');
const successor = await createUser('successor');
const sigPath = `sigs/${sigId}`;
const memberPath = `${sigPath}/members/${member.uid}`;
const requestId = `membership-leave-${crypto.randomUUID()}`;
const requestPath = `membershipCleanupRequests/${requestId}`;
const membership = {
  userId: member.uid,
  sigId,
  status: 'active',
  joinedAt: new Date(),
  updatedAt: new Date(),
};

await mustDeny('clients cannot write room seat documents directly', member.token, [
  {
    update: {
      name: documentName(
        `subgroups/${subgroupId}/rooms/room-${runId}/seats/seat-1`,
      ),
      fields: fields({ clientProbe: runId }),
    },
    currentDocument: { exists: false },
  },
]);

await mustDeny('clients cannot write active seat claim locators directly', member.token, [
  {
    update: {
      name: documentName(`activeSeatClaims/${member.uid}`),
      fields: fields({ clientProbe: runId }),
    },
    currentDocument: { exists: false },
  },
]);

await mustAllow('SIG owner initializes revision zero', owner.token, [
  {
    update: {
      name: documentName(sigPath),
      fields: fields({
        ownerId: owner.uid,
        status: 'active',
        membershipRevision: 0,
      }),
    },
    currentDocument: { exists: false },
  },
]);

await mustDeny('membership cannot change SIG revision without a membership transition', member.token, [
  update(sigPath, { membershipRevision: 1 }),
]);

await mustDeny('membership creation without revision increment is denied', member.token, [
  {
    update: {
      name: documentName(memberPath),
      fields: fields(membership),
    },
    currentDocument: { exists: false },
  },
]);

await mustAllow('membership creation with revision increment is permitted', member.token, [
  update(sigPath, { membershipRevision: 1 }),
  {
    update: {
      name: documentName(memberPath),
      fields: fields(membership),
    },
    currentDocument: { exists: false },
  },
]);

const pendingMembership = {
  status: 'removalPending',
  updatedAt: new Date(),
  removalRequestId: requestId,
};
const cleanupRequest = {
  requestId,
  userId: member.uid,
  sigId,
  scope: 'sig',
  status: 'pending',
  createdAt: new Date(),
  updatedAt: new Date(),
};

await mustDeny('membership status change without revision increment is denied', member.token, [
  update(memberPath, pendingMembership),
  {
    update: {
      name: documentName(requestPath),
      fields: fields(cleanupRequest),
    },
    currentDocument: { exists: false },
  },
]);

await mustAllow('valid pending removal increments the revision atomically', member.token, [
  update(sigPath, { membershipRevision: 2 }),
  update(memberPath, pendingMembership),
  {
    update: {
      name: documentName(requestPath),
      fields: fields(cleanupRequest),
    },
    currentDocument: { exists: false },
  },
]);

await mustDeny('client cannot acknowledge cleanup with an unverified client timestamp', member.token, [
  update(requestPath, { status: 'completed', updatedAt: new Date() }),
]);

function cleanupAck() {
 return {update:{name:documentName(requestPath),fields:fields({status:'completed'})},
  updateMask:{fieldPaths:['status']}, updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]};
}
await mustAllow('seed active seat cleanup safety guard','owner', [{update:{name:documentName(`activeSeatClaims/${member.uid}`),fields:fields({userId:member.uid})}}]);
await mustDeny('own cleanup acknowledgement blocked while seat remains',member.token,[cleanupAck()]);
await mustAllow('remove active seat safety fixture','owner',[{delete:documentName(`activeSeatClaims/${member.uid}`)}]);
await mustAllow('seed active participation cleanup safety guard','owner',[{update:{name:documentName(`users/${member.uid}/activeSession/current`),fields:fields({userId:member.uid})}}]);
await mustDeny('own cleanup acknowledgement blocked while participation remains',member.token,[cleanupAck()]);
await mustAllow('remove participation safety fixture','owner',[{delete:documentName(`users/${member.uid}/activeSession/current`)}]);
await mustDeny('another account cannot acknowledge the leave request',successor.token,[cleanupAck()]);
await mustAllow('Spark self-service acknowledgement after verified self cleanup',member.token,[cleanupAck()]);

await mustAllow('trusted cleanup handler can acknowledge the same request', 'owner', [
  update(requestPath, { status: 'completed', updatedAt: new Date() }),
]);

await mustDeny('final membership removal also requires a revision increment', member.token, [
  update(memberPath, {
    status: 'left',
    updatedAt: new Date(),
    removalRequestId: requestId,
  }),
]);

await mustAllow('acknowledged membership removal with revision increment is permitted', member.token, [
  update(sigPath, { membershipRevision: 3 }),
  update(memberPath, {
    status: 'left',
    updatedAt: new Date(),
    removalRequestId: requestId,
  }),
]);

const successorMembershipPath = `${sigPath}/members/${successor.uid}`;
await mustAllow('concurrent eligible join advances the owner-selection revision', successor.token, [
  update(sigPath, { membershipRevision: 4 }),
  {
    update: {
      name: documentName(successorMembershipPath),
      fields: fields({ ...membership, userId: successor.uid, status: 'active' }),
    },
    currentDocument: { exists: false },
  },
]);

const subgroupPath = `subgroups/${subgroupId}`;
const successorSubgroupMembershipPath = `${subgroupPath}/members/${successor.uid}`;
await mustAllow('SIG owner creates a subgroup for membership authorization tests', owner.token, [
  {
    update: {
      name: documentName(subgroupPath),
      fields: fields({ sigId, status: 'active' }),
    },
    currentDocument: { exists: false },
  },
]);
await mustAllow('active SIG member joins the subgroup', successor.token, [
  {
    update: {
      name: documentName(successorSubgroupMembershipPath),
      fields: fields({
        userId: successor.uid,
        sigId,
        status: 'active',
        joinedAt: new Date(),
        updatedAt: new Date(),
      }),
    },
    currentDocument: { exists: false },
  },
]);
await mustDeny('User A cannot modify User B SIG membership', member.token, [
  update(successorMembershipPath, {
    status: 'left',
    updatedAt: new Date(),
  }),
]);
await mustDeny('User A cannot modify User B subgroup membership', member.token, [
  update(successorSubgroupMembershipPath, {
    status: 'left',
    updatedAt: new Date(),
  }),
]);

const ownerTransferRequestId = `owner-transfer-${crypto.randomUUID()}`;
const ownerTransferRequestPath = `membershipCleanupRequests/${ownerTransferRequestId}`;
const ownerPending = {
  userId: owner.uid,
  sigId,
  status: 'removalPending',
  joinedAt: new Date(),
  updatedAt: new Date(),
  removalRequestId: ownerTransferRequestId,
};
const ownerTransferRequest = {
  requestId: ownerTransferRequestId,
  userId: owner.uid,
  sigId,
  scope: 'sig',
  status: 'pending',
  createdAt: new Date(),
  updatedAt: new Date(),
};

await mustAllow('owner transfer remains atomic with pending membership and request', owner.token, [
  update(sigPath, {
    ownerId: successor.uid,
    membershipRevision: 5,
  }, ['ownerId', 'membershipRevision']),
  {
    update: {
      name: documentName(`${sigPath}/members/${owner.uid}`),
      fields: fields(ownerPending),
    },
    currentDocument: { exists: false },
  },
  {
    update: {
      name: documentName(ownerTransferRequestPath),
      fields: fields(ownerTransferRequest),
    },
    currentDocument: { exists: false },
  },
]);

const closeRequestId = `owner-close-${crypto.randomUUID()}`;
await mustAllow('owner closure with no successor remains atomic', successor.token, [
  update(sigPath, {
    status: 'closed',
    membershipRevision: 6,
  }, ['status', 'membershipRevision']),
  update(successorMembershipPath, {
    status: 'removalPending',
    updatedAt: new Date(),
    removalRequestId: closeRequestId,
  }),
  {
    update: {
      name: documentName(`membershipCleanupRequests/${closeRequestId}`),
      fields: fields({
        requestId: closeRequestId,
        userId: successor.uid,
        sigId,
        scope: 'sig',
        status: 'pending',
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    },
    currentDocument: { exists: false },
  },
]);

}

runMembershipRulesTests().catch((error) => {
  console.error(error);
  // Let pending I/O handles close normally instead of forcing process exit.
  process.exitCode = 1;
});
