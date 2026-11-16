const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { completeMembershipCleanup } = require('./membership_cleanup');
initializeApp();
exports.cleanupMembership = onDocumentCreated({ document: 'membershipCleanupRequests/{requestId}',
  region: 'us-central1', retry: true }, async event => {
  if (!event.data) return;
  await completeMembershipCleanup(getFirestore(), event.params.requestId);
});
