import { getApps, initializeApp } from 'firebase-admin/app';

// Use the runtime's default credentials in deployed Functions and the
// configured emulator credentials during local development.
if (getApps().length === 0) {
  initializeApp();
}

// Room-creation helpers remain reusable; the connected Flutter composition uses
// its transaction-backed repository. Export the trusted cleanup trigger here.

import { getFirestore } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
const { completeMembershipCleanup } = require('../membership_cleanup');

export const cleanupMembership = onDocumentCreated({
  document: 'membershipCleanupRequests/{requestId}',
  region: 'us-central1', retry: true,
}, async event => {
  if (!event.data) return;
  await completeMembershipCleanup(getFirestore(), event.params.requestId);
});
