import '../../../core/models/community_models.dart';

abstract interface class RoomRepository {
  Future<List<RoomSummary>> listRooms(String subgroupId);
  Future<RoomSummary?> getRoom(String id);
}
