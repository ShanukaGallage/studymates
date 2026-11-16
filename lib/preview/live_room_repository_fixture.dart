import 'dart:async';

import '../core/models/community_models.dart';
import '../core/models/room_models.dart';
import '../features/rooms/data/room_repository.dart';

typedef FixtureRoomMembershipCheck = Future<bool> Function({
  required String sigId,
  required String subgroupId,
});

/// In-memory implementation of the live room contract for tests and previews.
///
/// It deliberately contains no Firestore paths or M2 implementation. The
/// injected membership callback is a fixture seam, not a production service.
final class FixtureLiveRoomRepository implements LiveRoomRepository {
  FixtureLiveRoomRepository({
    required Map<String, String> subgroupSigIds,
    required this.verifyMembership,
    required this.currentUserId,
    DateTime Function()? clock,
    Iterable<({RoomSnapshot room, Iterable<SeatState> seats})> initialRooms =
        const [],
  }) : _subgroupSigIds = Map.unmodifiable(subgroupSigIds),
       _clock = clock ?? DateTime.now {
    for (final initial in initialRooms) {
      final seats = validateSeatCollection(initial.seats);
      if (initial.room.roomId.trim().isEmpty ||
          initial.room.subgroupId.trim().isEmpty ||
          initial.room.title.trim().isEmpty ||
          initial.room.createdBy.trim().isEmpty ||
          initial.room.hostUid.trim().isEmpty ||
          _rooms.containsKey(initial.room.roomId)) {
        throw const RoomRepositoryException(RoomRepositoryError.invalidData);
      }
      _rooms[initial.room.roomId] = _StoredRoom(initial.room, seats);
    }
  }

  final Map<String, String> _subgroupSigIds;
  final FixtureRoomMembershipCheck verifyMembership;
  final String Function() currentUserId;
  final DateTime Function() _clock;
  final Map<String, _StoredRoom> _rooms = {};
  final Map<String, StreamController<List<RoomSnapshot>>> _roomListWatchers =
      {};
  final Map<String, StreamController<RoomSnapshot?>> _roomWatchers = {};
  final Map<String, StreamController<List<SeatState>>> _seatWatchers = {};
  int _nextRoomId = 1;
  bool _disposed = false;

  @override
  Future<RoomSnapshot> createRoom({
    required String subgroupId,
    required String title,
  }) async {
    _ensureOpen();
    final normalizedSubgroupId = subgroupId.trim();
    final normalizedTitle = title.trim();
    if (normalizedSubgroupId.isEmpty || normalizedTitle.isEmpty) {
      throw const RoomRepositoryException(RoomRepositoryError.invalidData);
    }

    final sigId = _subgroupSigIds[normalizedSubgroupId];
    if (sigId == null || sigId.isEmpty) {
      throw const RepositoryException(RepositoryError.notFound);
    }
    final userId = currentUserId().trim();
    if (userId.isEmpty) {
      throw const RoomRepositoryException(RoomRepositoryError.permissionDenied);
    }
    if (!await verifyMembership(
      sigId: sigId,
      subgroupId: normalizedSubgroupId,
    )) {
      throw const RoomRepositoryException(
        RoomRepositoryError.membershipRequired,
      );
    }

    final now = _clock().toUtc();
    final roomId = _newRoomId();
    final room = RoomSnapshot(
      roomId: roomId,
      subgroupId: normalizedSubgroupId,
      title: normalizedTitle,
      createdBy: userId,
      hostUid: userId,
      status: RoomStatus.waiting,
      createdAt: now,
      updatedAt: now,
    );
    final seats = validateSeatCollection([
      for (var number = 1; number <= 6; number++)
        SeatState(seatId: 'seat-$number', status: SeatStatus.available),
    ]);
    _rooms[roomId] = _StoredRoom(room, seats);
    _emitRoomList(normalizedSubgroupId);
    _emitRoom(roomId);
    _emitSeats(roomId);
    return room;
  }

