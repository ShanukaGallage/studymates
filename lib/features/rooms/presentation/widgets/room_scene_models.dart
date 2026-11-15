// Presentation inputs only. These are not server reservations or presence records.
enum RoomSeatStatus { available, occupied, selected, yours, pending, failed }

class SeatOccupant {
  const SeatOccupant({required this.name, required this.avatarId});
  final String name;
  final String avatarId;
}

class RoomSeat {
  const RoomSeat({required this.number, required this.status, this.occupant});
  final int number;
  final RoomSeatStatus status;
  final SeatOccupant? occupant;

  String get description => switch (status) {
    RoomSeatStatus.available => 'Available',
    RoomSeatStatus.occupied =>
      'Occupied by ${occupant?.name ?? 'a sample learner'}',
    RoomSeatStatus.selected => 'Selected in preview',
    RoomSeatStatus.yours => 'Yours in sample data',
    RoomSeatStatus.pending => 'Selection pending',
    RoomSeatStatus.failed => 'Selection failed. Tap to retry',
  };
}
