// Run only against local emulators; never administrative test writes in production.
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Set FIRESTORE_EMULATOR_HOST to a local emulator');
const assert = require('node:assert/strict');
const backendRequire = require('node:module').createRequire(require('node:path').resolve(__dirname, '../functions/package.json'));
const {initializeApp} = backendRequire('firebase-admin/app');
const {getFirestore, Timestamp} = backendRequire('firebase-admin/firestore');
const {completeMembershipCleanup} = require('../functions/membership_cleanup');
initializeApp({projectId:'studymates-dev'});
const db=getFirestore();
async function run() {
 const suffix=crypto.randomUUID(), uid=`departing-${suffix}`, successor=`successor-${suffix}`;
 const sig=`cleanup-sig-${suffix}`, sg=`cleanup-group-${suffix}`, room=`cleanup-room-${suffix}`;
 const requestId=`cleanup-${suffix}`, claimId='claim-old';
 const roomPath=`subgroups/${sg}/rooms/${room}`;
 const expiry=Timestamp.fromMillis(Date.now()+120000);
 const batch=db.batch();
 for (const [path,data] of [
  [`sigs/${sig}`,{ownerId:successor,status:'active'}],
  [`subgroups/${sg}`,{sigId:sig}],
  [`subgroups/${sg}/members/${uid}`,{status:'removalPending',removalRequestId:requestId}],
  [`subgroups/${sg}/members/${successor}`,{status:'active'}],
  [roomPath,{subgroupId:sg,hostUid:uid,status:'active'}],
  [`${roomPath}/seats/seat-1`,{seatId:'seat-1',status:'occupied',userId:uid,claimId,leaseExpiresAt:expiry}],
  [`${roomPath}/seats/seat-2`,{seatId:'seat-2',status:'occupied',userId:successor,claimId:'next',leaseExpiresAt:expiry}],
  [`activeSeatClaims/${uid}`,{subgroupId:sg,roomId:room,seatId:'seat-1',claimId}],
  [`users/${uid}/activeSession/current`,{sessionId:suffix,subgroupId:sg,roomId:room,seatId:'seat-1',claimId,goalText:'Learn'}],
  [`roomSessions/${suffix}`,{isDemo:true}],
  [`membershipCleanupRequests/${requestId}`,{userId:uid,sigId:sig,subgroupId:sg,scope:'subgroup',status:'pending'}],
 ]) batch.set(db.doc(path),data);
 await batch.commit();
 await completeMembershipCleanup(db,requestId);
 await completeMembershipCleanup(db,requestId);
 assert.equal((await db.doc(`${roomPath}/seats/seat-1`).get()).data().status,'available');
 assert.equal((await db.doc(`activeSeatClaims/${uid}`).get()).exists,false);
 assert.equal((await db.doc(`users/${uid}/activeSession/current`).get()).exists,false);
 assert.equal((await db.doc(`users/${uid}/completions/${suffix}`).get()).data().creditedSeconds,0);
 assert.equal((await db.doc(roomPath).get()).data().hostUid,successor);
 assert.equal((await db.doc(`membershipCleanupRequests/${requestId}`).get()).data().status,'completed');
 assert.equal((await db.collection(`users/${uid}/completions`).get()).size,1);
 console.log('PASS trusted membership cleanup, host transfer and retry idempotency');
 await db.terminate();
}
run().catch(e=>{console.error(e);process.exitCode=1});
