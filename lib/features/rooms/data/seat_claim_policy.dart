import '../../../core/models/room_models.dart';
import 'seat_claim_result.dart';

const seatLeaseDuration = Duration(minutes: 2);
const fixedRoomSeatIds = <String>[
  'seat-1',
  'seat-2',
  'seat-3',
  'seat-4',
  'seat-5',
  'seat-6',
];

/// In-memory locator decoded from an active-claim record.
///
/// This is a domain value for policy evaluation, not a Firestore schema.
final class ActiveSeatClaimReference {
  const ActiveSeatClaimReference({
    required this.subgroupId,
    required this.roomId,
    required this.seatId,
  });

  final String subgroupId;
  final String roomId;
  final String seatId;

  bool identifies({
    required String subgroupId,
    required String roomId,
    required String seatId,
  }) =>
      this.subgroupId == subgroupId &&
      this.roomId == roomId &&
      this.seatId == seatId;
}

enum ActiveSeatClaimSnapshotKind { missing, valid, malformed }

/// Transaction/fixture view of an active claim and the seat it references.
/// [referencedSeat] must be loaded before policy evaluation for a valid record.
final class ActiveSeatClaimSnapshot {
  const ActiveSeatClaimSnapshot._({
    required this.kind,
    this.reference,
    this.referencedSeat,
  });

  const ActiveSeatClaimSnapshot.missing()
    : this._(kind: ActiveSeatClaimSnapshotKind.missing);

  const ActiveSeatClaimSnapshot.malformed()
    : this._(kind: ActiveSeatClaimSnapshotKind.malformed);

  const ActiveSeatClaimSnapshot.valid({
    required ActiveSeatClaimReference reference,
    required SeatState? referencedSeat,
  }) : this._(
         kind: ActiveSeatClaimSnapshotKind.valid,
         reference: reference,
         referencedSeat: referencedSeat,
       );

  final ActiveSeatClaimSnapshotKind kind;
  final ActiveSeatClaimReference? reference;
  final SeatState? referencedSeat;
}

/// A stale claim which the caller may clean only as part of a successful
/// atomic claim operation. This contains no persisted field representation.
final class StaleSeatClaimCleanup {
  const StaleSeatClaimCleanup({required this.userId, required this.reference});

  final String userId;
  final ActiveSeatClaimReference reference;
}

final class SeatClaimPolicyDecision {
  SeatClaimPolicyDecision({
    required this.result,
    Iterable<StaleSeatClaimCleanup> staleClaimsToClean = const [],
  }) : staleClaimsToClean = List.unmodifiable(staleClaimsToClean);

  final SeatClaimResult result;
  final List<StaleSeatClaimCleanup> staleClaimsToClean;
}

