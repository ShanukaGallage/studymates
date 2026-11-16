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
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { createRoomDocument } from './create-room-document';
import { parseCreateRoomRequest } from './create-room-request';
import { CreateRoomRequestValidationError } from './create-room-request';
import { RoomCreationEligibilityError } from './room-creation-eligibility';
import {
  createSeatOperationHandlers,
  SeatOperationError,
} from './seat-operations';
const { completeMembershipCleanup } = require('../membership_cleanup');

export const cleanupMembership = onDocumentCreated({
  document: 'membershipCleanupRequests/{requestId}',
  region: 'us-central1', retry: true,
}, async event => {
  if (!event.data) return;
  await completeMembershipCleanup(getFirestore(), event.params.requestId);
});

function callableError(error: unknown): never {
  if (error instanceof HttpsError) throw error;
  if (error instanceof SeatOperationError) {
    throw new HttpsError(error.code, error.message);
  }
  if (error instanceof CreateRoomRequestValidationError) {
    throw new HttpsError('invalid-argument', error.message);
  }
  if (error instanceof RoomCreationEligibilityError) {
    const code = error.code === 'unauthenticated' ? 'unauthenticated'
      : error.code === 'invalid-argument' ? 'invalid-argument'
      : error.code === 'membership-required' ? 'permission-denied' : 'unavailable';
    throw new HttpsError(code, error.message);
  }
  if (error instanceof TypeError) {
    throw new HttpsError('invalid-argument', error.message);
  }
  console.error('Trusted room operation failed', error);
  throw new HttpsError('unavailable', 'The room operation could not be completed.');
}

const seatOperations = createSeatOperationHandlers(getFirestore());

export const createRoom = onCall({ region: 'us-central1' }, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign-in is required.');
  try {
    const parsed = parseCreateRoomRequest(request.data);
    const room = await createRoomDocument({
      firestore: getFirestore(), request: parsed, uid: request.auth.uid,
    });
    return { roomId: room.roomId, subgroupId: room.subgroupId, status: room.status };
  } catch (error) { return callableError(error); }
});

export const claimSeat = onCall({ region: 'us-central1' }, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign-in is required.');
  try { return await seatOperations.claim(request.auth.uid, request.data); }
  catch (error) { return callableError(error); }
});

export const releaseSeat = onCall({ region: 'us-central1' }, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign-in is required.');
  try { return await seatOperations.release(request.auth.uid, request.data); }
  catch (error) { return callableError(error); }
});

export const renewSeat = onCall({ region: 'us-central1' }, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign-in is required.');
  try { return await seatOperations.renew(request.auth.uid, request.data); }
  catch (error) { return callableError(error); }
});
