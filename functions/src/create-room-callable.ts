import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import {
  HttpsError,
  onCall,
  type CallableRequest,
} from 'firebase-functions/v2/https';

import {
  CreateRoomRequestValidationError,
  parseCreateRoomRequest,
} from './create-room-request';
import { createRoomDocument } from './create-room-document';
import { RoomCreationEligibilityError } from './room-creation-eligibility';

/** Handler factory keeps the callable testable without a deployed Firebase app. */
export function createRoomCallableHandler(firestore?: Firestore) {
  return async (request: CallableRequest<unknown>) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign-in is required.');
    }

    let validatedRequest;
    try {
      validatedRequest = parseCreateRoomRequest(request.data);
    } catch (error) {
      if (error instanceof CreateRoomRequestValidationError) {
        throw new HttpsError(
          'invalid-argument',
          'Provide a valid subgroupId and room title.',
        );
      }
      throw new HttpsError('internal', 'Room creation failed.');
    }

    try {
      return await createRoomDocument({
        firestore: firestore ?? getFirestore(),
        request: validatedRequest,
        uid,
      });
    } catch (error) {
      if (error instanceof RoomCreationEligibilityError) {
        switch (error.code) {
          case 'unauthenticated':
            throw new HttpsError('unauthenticated', 'Sign-in is required.');
          case 'invalid-argument':
            throw new HttpsError('invalid-argument', 'Invalid room request.');
          case 'membership-required':
            throw new HttpsError(
              'permission-denied',
              'Active SIG and subgroup membership are required.',
            );
          case 'unavailable':
            throw new HttpsError(
              'unavailable',
              'Membership could not be verified. Try again later.',
            );
        }
      }
      if (error instanceof TypeError) {
        throw new HttpsError('invalid-argument', 'Invalid room request.');
      }
      throw new HttpsError('internal', 'Room creation failed.');
    }
  };
}

export const createRoom = onCall(createRoomCallableHandler());
