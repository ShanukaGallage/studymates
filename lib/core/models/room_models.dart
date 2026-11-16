enum RoomStatus { waiting, active, completed, closed }

enum SeatStatus { available, occupied }

final class RoomSnapshot {
  RoomSnapshot({
    required this.roomId,
    required this.subgroupId,
    required this.title,
    required this.createdBy,
    required this.hostUid,
    required this.status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc();

  final String roomId;
  final String subgroupId;
  final String title;
  final String createdBy;
  final String hostUid;
  final RoomStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class SeatState {
  SeatState({
    required this.seatId,
    required this.status,
    this.userId,
    DateTime? claimedAt,
    DateTime? leaseExpiresAt,
    DateTime? lastRenewedAt,
  }) : claimedAt = claimedAt?.toUtc(),
       leaseExpiresAt = leaseExpiresAt?.toUtc(),
       lastRenewedAt = lastRenewedAt?.toUtc() {
    _validate();
  }

  final String seatId;
  final String? userId;
  final SeatStatus status;
  final DateTime? claimedAt;
  final DateTime? leaseExpiresAt;
  final DateTime? lastRenewedAt;

  void _validate() {
    if (status == SeatStatus.available &&
        (userId != null ||
            claimedAt != null ||
            leaseExpiresAt != null ||
            lastRenewedAt != null)) {
      throw ArgumentError(
        'Available seats cannot have occupant or lease data.',
      );
    }

    if (status == SeatStatus.occupied &&
        (userId == null || claimedAt == null)) {
      throw ArgumentError('Occupied seats require a user ID and claim time.');
    }
  }
}

List<SeatState> validateSeatCollection(Iterable<SeatState> seats) {
  final validatedSeats = List<SeatState>.unmodifiable(seats);
  if (validatedSeats.length != 6) {
    throw ArgumentError.value(
      validatedSeats.length,
      'seats',
      'A room must have exactly six seats.',
    );
  }

  final seatIds = <String>{};
  for (final seat in validatedSeats) {
    seat._validate();
    if (!seatIds.add(seat.seatId)) {
      throw ArgumentError.value(
        seat.seatId,
        'seats',
        'Seat IDs must be unique within a room.',
      );
    }
  }

  return validatedSeats;
}
