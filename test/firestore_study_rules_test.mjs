import assert from 'node:assert/strict';
const host = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const project = 'studymates-dev';
const root = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const name = path => `projects/${project}/databases/(default)/documents/${path}`;
const run = crypto.randomUUID();
function values(data) { return Object.fromEntries(Object.entries(data).map(([key,value]) => [key,
  value instanceof Date ? {timestampValue:value.toISOString()} : typeof value === 'boolean' ? {booleanValue:value} :
  typeof value === 'number' ? {integerValue:String(value)} : {stringValue:value}])); }
function write(path,data,serverFields=[]) {
 return {update:{name:name(path),fields:values(data)}, ...(serverFields.length ? {updateTransforms:serverFields.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))} : {})};
}
async function request(url,token,method='GET',body) {
 const res=await fetch(url,{method,headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
 return {status:res.status,body:await res.json()};
}
async function commit(token,writes) {return request(`${root}:commit`,token,'POST',{writes});}
async function allow(label,token,writes) {const r=await commit(token,writes); assert.equal(r.status,200,`${label}: ${JSON.stringify(r.body)}`); console.log('PASS',label);}
async function deny(label,token,writes) {const r=await commit(token,writes); assert.equal(r.status,403,`${label}: ${JSON.stringify(r.body)}`); console.log('PASS',label);}
async function user(label) {
 const res=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST||'127.0.0.1:9099'}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:`${label}-${run}@example.test`,password:'study-rules-test',returnSecureToken:true})});
 const data=await res.json();assert.equal(res.status,200,JSON.stringify(data));return {uid:data.localId,token:data.idToken};
}
const a=await user('a'), b=await user('b'), outsider=await user('outside');
const sg=`sg-${run}`,sig=`sig-${run}`, room=`room-${run}`;
const roomPath=`subgroups/${sg}/rooms/${room}`;
const seatPath=`${roomPath}/seats/seat-1`;
const claimPath=uid=>`activeSeatClaims/${uid}`;
// Administrative fixture seeding is confined to the emulator.
await allow('seed authorized memberships','owner',[
 write(`sigs/${sig}`,{ownerId:a.uid,status:'active',membershipRevision:0}),
 write(`subgroups/${sg}`,{sigId:sig,status:'active',name:'Rules topic'}),
 ...[a,b].flatMap(u=>[write(`sigs/${sig}/members/${u.uid}`,{userId:u.uid,sigId:sig,status:'active'}),write(`subgroups/${sg}/members/${u.uid}`,{userId:u.uid,sigId:sig,status:'active'})]),
 ...[a,b,outsider].map(u=>write(`users/${u.uid}`,{displayName:u.uid,avatarId:'default'})),
]);
const roomWrites=[write(roomPath,{roomId:room,subgroupId:sg,sigId:sig,title:'Rules room',createdBy:a.uid,hostUid:a.uid,status:'waiting'},['createdAt','updatedAt']),
 write(`roomDirectory/${room}`,{subgroupId:sg,sigId:sig}),
 ...Array.from({length:6},(_,i)=>write(`${roomPath}/seats/seat-${i+1}`,{seatId:`seat-${i+1}`,status:'available'}))];
