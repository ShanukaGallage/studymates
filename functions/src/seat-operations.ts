import {
  Timestamp,
  type Firestore,
  type QueryDocumentSnapshot,
} from 'firebase-admin/firestore';
import { verifyRoomCreationEligibility } from './room-creation-eligibility';

const SEATS = ['seat-1', 'seat-2', 'seat-3', 'seat-4', 'seat-5', 'seat-6'] as const;
const LEASE_MS = 2 * 60 * 1000;

export class SeatOperationError extends Error {
  constructor(readonly code: 'invalid-argument' | 'permission-denied' | 'failed-precondition' | 'not-found' | 'resource-exhausted' | 'already-exists', message: string) {
    super(message);
  }
}

type SeatInput = { subgroupId: string; roomId: string; seatId: string; expectedClaimId?: string; invitationToken?: string };
type SeatData = FirebaseFirestore.DocumentData;

function parseInput(input: unknown, operation: 'claim' | 'release' | 'renew'): SeatInput {
  if (!input || typeof input !== 'object' || Array.isArray(input)) {
    throw new SeatOperationError('invalid-argument', 'Request data must be an object.');
  }
  const data = input as Record<string, unknown>;
  const allowed = operation === 'claim'
    ? ['subgroupId', 'roomId', 'seatId', 'invitationToken']
    : ['subgroupId', 'roomId', 'seatId', 'expectedClaimId'];
  if (Object.keys(data).some(key => !allowed.includes(key))) {
    throw new SeatOperationError('invalid-argument', 'Unexpected request field.');
  }
  const required = (field: string): string => {
    const value = data[field];
    if (typeof value !== 'string' || !value.trim() || value.includes('/')) {
      throw new SeatOperationError('invalid-argument', `Invalid ${field}.`);
    }
    return value.trim();
  };
  const parsed: SeatInput = {
    subgroupId: required('subgroupId'), roomId: required('roomId'), seatId: required('seatId'),
  };
  if (operation !== 'claim') {
    const expectedClaimId = required('expectedClaimId');
    return { ...parsed, expectedClaimId };
  }
  if (data.invitationToken !== undefined) {
    if (typeof data.invitationToken !== 'string' || !/^[A-HJ-KM-NP-Z2-9]{16}$/.test(data.invitationToken)) {
      throw new SeatOperationError('invalid-argument', 'Invalid invitation token.');
    }
    return { ...parsed, invitationToken: data.invitationToken };
  }
  return parsed;
}

function ref(db: Firestore, input: SeatInput) {
  const room = db.doc(`subgroups/${input.subgroupId}/rooms/${input.roomId}`);
  return { room, seat: room.collection('seats').doc(input.seatId) };
}

function lease(data: SeatData): Timestamp | undefined {
  return data.leaseExpiresAt instanceof Timestamp ? data.leaseExpiresAt : undefined;
}

function checkCaller(uid: string): void {
  if (!uid || uid.includes('/')) throw new SeatOperationError('permission-denied', 'Authenticated identity is required.');
}

async function verifyEligible(db: Firestore, tx: FirebaseFirestore.Transaction, uid: string, subgroupId: string) {
  try {
    return await verifyRoomCreationEligibility({ firestore: db, transaction: tx, uid, subgroupId });
  } catch (error) {
    if (error instanceof Error && 'code' in error && error.code === 'membership-required') {
      throw new SeatOperationError('permission-denied', 'Active SIG and subgroup membership is required.');
    }
    throw error;
  }
}

function assertRoomOpen(room: SeatData | undefined): asserts room is SeatData {
  if (!room) throw new SeatOperationError('not-found', 'Room not found.');
  if (!['waiting', 'active'].includes(room.status)) {
    throw new SeatOperationError('failed-precondition', 'Room is closed.');
  }
}

function exactMarker(marker: SeatData | undefined, uid: string, input: SeatInput): boolean {
  return marker?.userId === uid && marker.subgroupId === input.subgroupId &&
    marker.roomId === input.roomId && marker.seatId === input.seatId &&
    typeof marker.claimId === 'string' && marker.claimId.length > 0;
}