  String _newRoomId() {
    String roomId;
    do {
      roomId = 'room-${(_nextRoomId++).toString().padLeft(6, '0')}';
    } while (_rooms.containsKey(roomId));
    return roomId;
  }

  @override
  Future<List<RoomSnapshot>> listRoomSnapshots(String subgroupId) async {
    _ensureOpen();
    final id = subgroupId.trim();
    return List.unmodifiable(
      _rooms.values
          .where((stored) => stored.room.subgroupId == id)
          .map((stored) => stored.room),
    );
  }

  @override
  Future<RoomSnapshot?> getRoomSnapshot(String roomId) async {
    _ensureOpen();
    return _rooms[roomId]?.room;
  }

  @override
  Future<List<RoomSummary>> listRooms(String subgroupId) async {
    final rooms = await listRoomSnapshots(subgroupId);
    return List.unmodifiable(rooms.map(_summaryFor));
  }

  @override
  Future<RoomSummary?> getRoom(String id) async {
    final room = await getRoomSnapshot(id);
    return room == null ? null : _summaryFor(room);
  }

  @override
  Stream<List<RoomSnapshot>> watchRooms(String subgroupId) {
    _ensureOpen();
    final id = subgroupId.trim();
    final controller = _roomListWatchers.putIfAbsent(
      id,
      () => StreamController<List<RoomSnapshot>>.broadcast(
        onListen: () => _emitRoomList(id),
      ),
    );
    return controller.stream;
  }

  @override
  Stream<RoomSnapshot?> watchRoom(String roomId) {
    _ensureOpen();
    final controller = _roomWatchers.putIfAbsent(
      roomId,
      () => StreamController<RoomSnapshot?>.broadcast(
        onListen: () => _emitRoom(roomId),
      ),
    );
    return controller.stream;
  }

  @override
  Stream<List<SeatState>> watchSeats(String roomId) {
    _ensureOpen();
    final controller = _seatWatchers.putIfAbsent(
      roomId,
      () => StreamController<List<SeatState>>.broadcast(
        onListen: () => _emitSeats(roomId),
      ),
    );
    return controller.stream;
  }

  /// Closes local streams. This is fixture lifecycle support, not a room API.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait([
      for (final controller in _roomListWatchers.values) controller.close(),
      for (final controller in _roomWatchers.values) controller.close(),
      for (final controller in _seatWatchers.values) controller.close(),
    ]);
  }

  RoomSummary _summaryFor(RoomSnapshot room) {
    final seats = _rooms[room.roomId]!.seats;
    return RoomSummary(
      id: room.roomId,
      subgroupId: room.subgroupId,
      title: room.title,
      occupiedSeats: seats
          .where((seat) => seat.status == SeatStatus.occupied)
          .length,
    );
  }

  void _emitRoomList(String subgroupId) {
    final controller = _roomListWatchers[subgroupId];
    if (controller == null || controller.isClosed || !controller.hasListener) {
      return;
    }
    controller.add(
      List.unmodifiable(
        _rooms.values
            .where((stored) => stored.room.subgroupId == subgroupId)
            .map((stored) => stored.room),
      ),
    );
  }

  void _emitRoom(String roomId) {
    final controller = _roomWatchers[roomId];
    if (controller == null || controller.isClosed || !controller.hasListener) {
      return;
    }
    controller.add(_rooms[roomId]?.room);
  }

  void _emitSeats(String roomId) {
    final controller = _seatWatchers[roomId];
    if (controller == null || controller.isClosed || !controller.hasListener) {
      return;
    }
    controller.add(_rooms[roomId]?.seats ?? const <SeatState>[]);
  }

  void _ensureOpen() {
    if (_disposed) throw StateError('Room repository fixture is disposed.');
  }
}

final class _StoredRoom {
  const _StoredRoom(this.room, this.seats);

  final RoomSnapshot room;
  final List<SeatState> seats;
}
