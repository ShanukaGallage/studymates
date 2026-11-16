enum SeatLeaseFailure {
  notAuthenticated,
  seatChanged,
  leaseExpired,
  membershipRequired,
  permissionDenied,
  unavailable,
}

sealed class SeatLeaseResult {
  const SeatLeaseResult();
}

final class SeatLeaseSucceeded extends SeatLeaseResult {
  const SeatLeaseSucceeded();
}

final class SeatLeaseFailed extends SeatLeaseResult {
  const SeatLeaseFailed(this.reason, this.message);
  final SeatLeaseFailure reason;
  final String message;
}

/// Expected claim identity protects against delayed requests affecting a later seat.
abstract interface class SeatLeaseRepository {
  Future<SeatLeaseResult> releaseSeat({
    required String subgroupId,
    required String roomId,
    required String seatId,
    required String expectedClaimId,
  });
  Future<SeatLeaseResult> renewSeatLease({
    required String subgroupId,
    required String roomId,
    required String seatId,
    required String expectedClaimId,
  });
}