await deny('non-member cannot create room',outsider.token,roomWrites);
await allow('member creates room and six seats',a.token,roomWrites);
function claim(u, claimId='claim-a', seat='seat-1', roomId=room) {
 const expiry=new Date(Date.now()+115000);
 return [write(`subgroups/${sg}/rooms/${roomId}/seats/${seat}`,{seatId:seat,status:'occupied',userId:u.uid,claimId,leaseExpiresAt:expiry,displayName:u.uid,avatarId:'default'},['claimedAt','lastRenewedAt']),
 write(claimPath(u.uid),{userId:u.uid,subgroupId:sg,roomId:roomId,seatId:seat,claimId,leaseExpiresAt:expiry})];
}
await deny('seat write without paired claim denied',a.token,[claim(a)[0]]);
await allow('atomic seat and claim pair',a.token,claim(a));
await deny('another learner cannot steal occupied seat',b.token,claim(b,'claim-b'));
await deny('same user cannot hold a second seat',a.token,claim(a,'claim-second','seat-2'));
await deny('arbitrary lease extension denied',a.token,[write(seatPath,{seatId:'seat-1',status:'occupied',userId:a.uid,claimId:'claim-a',leaseExpiresAt:new Date(Date.now()+9999999),displayName:a.uid,avatarId:'default'},['claimedAt','lastRenewedAt'])]);
await deny('another learner cannot release seat',b.token,[write(seatPath,{seatId:'seat-1',status:'available'}),{delete:name(claimPath(a.uid))}]);
await deny('fabricated completion denied',a.token,[write(`users/${a.uid}/completions/fake`,{recordId:'fake',userId:a.uid,sessionId:'fake',goalText:'fake',creditedSeconds:99999,timerStatus:'completed',goalOutcome:'completed',isDemo:false},['endedAt'])]);
await deny('private history not writable by another user',b.token,[write(`users/${a.uid}/completions/fake`,{userId:a.uid})]);
await allow('release is paired with deleting own claim',a.token,[write(seatPath,{seatId:'seat-1',status:'available'}),{delete:name(claimPath(a.uid))}]);
console.log('All room and seat security checks passed');
function patch(path,data,serverFields=[]) {return {...write(path,data,serverFields),updateMask:{fieldPaths:Object.keys(data)}};}
const sessionId=`session-${run}`;
const active=`users/${a.uid}/activeSession/current`;
await allow('reclaim after release',a.token,claim(a,'session-claim'));
await allow('host starts immutable shared demo with own participation',a.token,[
 write(`roomSessions/${sessionId}`,{sessionId,roomId:room,subgroupId:sg,hostUid:a.uid,roomTitle:'Rules room',isDemo:true},['startsAt']),
 patch(roomPath,{sessionId,status:'active'},['updatedAt']),
 write(active,{sessionId,roomId:room,subgroupId:sg,seatId:'seat-1',claimId:'session-claim',userId:a.uid,goalText:'Finish one task'},['joinedAt']),
]);
await deny('active participation prevents seat release before saving',a.token,[write(seatPath,{seatId:'seat-1',status:'available'}),{delete:name(claimPath(a.uid))}]);
const completion={recordId:sessionId,sessionId,userId:a.uid,goalText:'Finish one task',creditedSeconds:0,timerStatus:'endedEarly',goalOutcome:'unfinished',isDemo:true};
const completionPath=`users/${a.uid}/completions/${sessionId}`;
await deny('inflated session credit rejected',a.token,[write(completionPath,{...completion,creditedSeconds:99999},['endedAt']),{delete:name(active)}]);
await deny('demo cannot become normal progress',a.token,[write(completionPath,{...completion,isDemo:false},['endedAt']),{delete:name(active)}]);
await deny('early exit cannot claim completed timer',a.token,[write(completionPath,{...completion,timerStatus:'completed'},['endedAt']),{delete:name(active)}]);
await allow('completion and participation removal commit together',a.token,[write(completionPath,completion,['endedAt']),{delete:name(active)}]);
await deny('saved completion cannot be overwritten or duplicated',a.token,[write(completionPath,completion,['endedAt'])]);
await deny('saved participant cannot rejoin the same cycle',a.token,[write(active,{sessionId,roomId:room,subgroupId:sg,seatId:'seat-1',claimId:'session-claim',userId:a.uid,goalText:'Repeat'},['joinedAt'])]);
assert.equal((await request(`${root}/${completionPath}`,b.token)).status,403);
console.log('PASS private completion read rejected');
await allow('release after saving',a.token,[write(seatPath,{seatId:'seat-1',status:'available'}),{delete:name(claimPath(a.uid))}]);
const race=await Promise.all([commit(a.token,claim(a,'race-a')),commit(b.token,claim(b,'race-b'))]);
assert.deepEqual(race.map(r=>r.status).sort(),[200,403]);
console.log('PASS simultaneous seat claims yield exactly one winner');
console.log('All connected session and completion security checks passed');

