import type { Firestore, Transaction } from 'firebase-admin/firestore';

export type RoomCreationEligibilityErrorCode =
  | 'unauthenticated'
  | 'invalid-argument'
  | 'membership-required'
  | 'unavailable';

export class RoomCreationEligibilityError extends Error {
  constructor(readonly code: RoomCreationEligibilityErrorCode, message: string) {
    super(message);
    this.name = 'RoomCreationEligibilityError';
  }
}

export interface VerifyRoomCreationEligibilityInput {
  readonly firestore: Firestore;
  readonly transaction: Transaction;
  readonly uid: string;
  readonly subgroupId: string;
}

/**
 * Verifies the active M2 membership state using only the supplied transaction.
 * It performs no writes. Returns the subgroup's parent SIG ID on success.
 */
export async function verifyRoomCreationEligibility({
  firestore,
  transaction,
  uid,
  subgroupId,
}: VerifyRoomCreationEligibilityInput): Promise<{ sigId: string }> {
  const authenticatedUid = uid.trim();
  const requestedSubgroupId = subgroupId.trim();
  if (authenticatedUid.length === 0) {
    throw new RoomCreationEligibilityError(
      'unauthenticated',
      'An authenticated user is required.',
    );
  }
  if (requestedSubgroupId.length === 0 || requestedSubgroupId.includes('/')) {
    throw new RoomCreationEligibilityError(
      'invalid-argument',
      'A valid subgroupId is required.',
    );
  }

  // M2 stores subgroup.sigId and treats an omitted subgroup status as active.
  const subgroupSnapshot = await transaction.get(
    firestore.doc(`subgroups/${requestedSubgroupId}`),
  );
  if (!subgroupSnapshot.exists) {
    throw membershipRequired('The subgroup does not exist.');
  }
  const subgroup = subgroupSnapshot.data();
  if (subgroup === undefined) {
    throw unavailable('The subgroup document is malformed.');
  }
  const sigId = requiredString(subgroup, 'sigId', 'subgroup');

  // These paths and membership fields match FirestoreMembershipRepository.
  const sigSnapshot = await transaction.get(firestore.doc(`sigs/${sigId}`));
  const sigMemberSnapshot = await transaction.get(
    firestore.doc(`sigs/${sigId}/members/${authenticatedUid}`),
  );
  const subgroupMemberSnapshot = await transaction.get(
    firestore.doc(
      `subgroups/${requestedSubgroupId}/members/${authenticatedUid}`,
    ),
  );

  if (optionalStatus(subgroup, 'subgroup') !== 'active') {
    throw membershipRequired('The subgroup is not active.');
  }
  if (!sigSnapshot.exists) {
    throw membershipRequired('The parent SIG does not exist.');
  }
  const sig = sigSnapshot.data();
  if (sig === undefined) {
    throw unavailable('The SIG document is malformed.');
  }
  if (requiredStatus(sig, 'status', 'SIG') !== 'active') {
    throw membershipRequired('The parent SIG is not active.');
  }
  const ownerId = requiredString(sig, 'ownerId', 'SIG');

  const isOwner = ownerId === authenticatedUid;
  if (!sigMemberSnapshot.exists) {
    if (!isOwner) {
      throw membershipRequired('Active SIG membership is required.');
    }
  } else {
    const sigMember = sigMemberSnapshot.data();
    if (sigMember === undefined) {
      throw unavailable('The SIG membership document is malformed.');
    }
    if (!isActiveMembership(sigMember, authenticatedUid, sigId, 'SIG')) {
      throw membershipRequired('Active SIG membership is required.');
    }
  }

  if (!subgroupMemberSnapshot.exists) {
    throw membershipRequired('Active subgroup membership is required.');
  }
  const subgroupMember = subgroupMemberSnapshot.data();
  if (subgroupMember === undefined) {
    throw unavailable('The subgroup membership document is malformed.');
  }
  if (!isActiveMembership(subgroupMember, authenticatedUid, sigId, 'subgroup')) {
    throw membershipRequired('Active subgroup membership is required.');
  }

  return { sigId };
}

function isActiveMembership(
  data: FirebaseFirestore.DocumentData,
  uid: string,
  sigId: string,
  label: string,
): boolean {
  if (
    requiredString(data, 'userId', `${label} membership`) !== uid ||
    requiredString(data, 'sigId', `${label} membership`) !== sigId
  ) {
    throw unavailable(`The ${label} membership document is inconsistent.`);
  }
  const status: unknown = data.status;
  if (
    typeof status !== 'string' ||
    !['active', 'removalPending', 'left'].includes(status)
  ) {
    throw unavailable(`The ${label} membership document has an invalid status.`);
  }
  return status === 'active';
}

function requiredString(
  data: FirebaseFirestore.DocumentData,
  field: string,
  label: string,
): string {
  const value: unknown = data[field];
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw unavailable(`The ${label} document has an invalid ${field}.`);
  }
  return value;
}

function requiredStatus(
  data: FirebaseFirestore.DocumentData,
  field: string,
  label: string,
): string {
  const status = requiredString(data, field, label);
  if (status !== 'active' && status !== 'closed') {
    throw unavailable(`The ${label} document has an invalid ${field}.`);
  }
  return status;
}

function optionalStatus(
  data: FirebaseFirestore.DocumentData,
  label: string,
): string {
  const status: unknown = data.status ?? 'active';
  if (typeof status !== 'string' || !['active', 'closed'].includes(status)) {
    throw unavailable(`The ${label} document has an invalid status.`);
  }
  return status;
}

function membershipRequired(message: string): RoomCreationEligibilityError {
  return new RoomCreationEligibilityError('membership-required', message);
}

function unavailable(message: string): RoomCreationEligibilityError {
  return new RoomCreationEligibilityError('unavailable', message);
}
