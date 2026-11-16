import '../../../core/models/room_models.dart';

sealed class SeatClaimResult {
  const SeatClaimResult();
}

final class SeatClaimSucceeded extends SeatClaimResult {
  const SeatClaimSucceeded({
    required this.seat,
    required this.wasAlreadyClaimed,
  });

  final SeatState seat;
  final bool wasAlreadyClaimed;
}

enum SeatClaimFailure {
  invitationRequired,
  seatTaken,
  fullRoom,
  alreadySeated,
  membershipRequired,
  permissionDenied,
  roomUnavailable,
  seatNotFound,
  unavailable,
}

final class SeatClaimFailed extends SeatClaimResult {
  const SeatClaimFailed(this.failure);

  final SeatClaimFailure failure;
}