import '../../../core/models/community_models.dart';
import '../../../core/models/room_models.dart';

abstract interface class RoomRepository {
  Future<List<RoomSummary>> listRooms(String subgroupId);
  Future<RoomSummary?> getRoom(String id);
}

/// Live room data operations consumed by M3 integration and M1 presentation.
///
/// This extends the existing discovery API without changing its summary types.
abstract interface class LiveRoomRepository implements RoomRepository {
  Future<RoomSnapshot> createRoom({
    required String subgroupId,
    required String title,
  });

  Future<List<RoomSnapshot>> listRoomSnapshots(String subgroupId);

  Future<RoomSnapshot?> getRoomSnapshot(String roomId);

  Stream<List<RoomSnapshot>> watchRooms(String subgroupId);

  Stream<RoomSnapshot?> watchRoom(String roomId);

  Stream<List<SeatState>> watchSeats(String roomId);
}

enum RoomRepositoryError {
  invalidData,
  membershipRequired,
  permissionDenied,
  unavailable,
}

class RoomRepositoryException implements Exception {
  const RoomRepositoryException(this.code);

  final RoomRepositoryError code;

  @override
  String toString() => 'RoomRepositoryException($code)';
}
