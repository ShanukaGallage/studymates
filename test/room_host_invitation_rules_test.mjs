import assert from 'node:assert/strict';
const project = 'studymates-dev';
const root = `http://${process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080'}/v1/projects/${project}/databases/(default)/documents`;
const name = p => `projects/${project}/databases/(default)/documents/${p}`;
const run = crypto.randomUUID();
const v = x => Array.isArray(x) ? {arrayValue:{values:x.map(v)}} : x instanceof Date ? {timestampValue:x.toISOString()} : typeof x === 'boolean' ? {booleanValue:x} : typeof x === 'number' ? {integerValue:String(x)} : {stringValue:x};
const write = (p,data,server=[]) => ({update:{name:name(p),fields:Object.fromEntries(Object.entries(data).map(([k,x])=>[k,v(x)]))},...(server.length ? {updateTransforms:server.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))}: {})});
const patch = (p,data,server=[]) => ({...write(p,data,server),updateMask:{fieldPaths:Object.keys(data)}});
async function commit(token,writes) {const res=await fetch(`${root}:commit`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${token}`},body:JSON.stringify({writes})});return {status:res.status,body:await res.text()};}
async function allow(label,token,writes){const r=await commit(token,writes);assert.equal(r.status,200,`${label}: ${r.body}`);console.log(`PASS ${label}`);}
async function deny(label,token,writes){const r=await commit(token,writes);assert.equal(r.status,403,`${label}: ${r.body}`);console.log(`PASS ${label}`);}
async function user(label){const res=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST||'127.0.0.1:9099'}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:`host-${label}-${run}@example.test`,password:'study-test-password',returnSecureToken:true})});const d=await res.json();assert.equal(res.status,200);return {uid:d.localId,token:d.idToken};}
const [a,b,c,d]=await Promise.all(['a','b','c','d'].map(user));
const sg=`host-sg-${run}`, sig=`host-sig-${run}`, room=`host-room-${run}`;
const path=`subgroups/${sg}/rooms/${room}`;
const claim=u=>`activeSeatClaims/${u.uid}`;
const seat=i=>`${path}/seats/seat-${i}`;
const old=new Date(Date.now()-600000), future=new Date(Date.now()+115000);
const baseClaim=(u,i)=>({userId:u.uid,subgroupId:sg,roomId:room,seatId:`seat-${i}`,claimId:`claim-${i}`,leaseExpiresAt:future});
await allow('seed host and ordered candidates','owner',[
 write(`sigs/${sig}`,{ownerId:a.uid,status:'active',membershipRevision:0}),write(`subgroups/${sg}`,{sigId:sig,status:'active'}),
 ...[a,b,c].flatMap(u=>[write(`sigs/${sig}/members/${u.uid}`,{userId:u.uid,sigId:sig,status:'active'}),write(`subgroups/${sg}/members/${u.uid}`,{userId:u.uid,subgroupId:sg,sigId:sig,status:'active'}),write(`users/${u.uid}`,{displayName:u.uid,avatarId:'default'})]),
 write(path,{roomId:room,subgroupId:sg,sigId:sig,title:'Host test',createdBy:a.uid,hostUid:a.uid,status:'active',capacity:6,isPrivate:false,createdAt:old,updatedAt:old,hostQueue:['seat-1','seat-2','seat-3'],hostReleased:false,sessionId:'unchanged-cycle'}),
 ...[a,b,c].flatMap((u,i)=>[write(seat(i+1),{seatId:`seat-${i+1}`,status:'occupied',userId:u.uid,claimId:`claim-${i+1}`,claimedAt:new Date(Date.now()-(300-i*10)*1000),lastRenewedAt:old,leaseExpiresAt:future,displayName:u.uid,avatarId:'default'}),write(claim(u),baseClaim(u,i+1))]),
]);
const hostTo=u=>patch(path,{hostUid:u.uid},['updatedAt']);
await deny('healthy host cannot be displaced',c.token,[hostTo(b)]);
await deny('queue cannot be reordered by a newer occupant',c.token,[patch(path,{hostQueue:['seat-3','seat-2','seat-1']},['updatedAt'])]);
await deny('healthy queue head cannot be discarded',c.token,[patch(path,{hostQueue:['seat-2','seat-3']},['updatedAt'])]);
await allow('expire old host lease administratively','owner',[patch(claim(a),{leaseExpiresAt:old}),patch(seat(1),{leaseExpiresAt:old})]);
await deny('nonmember cannot elect a host',d.token,[hostTo(b)]);
await deny('newer learner cannot skip the expired queue head',c.token,[hostTo(c)]);
await allow('remaining occupant prunes expired head',c.token,[patch(path,{hostQueue:['seat-2','seat-3']},['updatedAt'])]);
await deny('newer occupant cannot bypass oldest eligible learner',c.token,[hostTo(c)]);
await allow('any seated member elects exactly the oldest eligible learner',c.token,[hostTo(b)]);
await deny('former host cannot reclaim authority from live successor',a.token,[hostTo(a)]);
await deny('host change cannot reset the shared cycle',b.token,[patch(path,{hostUid:c.uid,sessionId:'reset-cycle'},['updatedAt'])]);
await allow('host release atomically removes own queue entry',b.token,[write(seat(2),{seatId:'seat-2',status:'available'}),{delete:name(claim(b))},patch(path,{hostQueue:['seat-3'],hostReleased:true},['updatedAt'])]);
await allow('next longest occupant succeeds released host',c.token,[hostTo(c)]);
const expiry=new Date(Date.now()+115000);
const bSeat={seatId:'seat-2',status:'occupied',userId:b.uid,claimId:'b-rejoin',leaseExpiresAt:expiry,displayName:b.uid,avatarId:'default'};
const bClaim={...baseClaim(b,2),claimId:'b-rejoin',leaseExpiresAt:expiry};
await deny('claim without queue append is denied',b.token,[write(seat(2),bSeat,['claimedAt','lastRenewedAt']),write(claim(b),bClaim)]);
await deny('rejoining cannot jump ahead of existing occupants',b.token,[write(seat(2),bSeat,['claimedAt','lastRenewedAt']),write(claim(b),bClaim),patch(path,{hostQueue:['seat-2','seat-3']},['updatedAt'])]);
await allow('rejoining appends at the end',b.token,[write(seat(2),bSeat,['claimedAt','lastRenewedAt']),write(claim(b),bClaim),patch(path,{hostQueue:['seat-3','seat-2']},['updatedAt'])]);
await allow('ineligible host fixture','owner',[patch(claim(c),{leaseExpiresAt:old}),patch(seat(3),{leaseExpiresAt:old}),patch(`subgroups/${sg}/members/${c.uid}`,{status:'left'})]);
await allow('live but ineligible older candidate fixture','owner',[
 patch(path,{hostQueue:['seat-1','seat-3','seat-2']}),
 patch(seat(1),{leaseExpiresAt:new Date(Date.now()+115000)}),
 patch(claim(a),{leaseExpiresAt:new Date(Date.now()+115000)}),
 patch(`subgroups/${sg}/members/${a.uid}`,{status:'left'}),
]);
await deny('cannot bypass an ineligible head without pruning',b.token,[hostTo(b)]);
await allow('live but ineligible head can be pruned safely',b.token,[patch(path,{hostQueue:['seat-3','seat-2']},['updatedAt'])]);
await allow('eligible next learner removes departed host',b.token,[patch(path,{hostQueue:['seat-2']},['updatedAt'])]);
await allow('eligible queue head becomes host',b.token,[hostTo(b)]);
// Revocation management: old issuer/creator and current host retain authority.
const token='ABCD2345EFGH6789';
await allow('seed old host invitation','owner',[write(`roomInvites/${token}`,{subgroupId:sg,roomId:room,issuedBy:a.uid,expiresAt:new Date(Date.now()+3600000),revoked:false})]);
await deny('unrelated learner cannot revoke code',d.token,[patch(`roomInvites/${token}`,{revoked:true})]);
await deny('departed nonhost cannot revoke another issuer code',c.token,[patch(`roomInvites/${token}`,{revoked:true})]);
await allow('new host revokes prior host invitation',b.token,[patch(`roomInvites/${token}`,{revoked:true})]);
await deny('revocation cannot be undone',b.token,[patch(`roomInvites/${token}`,{revoked:false})]);
await deny('revocation cannot extend expiration',b.token,[patch(`roomInvites/${token}`,{revoked:true,expiresAt:new Date(Date.now()+7200000)})]);
async function list(u){const res=await fetch(`${root}:runQuery`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${u.token}`},body:JSON.stringify({structuredQuery:{from:[{collectionId:'roomInvites'}],where:{compositeFilter:{op:'AND',filters:[['roomId',room],['subgroupId',sg]].map(([fieldPath,x])=>({fieldFilter:{field:{fieldPath},op:'EQUAL',value:v(x)}}))}},limit:50}})});return {status:res.status,body:await res.text()};}
let result=await list(b);assert.equal(result.status,200,result.body);console.log('PASS new host can list room invitations');
result=await list(d);assert.equal(result.status,403,result.body);console.log('PASS outsiders cannot enumerate room invitations');
console.log('All host succession and invitation management rules checks passed');
const privateRoom=`private-queue-${run}`;
const privatePath=`subgroups/${sg}/rooms/${privateRoom}`;
await allow('prepare previously outsider as eligible learner','owner',[
 write(`users/${d.uid}`,{displayName:d.uid,avatarId:'default'}),
 write(`sigs/${sig}/members/${d.uid}`,{userId:d.uid,sigId:sig,status:'active'}),
 write(`subgroups/${sg}/members/${d.uid}`,{userId:d.uid,subgroupId:sg,sigId:sig,status:'active'}),
]);
await allow('create private 40-desk room with empty ordered queue',b.token,[
 write(privatePath,{roomId:privateRoom,subgroupId:sg,sigId:sig,title:'Private queue',createdBy:b.uid,hostUid:b.uid,status:'waiting',capacity:40,isPrivate:true,hostQueue:[],hostReleased:false},['createdAt','updatedAt']),
 write(`roomDirectory/${privateRoom}`,{subgroupId:sg,sigId:sig}),
 ...Array.from({length:40},(_,i)=>write(`${privatePath}/seats/seat-${i+1}`,{seatId:`seat-${i+1}`,status:'available'})),
]);
const privateToken='ABCD2345EFGH6792';
await allow('host issues private-room code',b.token,[write(`roomInvites/${privateToken}`,{subgroupId:sg,roomId:privateRoom,issuedBy:b.uid,expiresAt:new Date(Date.now()+3600000),revoked:false})]);
await allow('verified code grants access before desk reads',d.token,[write(`users/${d.uid}/roomAccess/${privateRoom}`,{userId:d.uid,roomId:privateRoom,subgroupId:sg,invitationToken:privateToken},['admittedAt'])]);
const privateExpiry=new Date(Date.now()+115000);
await allow('private desk 40 claim and FIFO append fit rules budget',d.token,[
 write(`${privatePath}/seats/seat-40`,{seatId:'seat-40',status:'occupied',userId:d.uid,claimId:'private-claim',leaseExpiresAt:privateExpiry,displayName:d.uid,avatarId:'default'},['claimedAt','lastRenewedAt']),
 write(claim(d),{userId:d.uid,subgroupId:sg,roomId:privateRoom,seatId:'seat-40',claimId:'private-claim',leaseExpiresAt:privateExpiry}),
 patch(privatePath,{hostQueue:['seat-40']},['updatedAt']),
]);
await allow('unseated creator explicitly yields initial host grace',b.token,[patch(privatePath,{hostReleased:true},['updatedAt'])]);
await allow('oldest private-room learner takes yielded host role',d.token,[patch(privatePath,{hostUid:d.uid},['updatedAt'])]);
console.log('Private-room queue and host-grace checks passed');