export function createSeatOperationHandlers(db: Firestore) {
  return {
    async claim(uid: string, raw: unknown) {
      checkCaller(uid);
      const input = parseInput(raw, 'claim');
      if (!(SEATS as readonly string[]).includes(input.seatId)) throw new SeatOperationError('not-found', 'Seat not found.');
      const paths = ref(db, input);
      const markerRef = db.doc(`activeSeatClaims/${uid}`);
      const inviteRef = input.invitationToken ? db.doc(`roomInvites/${input.invitationToken}`) : undefined;
      const now = Timestamp.now();
      const expiry = Timestamp.fromMillis(now.toMillis() + LEASE_MS);
      return db.runTransaction(async tx => {
        const eligibility = await verifyEligible(db, tx, uid, input.subgroupId);
        const roomSnap = await tx.get(paths.room);
        const targetSnap = await tx.get(paths.seat);
        const markerSnap = await tx.get(markerRef);
        const occupiedByCaller = await tx.get(db.collectionGroup('seats').where('userId', '==', uid));
        const profileSnap = await tx.get(db.doc(`users/${uid}`));
        const activeSnap = await tx.get(db.doc(`users/${uid}/activeSession/current`));
        const inviteSnap = inviteRef ? await tx.get(inviteRef) : undefined;
        assertRoomOpen(roomSnap.data());
        if (roomSnap.data()!.subgroupId !== input.subgroupId || roomSnap.data()!.sigId !== eligibility.sigId) {
          throw new SeatOperationError('failed-precondition', 'Room does not belong to this active subgroup and SIG.');
        }
        if (!targetSnap.exists) throw new SeatOperationError('not-found', 'Seat not found.');
        const target = targetSnap.data()!;
        const marker = markerSnap.data();
        if (input.invitationToken) {
          const invite = inviteSnap?.data();
          if (!invite || invite.revoked === true || invite.roomId !== input.roomId ||
              invite.subgroupId !== input.subgroupId || !(invite.expiresAt instanceof Timestamp) ||
              invite.expiresAt.toMillis() <= now.toMillis()) {
            throw new SeatOperationError('failed-precondition', 'Invitation expired or revoked.');
          }
        }
        const userSeats = occupiedByCaller.docs.filter(s => s.get('status') === 'occupied');
        let expiredOwnSeat: QueryDocumentSnapshot | undefined;
        if (userSeats.length > 1) throw new SeatOperationError('failed-precondition', 'Multiple occupied seats need repair.');
        if (userSeats.length === 1) {
          const ownSeat = userSeats[0];
          const ownExpiry = lease(ownSeat.data());
          const ownMarkerMatches = marker && marker.userId === uid &&
            marker.claimId === ownSeat.get('claimId') &&
            ownMarkerPath(marker) === ownSeat.ref.path;
          if (!ownMarkerMatches) throw new SeatOperationError('failed-precondition', 'An occupied seat has an inconsistent claim marker.');
          if (ownExpiry && ownExpiry.toMillis() > now.toMillis()) {
            if (ownSeat.ref.path === paths.seat.path && ownSeat.get('claimId') === marker.claimId) {
              return { seatId: input.seatId, claimId: marker.claimId, claimedAt: ownSeat.get('claimedAt').toMillis(), leaseExpiresAt: ownExpiry.toMillis(), alreadyClaimed: true };
            }
            throw new SeatOperationError('already-exists', 'You already occupy a live seat.');
          }
          // Expired own lease is repaired atomically before assigning this claim.
          expiredOwnSeat = ownSeat;
        } else if (marker) {
          // A marker without its occupied seat is retained as evidence. Refuse to
          // overwrite it; cleanup or an operator can reconcile the inconsistency.
          throw new SeatOperationError('failed-precondition', 'A claim marker needs repair before claiming a seat.');
        }
        if (activeSnap.exists) {
          throw new SeatOperationError('already-exists', 'End your active session before claiming another seat.');
        }
        let expiredOtherMarkerRef: FirebaseFirestore.DocumentReference | undefined;
        if (target.status === 'occupied') {
          const targetExpiry = lease(target);
          if (!targetExpiry || targetExpiry.toMillis() > now.toMillis()) {
            throw new SeatOperationError('resource-exhausted', 'Seat is already occupied.');
          }
          if (target.userId && target.userId !== uid) {
            const otherMarker = await tx.get(db.doc(`activeSeatClaims/${target.userId}`));
            const other = otherMarker.data();
            if (other && (other.claimId !== target.claimId || ownMarkerPath(other) !== paths.seat.path)) {
              throw new SeatOperationError('failed-precondition', 'Expired seat has an inconsistent claim marker.');
            }
            if (other) expiredOtherMarkerRef = otherMarker.ref;
          }
        } else if (target.status !== 'available') {
          throw new SeatOperationError('failed-precondition', 'Seat state is invalid.');
        }
        const claimId = db.collection('_claimIds').doc().id;
        if (expiredOwnSeat) {
          if (expiredOwnSeat.ref.path !== paths.seat.path) {
            tx.set(expiredOwnSeat.ref, {
              seatId: expiredOwnSeat.get('seatId'),
              status: 'available',
            });
          }
        }
        if (expiredOtherMarkerRef) tx.delete(expiredOtherMarkerRef);
        tx.set(paths.seat, {
          seatId: input.seatId, status: 'occupied', userId: uid, claimId,
          claimedAt: now, lastRenewedAt: now, leaseExpiresAt: expiry,
          displayName: profileSnap.data()?.displayName ?? 'Study mate',
          avatarId: profileSnap.data()?.avatarId ?? 'default',
        });
        tx.set(markerRef, {
          userId: uid, subgroupId: input.subgroupId, roomId: input.roomId,
          seatId: input.seatId, claimId, leaseExpiresAt: expiry,
        });
        return { seatId: input.seatId, claimId, claimedAt: now.toMillis(), leaseExpiresAt: expiry.toMillis(), alreadyClaimed: false };
      });
    },

    async release(uid: string, raw: unknown) {
      checkCaller(uid);
      const input = parseInput(raw, 'release');
      if (!(SEATS as readonly string[]).includes(input.seatId)) throw new SeatOperationError('not-found', 'Seat not found.');
      const paths = ref(db, input);
      const markerRef = db.doc(`activeSeatClaims/${uid}`);
      return db.runTransaction(async tx => {
        const eligibility = await verifyEligible(db, tx, uid, input.subgroupId);
        const roomSnap = await tx.get(paths.room);
        const seatSnap = await tx.get(paths.seat);
        const markerSnap = await tx.get(markerRef);
        const activeSnap = await tx.get(db.doc(`users/${uid}/activeSession/current`));
        assertRoomOpen(roomSnap.data());
        const seat = seatSnap.data();
        const marker = markerSnap.data();
        if (roomSnap.data()!.subgroupId !== input.subgroupId || roomSnap.data()!.sigId !== eligibility.sigId) {
          throw new SeatOperationError('failed-precondition', 'Room parent SIG does not match subgroup.');
        }
        if (!seat || seat.status === 'available') return { released: false };
        if (activeSnap.exists) throw new SeatOperationError('failed-precondition', 'End your active session before releasing the seat.');
        if (seat.userId !== uid || seat.claimId !== input.expectedClaimId || !exactMarker(marker, uid, input) || marker!.claimId !== input.expectedClaimId) {
          throw new SeatOperationError('failed-precondition', 'Seat ownership or claim marker changed.');
        }
        tx.set(paths.seat, { seatId: input.seatId, status: 'available' });
        tx.delete(markerRef);
        return { released: true };
      });
    },

    async renew(uid: string, raw: unknown) {
      checkCaller(uid);
      const input = parseInput(raw, 'renew');
      if (!(SEATS as readonly string[]).includes(input.seatId)) throw new SeatOperationError('not-found', 'Seat not found.');
      const paths = ref(db, input);
      const markerRef = db.doc(`activeSeatClaims/${uid}`);
      return db.runTransaction(async tx => {
        const eligibility = await verifyEligible(db, tx, uid, input.subgroupId);
        const roomSnap = await tx.get(paths.room);
        const seatSnap = await tx.get(paths.seat);
        const markerSnap = await tx.get(markerRef);
        const now = Timestamp.now();
        assertRoomOpen(roomSnap.data());
        if (roomSnap.data()!.subgroupId !== input.subgroupId || roomSnap.data()!.sigId !== eligibility.sigId) throw new SeatOperationError('failed-precondition', 'Room parent SIG does not match subgroup.');
        const seat = seatSnap.data();
        const marker = markerSnap.data();
        if (!seat || seat.status !== 'occupied' || seat.userId !== uid || seat.claimId !== input.expectedClaimId ||
            !exactMarker(marker, uid, input) || marker!.claimId !== input.expectedClaimId) {
          throw new SeatOperationError('failed-precondition', 'Seat ownership or claim marker changed.');
        }
        const expires = lease(seat);
        if (!expires || expires.toMillis() <= now.toMillis()) throw new SeatOperationError('failed-precondition', 'Seat lease expired. Claim a seat again.');
        const nextExpiry = Timestamp.fromMillis(now.toMillis() + LEASE_MS);
        tx.update(paths.seat, { lastRenewedAt: now, leaseExpiresAt: nextExpiry });
        tx.update(markerRef, { leaseExpiresAt: nextExpiry });
        return { seatId: input.seatId, claimId: input.expectedClaimId, leaseExpiresAt: nextExpiry.toMillis() };
      });
    },
  };
}

function ownMarkerPath(marker: SeatData): string {
  return `subgroups/${marker.subgroupId}/rooms/${marker.roomId}/seats/${marker.seatId}`;
}
