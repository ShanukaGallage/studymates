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
    this.capacity = 6,
    this.isPrivate = false,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    if (capacity < 2 || capacity > 40) {
      throw ArgumentError.value(capacity, 'capacity', 'Must be 2–40');
    }
  }

  final String roomId;
  final String subgroupId;
  final String title;
  final String createdBy;
  final String hostUid;
  final RoomStatus status;
  final int capacity;
  final bool isPrivate;
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

List<SeatState> validateSeatCollection(
  Iterable<SeatState> seats, {
  int capacity = 6,
}) {
  final validatedSeats = List<SeatState>.unmodifiable(seats);
  if (capacity < 2 || capacity > 40 || validatedSeats.length != capacity) {
    throw ArgumentError.value(
      validatedSeats.length,
      'seats',
      'A room must have exactly its configured capacity (2–40 seats).',
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
