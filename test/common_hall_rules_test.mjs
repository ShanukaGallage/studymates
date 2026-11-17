import assert from 'node:assert/strict';

const project = 'studymates-dev';
const host = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
assert.match(host, /^(127\.0\.0\.1|localhost):\d+$/);
const root = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const name = path => `projects/${project}/databases/(default)/documents/${path}`;
const run = crypto.randomUUID();
const fields = data => Object.fromEntries(Object.entries(data).map(([key, value]) => [key,
  value instanceof Date ? {timestampValue: value.toISOString()} : typeof value === 'boolean' ? {booleanValue: value} : typeof value === 'number' ? {integerValue: String(value)} : {stringValue: value}]));
function write(path, data, serverFields = []) {
  return {update: {name: name(path), fields: fields(data)}, ...(serverFields.length ? {updateTransforms: serverFields.map(fieldPath => ({fieldPath, setToServerValue: 'REQUEST_TIME'}))} : {})};
}
function patch(path, data, serverFields = []) { return {...write(path, data, serverFields), updateMask: {fieldPaths: Object.keys(data)}}; }
const remove = path => ({delete: name(path)});
async function request(path, token, body) {
  const response = await fetch(path, {method: body ? 'POST' : 'GET', headers: {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json'}, ...(body ? {body: JSON.stringify(body)} : {})});
  return {status: response.status, body: await response.json()};
}
async function commit(token, writes) { return request(`${root}:commit`, token, {writes}); }
async function allow(label, token, writes) { const result = await commit(token, writes); assert.equal(result.status, 200, `${label}: ${JSON.stringify(result.body)}`); console.log('PASS', label); }
async function deny(label, token, writes) { const result = await commit(token, writes); assert.equal(result.status, 403, `${label}: ${JSON.stringify(result.body)}`); console.log('PASS', label); }
async function user(label) {
  const response = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({email:`hall-${label}-${run}@example.test`, password:'hall-rules-test', returnSecureToken:true})});
  const data = await response.json(); assert.equal(response.status, 200); return {uid:data.localId, token:data.idToken};
}
const a = await user('a'), b = await user('b');
const active = uid => `users/${uid}/hallSession/current`;
const present = uid => `commonHallPresence/${uid}`;
const id = `hall-${run}`;
const entry = (u, session = id) => [
  write(active(u.uid), {userId:u.uid, sessionId:session, goalText:'Self study'}, ['startsAt', 'confirmedAt']),
  write(present(u.uid), {userId:u.uid, sessionId:session, displayName:u.uid, avatarId:'default'}, ['joinedAt', 'lastSeenAt']),
];
await allow('seed private test profiles', 'owner', [a,b].map(u => write(`users/${u.uid}`, {displayName:u.uid, avatarId:'default'})));
await deny('hall entry must create its desk atomically', a.token, [entry(a)[0]]);
await deny('desk requires a real private session', a.token, [entry(a)[1]]);
await allow('authenticated user enters one hall desk', a.token, entry(a));
await deny('same user cannot reset its study start', a.token, entry(a, `hall-reset-${run}`));
assert.equal((await request(`${root}/${present(a.uid)}`, b.token)).status, 200);
assert.equal((await request(`${root}/${active(a.uid)}`, b.token)).status, 403);
console.log('PASS other members see the desk, never private timing or goal');
await deny('another user cannot renew a desk', b.token, [patch(active(a.uid), {}, ['confirmedAt']), patch(present(a.uid), {}, ['lastSeenAt'])]);
await deny('unpaired heartbeat rejected', a.token, [patch(active(a.uid), {}, ['confirmedAt'])]);
await allow('paired server-time heartbeat', a.token, [patch(active(a.uid), {}, ['confirmedAt']), patch(present(a.uid), {}, ['lastSeenAt'])]);
await deny('another user cannot remove a desk', b.token, [remove(present(a.uid))]);

const sg = `hall-sg-${run}`, sig = `hall-sig-${run}`, room = `hall-room-${run}`;
const roomPath = `subgroups/${sg}/rooms/${room}`;
await allow('seed independent room eligibility', 'owner', [
  write(`sigs/${sig}`, {ownerId:a.uid,status:'active',membershipRevision:0}),
  write(`subgroups/${sg}`, {sigId:sig,status:'active',name:'Hall rules topic'}),
  ...[a,b].flatMap(u => [write(`sigs/${sig}/members/${u.uid}`,{userId:u.uid,sigId:sig,status:'active'}),write(`subgroups/${sg}/members/${u.uid}`,{userId:u.uid,sigId:sig,status:'active'})]),
  write(roomPath,{roomId:room,subgroupId:sg,sigId:sig,title:'Room',createdBy:a.uid,hostUid:a.uid,status:'waiting'},['createdAt','updatedAt']),
  write(`${roomPath}/seats/seat-1`, {seatId:'seat-1',status:'available'}),
]);
function claim(u) {
  const expiry = new Date(Date.now()+115000);
  return [write(`${roomPath}/seats/seat-1`, {seatId:'seat-1',status:'occupied',userId:u.uid,claimId:run,leaseExpiresAt:expiry,displayName:u.uid,avatarId:'default'}, ['claimedAt','lastRenewedAt']),write(`activeSeatClaims/${u.uid}`,{userId:u.uid,subgroupId:sg,roomId:room,seatId:'seat-1',claimId:run,leaseExpiresAt:expiry})];
}
await deny('hall study prevents taking a room seat', a.token, claim(a));
await allow('a different user can take the room seat', b.token, claim(b));
await deny('room seat prevents hall entry', b.token, entry(b, `hall-b-${run}`));

// Seed exact elapsed boundaries only through the local emulator admin fixture.
const confirmed = new Date(Date.now()-30000);
const start = new Date(confirmed.getTime()-8400*1000); // 2h20m elapsed = 2h focus.
await allow('seed confirmed 25/5 timing boundaries', 'owner', [
  patch(active(a.uid), {startsAt:start,confirmedAt:confirmed}),
  patch(present(a.uid), {joinedAt:start,lastSeenAt:confirmed}),
]);
const completion = {recordId:id,sessionId:id,userId:a.uid,goalText:'Self study',creditedSeconds:7200,timerStatus:'completed',goalOutcome:'completed',isDemo:false};
const completionPath = `users/${a.uid}/completions/${id}`;
const finish = data => [write(completionPath,data,['endedAt']),remove(active(a.uid)),remove(present(a.uid))];
await deny('break minutes cannot be credited', a.token, finish({...completion,creditedSeconds:8400}));
await deny('credit cannot exceed confirmed focus time', a.token, finish({...completion,creditedSeconds:7201}));
await deny('cannot change hall records into demo data', a.token, finish({...completion,isDemo:true}));
await deny('cannot erase active session without saving', a.token, [remove(active(a.uid)),remove(present(a.uid))]);
await allow('finish atomically saves normal focus time and removes desk', a.token, finish(completion));
await deny('cannot duplicate or overwrite completion', a.token, [write(completionPath,completion,['endedAt'])]);
assert.equal((await request(`${root}/${present(a.uid)}`, a.token)).status,404);
assert.equal((await request(`${root}/${active(a.uid)}`, a.token)).status,404);

const old = new Date(Date.now()-240000), stale = `hall-stale-${run}`;
await allow('seed expired isolated activity', 'owner', [
  write(active(a.uid),{userId:a.uid,sessionId:stale,goalText:'Self study',startsAt:new Date(old.getTime()-1800*1000),confirmedAt:old}),
  write(present(a.uid),{userId:a.uid,sessionId:stale,displayName:a.uid,avatarId:'default',joinedAt:new Date(old.getTime()-1800*1000),lastSeenAt:old}),
]);
await deny('expired session cannot renew across offline hours', a.token, [patch(active(a.uid),{},['confirmedAt']),patch(present(a.uid),{},['lastSeenAt'])]);
await allow('expired session saves only its confirmed 25 minutes', a.token, [
  write(`users/${a.uid}/completions/${stale}`, {...completion,recordId:stale,sessionId:stale,creditedSeconds:1500},['endedAt']),remove(active(a.uid)),remove(present(a.uid)),
]);
console.log('All Common Hall security checks passed');
