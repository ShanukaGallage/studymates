import {
  Timestamp,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';

import type { CreateRoomRequest } from './create-room-request';
import {
  verifyRoomCreationEligibility,
  type VerifyRoomCreationEligibilityInput,
} from './room-creation-eligibility';

export interface CreatedRoomDocument {
  readonly roomId: string;
  readonly subgroupId: string;
  readonly sigId: string;
  readonly title: string;
  readonly createdBy: string;
  readonly hostUid: string;
  readonly status: 'waiting';
  readonly createdAt: Timestamp;
  readonly updatedAt: Timestamp;
}

export interface InitialSeatDocument {
  readonly seatId: string;
  readonly status: 'available';
  readonly userId: null;
  readonly claimedAt: null;
  readonly leaseExpiresAt: null;
  readonly lastRenewedAt: null;
}

export const INITIAL_ROOM_SEAT_IDS = [
  'seat-1',
  'seat-2',
  'seat-3',
  'seat-4',
  'seat-5',
  'seat-6',
] as const;

export interface CreateRoomDocumentInput {
  readonly firestore: Firestore;
  readonly request: CreateRoomRequest;
  /** UID obtained by the caller from authenticated Firebase context. */
  readonly uid: string;
}

type EligibilityVerifier = (
  input: VerifyRoomCreationEligibilityInput,
) => Promise<{ sigId: string }>;

/**
 * Creates a room and its six available seats atomically. The membership
 * verifier reads M2's four documents through this same transaction before any
 * room or seat writes are issued.
 */
export async function createRoomDocument(
  { firestore, request, uid }: CreateRoomDocumentInput,
  verifyEligibility: EligibilityVerifier = verifyRoomCreationEligibility,
): Promise<CreatedRoomDocument> {
  const subgroupId = request.subgroupId.trim();
  const title = request.title.trim();
  const authenticatedUid = uid.trim();

  if (!subgroupId || subgroupId.includes('/')) {
    throw new TypeError('A validated subgroupId is required.');
  }
  if (!title) {
    throw new TypeError('A validated room title is required.');
  }
  if (!authenticatedUid || authenticatedUid.includes('/')) {
    throw new TypeError('An authenticated UID is required.');
  }

  const roomCollection = firestore.collection(
    `subgroups/${subgroupId}/rooms`,
  );
  // Firestore's generated document ID avoids predictable/caller-selected IDs.
  const roomReference = roomCollection.doc();
  const roomId = roomReference.id;

  return firestore.runTransaction(async (transaction: Transaction) => {
    const { sigId } = await verifyEligibility({
      firestore,
      transaction,
      uid: authenticatedUid,
      subgroupId,
    });

    const now = Timestamp.now();
    const room: CreatedRoomDocument = {
      roomId,
      subgroupId,
      sigId,
      title,
      createdBy: authenticatedUid,
      hostUid: authenticatedUid,
      status: 'waiting',
      createdAt: now,
      updatedAt: now,
    };

    transaction.create(roomReference, room);
    transaction.create(firestore.doc(`roomDirectory/${roomId}`), {
      subgroupId,
      sigId,
    });
    for (const seatId of INITIAL_ROOM_SEAT_IDS) {
      const seat: InitialSeatDocument = {
        seatId,
        status: 'available',
        userId: null,
        claimedAt: null,
        leaseExpiresAt: null,
        lastRenewedAt: null,
      };
      transaction.create(
        firestore.doc(`${roomReference.path}/seats/${seatId}`),
        seat,
      );
    }
    return room;
  });
}
