import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/core/models/room_models.dart';
import 'package:studymates/features/communities/data/membership_repository.dart';
import 'package:studymates/features/rooms/data/firestore_live_room_repository.dart';
import 'package:studymates/features/rooms/data/room_repository.dart';
import 'package:studymates/features/rooms/data/seat_claim_result.dart';

void main() {
  final nowUtc = DateTime.utc(2026, 11, 16, 9);

  group('RoomFirestoreCodec', () {
    test('round-trips room fields and UTC timestamps', () {
      final room = RoomSnapshot(
        roomId: 'room-a',
        subgroupId: 'subgroup-a',
        title: 'Study room',
        createdBy: 'user-a',
        hostUid: 'user-a',
        status: RoomStatus.waiting,
        createdAt: nowUtc,
        updatedAt: nowUtc.add(const Duration(seconds: 1)),
      );

      final data = RoomFirestoreCodec.serializeRoom(room);
      final parsed = RoomFirestoreCodec.deserializeRoom(data);

      expect(
        data.keys,
        containsAll([
          'roomId',
          'subgroupId',
          'title',
          'createdBy',
          'hostUid',
          'status',
          'createdAt',
          'updatedAt',
        ]),
      );
      expect(parsed.roomId, room.roomId);
      expect(parsed.status, room.status);
      expect(parsed.createdAt, nowUtc);
      expect(parsed.createdAt.isUtc, isTrue);
    });

    test('round-trips available and occupied seat fields', () {
      final available = SeatState(
        seatId: 'seat-1',
        status: SeatStatus.available,
      );
      final occupied = SeatState(
        seatId: 'seat-2',
        status: SeatStatus.occupied,
        userId: 'user-a',
        claimedAt: nowUtc,
        leaseExpiresAt: nowUtc.add(const Duration(minutes: 2)),
        lastRenewedAt: nowUtc,
      );

      final parsedAvailable = RoomFirestoreCodec.deserializeSeat(
        RoomFirestoreCodec.serializeSeat(available),
      );
      final parsedOccupied = RoomFirestoreCodec.deserializeSeat(
        RoomFirestoreCodec.serializeSeat(occupied),
      );

      expect(parsedAvailable.status, SeatStatus.available);
      expect(parsedAvailable.leaseExpiresAt, isNull);
      expect(parsedOccupied.userId, 'user-a');
      expect(
        parsedOccupied.leaseExpiresAt,
        nowUtc.add(const Duration(minutes: 2)),
      );
      expect(parsedOccupied.lastRenewedAt!.isUtc, isTrue);
    });

    test('rejects malformed persisted room or seat values', () {
      expect(
        () => RoomFirestoreCodec.deserializeRoom(const {}),
        throwsFormatException,
      );
      expect(
        () => RoomFirestoreCodec.deserializeSeat(const {
          'seatId': 'seat-1',
          'status': 'reserved',
        }),
        throwsFormatException,
      );
    });
  });

  group('FirestoreLiveRoomRepository with a fake document store', () {
    late _FakeRoomDocumentStore store;
    late _FakeMembershipRepository membership;
    late FirestoreLiveRoomRepository repository;

    setUp(() {
      store = _FakeRoomDocumentStore();
      store.documents['subgroups/subgroup-a'] = {'sigId': 'sig-a'};
      membership = _FakeMembershipRepository();
      repository = FirestoreLiveRoomRepository(
        documentStore: store,
        membershipRepository: membership,
        currentUserId: () => 'user-a',
        clock: () => nowUtc,
      );
    });

    test(
      'creates room and exactly six seats after transaction membership',
      () async {
        final room = await repository.createRoom(
          subgroupId: 'subgroup-a',
          title: '  Study room  ',
        );

        expect(room.roomId, 'room-1');
        expect(room.title, 'Study room');
        expect(room.createdBy, 'user-a');
        expect(room.hostUid, 'user-a');
        expect(room.createdAt, nowUtc);
        expect(membership.transaction, same(store.lastTransaction));
        expect(store.documents['subgroups/subgroup-a/rooms/room-1'], isNotNull);
        final seats = store.documents.entries
            .where(
              (entry) => entry.key.startsWith(
                'subgroups/subgroup-a/rooms/room-1/seats/',
              ),
            )
            .toList();
        expect(seats, hasLength(6));
        expect(seats.map((entry) => entry.value['seatId']).toSet(), {
          'seat-1',
          'seat-2',
          'seat-3',
          'seat-4',
          'seat-5',
          'seat-6',
        });
        expect(
          seats.every((entry) => entry.value['status'] == 'available'),
          isTrue,
        );
      },
    );

    test(
      'membership rejection and verification failure do not write',
      () async {
        for (final (result, expectedError) in [
          (
            MembershipCheckResult.nonMember,
            RoomRepositoryError.membershipRequired,
          ),
          (
            MembershipCheckResult.permissionDenied,
            RoomRepositoryError.permissionDenied,
          ),
          (MembershipCheckResult.unavailable, RoomRepositoryError.unavailable),
        ]) {
          membership.result = result;
          await expectLater(
            repository.createRoom(subgroupId: 'subgroup-a', title: 'Room'),
            throwsA(
              isA<RoomRepositoryException>().having(
                (error) => error.code,
                'code',
                expectedError,
              ),
            ),
          );
        }

        expect(
          store.documents.keys.where((path) => path.contains('/rooms/')),
          isEmpty,
        );
      },
    );

    test(
      'lists summaries, looks up stable IDs and returns null when missing',
      () async {
        final created = await repository.createRoom(
          subgroupId: 'subgroup-a',
          title: 'Room',
        );
        final summaries = await repository.listRooms('subgroup-a');

        expect(summaries.single.id, created.roomId);
        expect(summaries.single.occupiedSeats, 0);
        final lookedUp = await repository.getRoom(created.roomId);
        expect(lookedUp?.id, summaries.single.id);
        expect(lookedUp?.occupiedSeats, summaries.single.occupiedSeats);
        expect(await repository.getRoomSnapshot('missing-room'), isNull);
      },
    );

    test('observes rooms, a room and exactly six seat states', () async {
      final room = await repository.createRoom(
        subgroupId: 'subgroup-a',
        title: 'Room',
      );

      expect(
        (await repository.watchRooms('subgroup-a').first).single.roomId,
        room.roomId,
      );
      expect(
        (await repository.watchRoom(room.roomId).first)?.roomId,
        room.roomId,
      );
      expect(await repository.watchSeats(room.roomId).first, hasLength(6));
    });

    test('does not write a seat claim without the trusted callable', () async {
      final room = await repository.createRoom(
        subgroupId: 'subgroup-a',
        title: 'Room',
      );
      final before = Map<String, Map<String, dynamic>>.of(store.documents);

      final result = await repository.claimSeat(
        subgroupId: 'subgroup-a',
        roomId: room.roomId,
        seatId: 'seat-1',
      );

      expect(result, isA<SeatClaimFailed>());
      expect((result as SeatClaimFailed).failure, SeatClaimFailure.unavailable);
      expect(store.documents, before);
    });
  });
}

