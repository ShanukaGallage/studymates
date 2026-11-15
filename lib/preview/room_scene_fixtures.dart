import '../features/rooms/presentation/widgets/room_scene_models.dart';
import 'community_fixtures.dart';

const _sampleOccupants = [
  SeatOccupant(name: 'Sam (sample)', avatarId: 'mint'),
  SeatOccupant(name: 'Maya (sample)', avatarId: 'amber'),
  SeatOccupant(name: 'Noah (sample)', avatarId: 'mint'),
  SeatOccupant(name: 'Isha (sample)', avatarId: 'amber'),
  SeatOccupant(name: 'Leo (sample)', avatarId: 'mint'),
  SeatOccupant(name: 'Ari (sample)', avatarId: 'amber'),
];

List<RoomSeat> roomSceneFixtures(String roomId) {
  final matches = previewRooms.where((room) => room.id == roomId);
  if (matches.isEmpty) return const [];
  final room = matches.single;
  return List.unmodifiable(
    List.generate(
      room.capacity,
      (index) => RoomSeat(
        number: index + 1,
        status: index < room.occupiedSeats
            ? RoomSeatStatus.occupied
            : RoomSeatStatus.available,
        occupant: index < room.occupiedSeats ? _sampleOccupants[index] : null,
      ),
    ),
  );
}

// Isolated gallery samples: every state can be inspected without claiming a seat.
const galleryRoomSeats = [
  RoomSeat(number: 1, status: RoomSeatStatus.available),
  RoomSeat(
    number: 2,
    status: RoomSeatStatus.occupied,
    occupant: SeatOccupant(name: 'Sam (sample)', avatarId: 'mint'),
  ),
  RoomSeat(number: 3, status: RoomSeatStatus.selected),
  RoomSeat(
    number: 4,
    status: RoomSeatStatus.yours,
    occupant: SeatOccupant(name: 'You (sample)', avatarId: 'amber'),
  ),
  RoomSeat(number: 5, status: RoomSeatStatus.pending),
  RoomSeat(number: 6, status: RoomSeatStatus.failed),
];
