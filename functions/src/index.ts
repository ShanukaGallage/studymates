import { getApps, initializeApp } from 'firebase-admin/app';

// Use the runtime's default credentials in deployed Functions and the
// configured emulator credentials during local development.
if (getApps().length === 0) {
  initializeApp();
}

// Future callable and Firestore-trigger exports should use Firebase Functions
// v2 APIs from the `firebase-functions/v2` entry points.
