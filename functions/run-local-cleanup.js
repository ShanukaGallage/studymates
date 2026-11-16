const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  throw new Error('This helper requires a localhost FIRESTORE_EMULATOR_HOST.');
}
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {completeMembershipCleanup} = require('./membership_cleanup');
initializeApp({projectId: 'studymates-dev'});
(async () => {
  const db = getFirestore();
  const requests = await db.collection('membershipCleanupRequests').where('status', '==', 'pending').get();
  for (const request of requests.docs) await completeMembershipCleanup(db, request.id);
  console.log(`Processed ${requests.size} local cleanup requests.`);
  await db.terminate();
})().catch(error => {console.error(error); process.exitCode = 1;});