/// Pure claim decision logic. Time and transaction reads are supplied by the
/// caller; this class never accesses Firebase or the system clock.
abstract final class SeatClaimPolicy {
  static SeatClaimPolicyDecision evaluate({
    required RoomStatus roomStatus,
    required String subgroupId,
    required String roomId,
    required Iterable<SeatState> seats,
    required String requestedSeatId,
    required String userId,
    required DateTime nowUtc,
    required Map<String, ActiveSeatClaimSnapshot> activeClaimsByUser,
  }) {
    if (!fixedRoomSeatIds.contains(requestedSeatId)) {
      return _failure(SeatClaimFailure.seatNotFound);
    }
    if (roomStatus == RoomStatus.completed || roomStatus == RoomStatus.closed) {
      return _failure(SeatClaimFailure.roomUnavailable);
    }

    late final List<SeatState> validatedSeats;
    try {
      validatedSeats = validateSeatCollection(seats);
    } on ArgumentError {
      return _failure(SeatClaimFailure.unavailable);
    }

    final seatIds = validatedSeats.map((seat) => seat.seatId).toSet();
    if (!seatIds.containsAll(fixedRoomSeatIds) ||
        fixedRoomSeatIds.any((id) => !seatIds.contains(id))) {
      return _failure(SeatClaimFailure.unavailable);
    }

    final now = nowUtc.toUtc();
    if (userId.trim().isEmpty ||
        subgroupId.trim().isEmpty ||
        roomId.trim().isEmpty) {
      return _failure(SeatClaimFailure.unavailable);
    }

    for (final seat in validatedSeats) {
      if (seat.status == SeatStatus.occupied &&
          (seat.userId == null ||
              seat.userId!.trim().isEmpty ||
              seat.leaseExpiresAt == null)) {
        return _failure(SeatClaimFailure.unavailable);
      }
    }

    final requestedSeat = validatedSeats.firstWhere(
      (seat) => seat.seatId == requestedSeatId,
    );
    final cleanups = <StaleSeatClaimCleanup>[];

    final userClaim =
        activeClaimsByUser[userId] ?? const ActiveSeatClaimSnapshot.missing();
    switch (userClaim.kind) {
      case ActiveSeatClaimSnapshotKind.malformed:
        return _failure(SeatClaimFailure.unavailable);
      case ActiveSeatClaimSnapshotKind.missing:
        break;
      case ActiveSeatClaimSnapshotKind.valid:
        final reference = userClaim.reference;
        final referencedSeat = userClaim.referencedSeat;
        if (reference == null ||
            !_validReferencedSeat(
              userId: userId,
              reference: reference,
              seat: referencedSeat,
            )) {
          return _failure(SeatClaimFailure.unavailable);
        }

        final sameRequestedSeat = reference.identifies(
          subgroupId: subgroupId,
          roomId: roomId,
          seatId: requestedSeatId,
        );
        final leaseExpiry = referencedSeat!.leaseExpiresAt!.toUtc();
        if (leaseExpiry.isAfter(now)) {
          if (sameRequestedSeat &&
              requestedSeat.status == SeatStatus.occupied &&
              requestedSeat.userId == userId) {
            return SeatClaimPolicyDecision(
              result: SeatClaimSucceeded(
                seat: requestedSeat,
                wasAlreadyClaimed: true,
              ),
            );
          }
          return _failure(SeatClaimFailure.alreadySeated);
        }

        cleanups.add(
          StaleSeatClaimCleanup(userId: userId, reference: reference),
        );
    }

    final requestedOccupantId = requestedSeat.userId;
    final requestedExpiry = requestedSeat.leaseExpiresAt?.toUtc();
    if (requestedSeat.status == SeatStatus.occupied) {
      if (requestedOccupantId == null || requestedExpiry == null) {
        return _failure(SeatClaimFailure.unavailable);
      }
      final occupantClaim =
          activeClaimsByUser[requestedOccupantId] ??
          const ActiveSeatClaimSnapshot.missing();
      if (occupantClaim.kind != ActiveSeatClaimSnapshotKind.valid ||
          occupantClaim.reference == null ||
          !_validReferencedSeat(
            userId: requestedOccupantId,
            reference: occupantClaim.reference!,
            seat: occupantClaim.referencedSeat,
          ) ||
          !occupantClaim.reference!.identifies(
            subgroupId: subgroupId,
            roomId: roomId,
            seatId: requestedSeatId,
          )) {
        return _failure(SeatClaimFailure.unavailable);
      }
    }

    final liveOccupiedSeats = validatedSeats
        .where(
          (seat) =>
              seat.status == SeatStatus.occupied &&
              seat.leaseExpiresAt!.toUtc().isAfter(now),
        )
        .length;
    if (liveOccupiedSeats == fixedRoomSeatIds.length) {
      return _failure(SeatClaimFailure.fullRoom);
    }

    if (requestedSeat.status == SeatStatus.occupied) {
      if (requestedExpiry!.isAfter(now)) {
        return _failure(SeatClaimFailure.seatTaken);
      }
      if (requestedOccupantId != userId &&
          !cleanups.any((cleanup) => cleanup.userId == requestedOccupantId)) {
        cleanups.add(
          StaleSeatClaimCleanup(
            userId: requestedOccupantId!,
            reference: activeClaimsByUser[requestedOccupantId]!.reference!,
          ),
        );
      }
    }

    final claimedAt = now;
    return SeatClaimPolicyDecision(
      result: SeatClaimSucceeded(
        seat: SeatState(
          seatId: requestedSeatId,
          status: SeatStatus.occupied,
          userId: userId,
          claimedAt: claimedAt,
          leaseExpiresAt: claimedAt.add(seatLeaseDuration),
          lastRenewedAt: claimedAt,
        ),
        wasAlreadyClaimed: false,
      ),
      staleClaimsToClean: cleanups,
    );
  }

  static bool _validReferencedSeat({
    required String userId,
    required ActiveSeatClaimReference reference,
    required SeatState? seat,
  }) =>
      reference.subgroupId.trim().isNotEmpty &&
      reference.roomId.trim().isNotEmpty &&
      reference.seatId.trim().isNotEmpty &&
      seat != null &&
      seat.seatId == reference.seatId &&
      seat.status == SeatStatus.occupied &&
      seat.userId == userId &&
      seat.leaseExpiresAt != null;

  static SeatClaimPolicyDecision _failure(SeatClaimFailure failure) =>
      SeatClaimPolicyDecision(result: SeatClaimFailed(failure));
}