final class _FakeMembershipRepository implements MembershipRepository {
  MembershipCheckResult result = MembershipCheckResult.member;
  Transaction? transaction;

  @override
  Future<MembershipCheckResult> verifyRoomEligibilityInTransaction({
    required Transaction transaction,
    required String sigId,
    required String subgroupId,
  }) async {
    this.transaction = transaction;
    expect(sigId, 'sig-a');
    expect(subgroupId, 'subgroup-a');
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeRoomDocumentStore implements RoomDocumentStore {
  final Map<String, Map<String, dynamic>> documents = {};
  final Map<String, StreamController<void>> _collectionChanges = {};
  final StreamController<void> _roomChanges = StreamController<void>.broadcast(
    sync: true,
  );
  int _nextRoomId = 1;
  Transaction? lastTransaction;

  @override
  String newRoomId(String roomsPath) => 'room-${_nextRoomId++}';

  @override
  Future<Map<String, dynamic>?> getDocument(String path) async =>
      documents[path];

  @override
  Future<Map<String, dynamic>?> getRoomById(String roomId) async =>
      documents.values.where((value) => value['roomId'] == roomId).firstOrNull;

  @override
  Future<List<Map<String, dynamic>>> listCollection(String path) async =>
      _documentsIn(path);

  @override
  Stream<Map<String, dynamic>?> watchRoomById(String roomId) =>
      Stream.multi((sink) {
        final subscription = _roomChanges.stream.listen(
          (_) => sink.add(_room(roomId)),
        );
        sink.add(_room(roomId));
        sink.onCancel = subscription.cancel;
      });

  @override
  Stream<List<Map<String, dynamic>>> watchCollection(String path) =>
      Stream.multi((sink) {
        final changes = _collectionChanges.putIfAbsent(
          path,
          () => StreamController<void>.broadcast(sync: true),
        );
        final subscription = changes.stream.listen(
          (_) => sink.add(_documentsIn(path)),
        );
        sink.add(_documentsIn(path));
        sink.onCancel = subscription.cancel;
      });

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(
      RoomWriteTransaction transaction,
      Transaction firestoreTransaction,
    )
    action,
  ) async {
    final firestoreTransaction = _FakeFirestoreTransaction();
    lastTransaction = firestoreTransaction;
    final staged = <String, Map<String, dynamic>>{};
    final result = await action(
      _FakeRoomWriteTransaction(staged),
      firestoreTransaction,
    );
    documents.addAll(staged);
    for (final path in staged.keys) {
      final separator = path.lastIndexOf('/');
      _collectionChanges[path.substring(0, separator)]?.add(null);
    }
    _roomChanges.add(null);
    return result;
  }

  List<Map<String, dynamic>> _documentsIn(String collectionPath) => documents
      .entries
      .where((entry) {
        final parent = entry.key.substring(0, entry.key.lastIndexOf('/'));
        return parent == collectionPath;
      })
      .map((entry) => entry.value)
      .toList(growable: false);

  Map<String, dynamic>? _room(String roomId) =>
      documents.values.where((value) => value['roomId'] == roomId).firstOrNull;
}

final class _FakeRoomWriteTransaction implements RoomWriteTransaction {
  _FakeRoomWriteTransaction(this.staged);
  final Map<String, Map<String, dynamic>> staged;

  @override
  void set(String path, Map<String, dynamic> data) => staged[path] = data;
}

final class _FakeFirestoreTransaction implements Transaction {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
