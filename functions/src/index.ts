import { getApps, initializeApp } from 'firebase-admin/app';
export { createRoom } from './create-room-callable';

// Use the runtime's default credentials in deployed Functions and the
// configured emulator credentials during local development.
if (getApps().length === 0) {
  initializeApp();
}
