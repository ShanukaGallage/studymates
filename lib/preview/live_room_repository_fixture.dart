import 'dart:async';

import '../core/models/community_models.dart';
import '../core/models/room_models.dart';
import '../features/rooms/data/room_repository.dart';
import '../features/rooms/data/seat_claim_policy.dart';
import '../features/rooms/data/seat_claim_result.dart';

enum FixtureMembershipCheckResult {
  member,
  nonMember,
  permissionDenied,
  unavailable,
}

typedef FixtureRoomMembershipCheck =
    Future<FixtureMembershipCheckResult> Function({
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
    this._beforeClaimApplyForTest,
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
  final void Function()? _beforeClaimApplyForTest;
  final Map<String, _StoredRoom> _rooms = {};
  final Map<String, StreamController<List<RoomSnapshot>>> _roomListWatchers =
      {};
  final Map<String, StreamController<RoomSnapshot?>> _roomWatchers = {};
  final Map<String, StreamController<List<SeatState>>> _seatWatchers = {};
  int _nextRoomId = 1;
  bool _disposed = false;
  final Set<String> _malformedActiveClaimUsers = {};

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
    final membership = await verifyMembership(
      sigId: sigId,
      subgroupId: normalizedSubgroupId,
    );
    switch (membership) {
      case FixtureMembershipCheckResult.member:
        break;
      case FixtureMembershipCheckResult.nonMember:
        throw const RoomRepositoryException(
          RoomRepositoryError.membershipRequired,
        );
      case FixtureMembershipCheckResult.permissionDenied:
        throw const RoomRepositoryException(
          RoomRepositoryError.permissionDenied,
        );
      case FixtureMembershipCheckResult.unavailable:
        throw const RoomRepositoryException(RoomRepositoryError.unavailable);
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

  /// Deterministic local claim behavior for tests and UI integration only.
  /// This method does not provide Firestore transaction atomicity.
  @override
  Future<SeatClaimResult> claimSeat({
    required String subgroupId,
    required String roomId,
    required String seatId,
  }) async {
    _ensureOpen();
    final roomData = _rooms[roomId];
    if (roomData == null || roomData.room.subgroupId != subgroupId) {
      return const SeatClaimFailed(SeatClaimFailure.roomUnavailable);
    }

    final userId = currentUserId().trim();
    if (userId.isEmpty) {
      return const SeatClaimFailed(SeatClaimFailure.permissionDenied);
    }
    final sigId = _subgroupSigIds[subgroupId];
    if (sigId == null || sigId.isEmpty) {
      return const SeatClaimFailed(SeatClaimFailure.unavailable);
    }

    final membership = await verifyMembership(
      sigId: sigId,
      subgroupId: subgroupId,
    );
    final membershipFailure = switch (membership) {
      FixtureMembershipCheckResult.member => null,
      FixtureMembershipCheckResult.nonMember =>
        SeatClaimFailure.membershipRequired,
      FixtureMembershipCheckResult.permissionDenied =>
        SeatClaimFailure.permissionDenied,
      FixtureMembershipCheckResult.unavailable => SeatClaimFailure.unavailable,
    };
    if (membershipFailure case final failure?) {
      return SeatClaimFailed(failure);
    }

    final requestedSeat = roomData.seats
        .where((seat) => seat.seatId == seatId)
        .firstOrNull;
    final userIds = <String>{userId, ?requestedSeat?.userId};
    final activeClaims = <String, ActiveSeatClaimSnapshot>{
      for (final id in userIds) id: _activeClaimSnapshot(id),
    };
    final decision = SeatClaimPolicy.evaluate(
      roomStatus: roomData.room.status,
      subgroupId: subgroupId,
      roomId: roomId,
      seats: roomData.seats,
      requestedSeatId: seatId,
      userId: userId,
      nowUtc: _clock().toUtc(),
      activeClaimsByUser: activeClaims,
    );
    final result = decision.result;
    if (result case SeatClaimSucceeded(:final seat, :final wasAlreadyClaimed)) {
      if (wasAlreadyClaimed) return result;
      _beforeClaimApplyForTest?.call();

      // Prepare every changed seat collection and validate every cleanup
      // against the current fixture state before changing any shared state.
      final seatIndex = roomData.seats.indexWhere(
        (value) => value.seatId == seatId,
      );
      if (seatIndex < 0) {
        return const SeatClaimFailed(SeatClaimFailure.seatNotFound);
      }
      final now = _clock().toUtc();
      final changedSeats = <String, List<SeatState>>{};
      final cleanupUsers = <String>{};
      for (final cleanup in decision.staleClaimsToClean) {
        final reference = cleanup.reference;
        final currentReference = _activeSeatClaims[cleanup.userId];
        final oldRoom = _rooms[reference.roomId];
        if (cleanup.userId.trim().isEmpty ||
            !cleanupUsers.add(cleanup.userId) ||
            _malformedActiveClaimUsers.contains(cleanup.userId) ||
            currentReference == null ||
            !_sameClaimReference(currentReference, reference) ||
            oldRoom == null ||
            oldRoom.room.subgroupId != reference.subgroupId) {
          return const SeatClaimFailed(SeatClaimFailure.unavailable);
        }
        final oldSeats = changedSeats.putIfAbsent(
          oldRoom.room.roomId,
          () => [...oldRoom.seats],
        );
        final oldSeatIndex = oldSeats.indexWhere(
          (oldSeat) => oldSeat.seatId == reference.seatId,
        );
        if (oldSeatIndex < 0) {
          return const SeatClaimFailed(SeatClaimFailure.unavailable);
        }
        final oldSeat = oldSeats[oldSeatIndex];
        if (oldSeat.status != SeatStatus.occupied ||
            oldSeat.userId != cleanup.userId ||
            oldSeat.leaseExpiresAt == null ||
            oldSeat.leaseExpiresAt!.toUtc().isAfter(now)) {
          return const SeatClaimFailed(SeatClaimFailure.unavailable);
        }
        if (oldRoom.room.roomId != roomId || oldSeat.seatId != seatId) {
          oldSeats[oldSeatIndex] = SeatState(
            seatId: reference.seatId,
            status: SeatStatus.available,
          );
        }
      }

      final targetSeats = changedSeats.putIfAbsent(
        roomId,
        () => [...roomData.seats],
      );
      targetSeats[seatIndex] = seat;
      final validatedChanges = <String, List<SeatState>>{};
      try {
        for (final entry in changedSeats.entries) {
          validatedChanges[entry.key] = validateSeatCollection(entry.value);
        }
      } on ArgumentError {
        return const SeatClaimFailed(SeatClaimFailure.unavailable);
      }

      // Commit the already validated local plan only after all checks pass.
      for (final entry in validatedChanges.entries) {
        _rooms[entry.key]!.seats = entry.value;
      }
      for (final cleanupUser in cleanupUsers) {
        _activeSeatClaims.remove(cleanupUser);
        _malformedActiveClaimUsers.remove(cleanupUser);
      }
      _activeSeatClaims[userId] = ActiveSeatClaimReference(
        subgroupId: subgroupId,
        roomId: roomId,
        seatId: seatId,
      );
      _malformedActiveClaimUsers.remove(userId);
      for (final changedRoomId in validatedChanges.keys) {
        final changedRoom = _rooms[changedRoomId]!;
        _emitSeats(changedRoomId);
        _emitRoom(changedRoomId);
        _emitRoomList(changedRoom.room.subgroupId);
      }
      return result;
    }
    return result;
  }

  final Map<String, ActiveSeatClaimReference> _activeSeatClaims = {};

  /// Read-only fixture introspection for consistency tests, not a repository
  /// operation or persisted record representation.
  ActiveSeatClaimReference? activeSeatClaimForTest(String userId) =>
      _activeSeatClaims[userId];

  bool _sameClaimReference(
    ActiveSeatClaimReference first,
    ActiveSeatClaimReference second,
  ) =>
      first.subgroupId == second.subgroupId &&
      first.roomId == second.roomId &&
      first.seatId == second.seatId;

  /// Seeds fixture state for status/data-integrity tests only.
  void seedRoomForTest(RoomSnapshot room, Iterable<SeatState> seats) {
    _ensureOpen();
    final validatedSeats = validateSeatCollection(seats);
    if (room.roomId.trim().isEmpty ||
        room.subgroupId.trim().isEmpty ||
        room.title.trim().isEmpty ||
        room.createdBy.trim().isEmpty ||
        room.hostUid.trim().isEmpty ||
        _rooms.containsKey(room.roomId)) {
      throw const RoomRepositoryException(RoomRepositoryError.invalidData);
    }
    _rooms[room.roomId] = _StoredRoom(room, validatedSeats);
  }

  /// Marks a fixture claim as unreadable/inconsistent without deleting it.
  void corruptActiveSeatClaimForTest(String userId) {
    if (!_activeSeatClaims.containsKey(userId)) {
      throw ArgumentError.value(userId, 'userId', 'No fixture claim exists.');
    }
    _malformedActiveClaimUsers.add(userId);
  }

  ActiveSeatClaimSnapshot _activeClaimSnapshot(String userId) {
    if (_malformedActiveClaimUsers.contains(userId)) {
      return const ActiveSeatClaimSnapshot.malformed();
    }
    final reference = _activeSeatClaims[userId];
    if (reference == null) return const ActiveSeatClaimSnapshot.missing();

    final room = _rooms[reference.roomId];
    if (room == null || room.room.subgroupId != reference.subgroupId) {
      return const ActiveSeatClaimSnapshot.malformed();
    }
    final seat = room.seats
        .where((candidate) => candidate.seatId == reference.seatId)
        .firstOrNull;
    if (seat == null) return const ActiveSeatClaimSnapshot.malformed();
    return ActiveSeatClaimSnapshot.valid(
      reference: reference,
      referencedSeat: seat,
    );
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
  _StoredRoom(this.room, this.seats);

  final RoomSnapshot room;
  List<SeatState> seats;
}
