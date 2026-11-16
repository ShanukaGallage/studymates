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
  readonly title: string;
  readonly createdBy: string;
  readonly hostUid: string;
  readonly status: 'waiting';
  readonly createdAt: Timestamp;
  readonly updatedAt: Timestamp;
}

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
 * Creates only the room document. The membership verifier reads M2's four
 * documents through this same transaction before the room write is issued.
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
    await verifyEligibility({
      firestore,
      transaction,
      uid: authenticatedUid,
      subgroupId,
    });

    const now = Timestamp.now();
    const room: CreatedRoomDocument = {
      roomId,
      subgroupId,
      title,
      createdBy: authenticatedUid,
      hostUid: authenticatedUid,
      status: 'waiting',
      createdAt: now,
      updatedAt: now,
    };

    transaction.create(roomReference, room);
    return room;
  });
}