function configuredRoom(id,capacity,isPrivate) {
 const path=`subgroups/${sg}/rooms/${id}`;
 return [write(path,{roomId:id,subgroupId:sg,sigId:sig,title:'Configured room',createdBy:a.uid,hostUid:a.uid,status:'waiting',capacity,isPrivate},['createdAt','updatedAt']),
  write(`roomDirectory/${id}`,{subgroupId:sg,sigId:sig}),
  ...Array.from({length:Math.max(0,Math.min(capacity,40))},(_,i)=>write(`${path}/seats/seat-${i+1}`,{seatId:`seat-${i+1}`,status:'available'}))];
}
await deny('capacity below two rejected',a.token,configuredRoom(`small-${run}`,1,false));
await deny('capacity over forty rejected',a.token,configuredRoom(`large-${run}`,41,false));
const forty=`forty-${run}`;
await allow('forty-desk room initializes all forty seats atomically',a.token,configuredRoom(forty,40,false));
await deny('room capacity is immutable after creation',a.token,[patch(`subgroups/${sg}/rooms/${forty}`,{capacity:39})]);
// Reset the independent race test's claim before checking configured rooms.
await allow('clear fixture claims for capacity tests','owner',[{delete:name(claimPath(a.uid))},{delete:name(claimPath(b.uid))}]);
await allow('desk forty can be claimed',b.token,claim(b,'forty-claim','seat-40',forty));
await deny('desk forty-one cannot be manufactured',a.token,[write(`subgroups/${sg}/rooms/${forty}/seats/seat-41`,{seatId:'seat-41',status:'available'})]);
await allow('release desk forty',b.token,[write(`subgroups/${sg}/rooms/${forty}/seats/seat-40`,{seatId:'seat-40',status:'available'}),{delete:name(claimPath(b.uid))}]);
const privateRoom=`private-${run}`, privatePath=`subgroups/${sg}/rooms/${privateRoom}`;
await allow('create private two-desk room',a.token,configuredRoom(privateRoom,2,true));
assert.equal((await request(`${root}/${privatePath}`,b.token)).status,200);
console.log('PASS private room metadata remains discoverable');
assert.equal((await request(`${root}/${privatePath}/seats/seat-1`,b.token)).status,403);
console.log('PASS private room seats require admission');
await deny('member cannot bypass private invitation by claiming directly',b.token,claim(b,'private-claim','seat-1',privateRoom));
const alphabet='ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const token=Array.from(crypto.getRandomValues(new Uint8Array(16)),n=>alphabet[n%alphabet.length]).join('');
const otherToken=Array.from(crypto.getRandomValues(new Uint8Array(16)),n=>alphabet[n%alphabet.length]).join('');
await allow('host issues private invitation',a.token,[write(`roomInvites/${token}`,{roomId:privateRoom,subgroupId:sg,issuedBy:a.uid,expiresAt:new Date(Date.now()+3600000),revoked:false})]);
await deny('uninvited member cannot issue private room invitation',b.token,[write(`roomInvites/${otherToken}`,{roomId:privateRoom,subgroupId:sg,issuedBy:b.uid,expiresAt:new Date(Date.now()+3600000),revoked:false})]);
const grant=(invitationToken=token)=>write(`users/${b.uid}/roomAccess/${privateRoom}`,{userId:b.uid,roomId:privateRoom,subgroupId:sg,invitationToken},['admittedAt']);
await deny('wrong invitation cannot grant private access',b.token,[grant(otherToken),...claim(b,'private-claim','seat-1',privateRoom)]);
for (const [label,invite] of [
 ['expired', {roomId:privateRoom,subgroupId:sg,issuedBy:a.uid,expiresAt:new Date(Date.now()-1000),revoked:false}],
 ['revoked', {roomId:privateRoom,subgroupId:sg,issuedBy:a.uid,expiresAt:new Date(Date.now()+3600000),revoked:true}],
 ['other-room', {roomId:forty,subgroupId:sg,issuedBy:a.uid,expiresAt:new Date(Date.now()+3600000),revoked:false}],
]) {
 const invalidCode=Array.from(crypto.getRandomValues(new Uint8Array(16)),n=>alphabet[n%alphabet.length]).join('');
 await allow(`seed ${label} invitation fixture`,'owner',[write(`roomInvites/${invalidCode}`,invite)]);
 await deny(`${label} invitation cannot admit private-room member`,b.token,[grant(invalidCode),...claim(b,'private-claim','seat-1',privateRoom)]);
}
await allow('verified invitation grants admission and claims seat atomically',b.token,[grant(),...claim(b,'private-claim','seat-1',privateRoom)]);
assert.equal((await request(`${root}/${privatePath}/seats/seat-1`,b.token)).status,200);
assert.equal((await request(`${root}/users/${b.uid}/roomAccess/${privateRoom}`,a.token)).status,403);
console.log('PASS admitted member sees seats; invitation token remains private');
await deny('private two-desk capacity cannot be exceeded',a.token,claim(a,'bad-third','seat-3',privateRoom));
await deny('private seat cannot be reassigned to a nonmember',outsider.token,claim(outsider,'outside','seat-2',privateRoom));
console.log('All configurable capacity and private-room security checks passed');
const newcomer=await user('private-newcomer');
await allow('seed separate code verification user','owner',[
 write(`users/${newcomer.uid}`,{displayName:newcomer.uid,avatarId:'default'}),
 write(`sigs/${sig}/members/${newcomer.uid}`,{userId:newcomer.uid,sigId:sig,status:'active'}),
 write(`subgroups/${sg}/members/${newcomer.uid}`,{userId:newcomer.uid,sigId:sig,status:'active'}),
]);
await allow('code verification grants access before protected seat reads',newcomer.token,[
 write(`users/${newcomer.uid}/roomAccess/${privateRoom}`,{userId:newcomer.uid,roomId:privateRoom,subgroupId:sg,invitationToken:token},['admittedAt'])
]);
assert.equal((await request(`${root}/${privatePath}/seats/seat-2`,newcomer.token)).status,200);
await allow('verified user then atomically claims the second private desk',newcomer.token,claim(newcomer,'private-second','seat-2',privateRoom));
