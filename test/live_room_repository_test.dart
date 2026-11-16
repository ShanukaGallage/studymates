import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/core/models/community_models.dart';
import 'package:studymates/core/models/room_models.dart';
import 'package:studymates/features/rooms/data/room_repository.dart';
import 'package:studymates/preview/live_room_repository_fixture.dart';

const _subgroupToSig = {'subgroup-a': 'sig-a', 'subgroup-b': 'sig-b'};

FixtureLiveRoomRepository _repository({
  FixtureMembershipCheckResult membership = FixtureMembershipCheckResult.member,
  String userId = 'user-1',
  DateTime Function()? clock,
  Iterable<({RoomSnapshot room, Iterable<SeatState> seats})> initialRooms =
      const [],
}) => FixtureLiveRoomRepository(
  subgroupSigIds: _subgroupToSig,
  verifyMembership: ({required sigId, required subgroupId}) async =>
      _subgroupToSig[subgroupId] == sigId
      ? membership
      : FixtureMembershipCheckResult.nonMember,
  currentUserId: () => userId,
  clock: clock,
  initialRooms: initialRooms,
);

List<SeatState> _seats({required int occupied}) => [
  for (var number = 1; number <= 6; number++)
    if (number <= occupied)
      SeatState(
        seatId: 'seat-$number',
        status: SeatStatus.occupied,
        userId: 'occupant-$number',
        claimedAt: DateTime.utc(2026, 1, 1),
      )
    else
      SeatState(seatId: 'seat-$number', status: SeatStatus.available),
];

({RoomSnapshot room, Iterable<SeatState> seats}) _roomFixture({
  required String id,
  required String subgroupId,
  required int occupied,
}) => (
  room: RoomSnapshot(
    roomId: id,
    subgroupId: subgroupId,
    title: 'Room $id',
    createdBy: 'owner-$id',
    hostUid: 'owner-$id',
    status: RoomStatus.waiting,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  ),
  seats: _seats(occupied: occupied),
);

void main() {
  group('FixtureLiveRoomRepository', () {
    test(
      'creates a stable room with six available seats and UTC timestamps',
      () async {
        final localTime = DateTime(2026, 11, 16, 12);
        final repository = _repository(clock: () => localTime);
        addTearDown(repository.dispose);

        final room = await repository.createRoom(
          subgroupId: 'subgroup-a',
          title: '  Study together  ',
        );
        final seats = await repository.watchSeats(room.roomId).first;

        expect(room.roomId, 'room-000001');
        expect(room.subgroupId, 'subgroup-a');
        expect(room.title, 'Study together');
        expect(room.createdBy, 'user-1');
        expect(room.hostUid, 'user-1');
        expect(room.status, RoomStatus.waiting);
        expect(room.createdAt, localTime.toUtc());
        expect(room.updatedAt, localTime.toUtc());
        expect(room.createdAt.isUtc, isTrue);
        expect(seats, hasLength(6));
        expect(
          seats.every((seat) => seat.status == SeatStatus.available),
          isTrue,
        );
        expect(seats.map((seat) => seat.seatId).toSet(), hasLength(6));
      },
    );

    test('lists rooms only for the requested subgroup and reuses discovery summaries', () async {
      final repository = _repository(
        initialRooms: [
          _roomFixture(id: 'room-a', subgroupId: 'subgroup-a', occupied: 3),
          _roomFixture(id: 'room-b', subgroupId: 'subgroup-b', occupied: 0),
          _roomFixture(id: 'room-full', subgroupId: 'subgroup-a', occupied: 6),
        ],
      );
      addTearDown(repository.dispose);

      final liveRooms = await repository.listRoomSnapshots('subgroup-a');
      final summaries = await repository.listRooms('subgroup-a');

      expect(liveRooms.map((room) => room.roomId), ['room-a', 'room-full']);
      expect(summaries.map((room) => room.id), ['room-a', 'room-full']);
      expect(summaries.map((room) => room.occupiedSeats), [3, 6]);
      expect(summaries.last.isFull, isTrue);
    });

    test(
      'gets live snapshots and existing discovery summaries by stable ID',
      () async {
        final repository = _repository(
          initialRooms: [
            _roomFixture(
              id: 'stable-room-id',
              subgroupId: 'subgroup-a',
              occupied: 1,
            ),
          ],
        );
        addTearDown(repository.dispose);

        expect(
          (await repository.getRoomSnapshot('stable-room-id'))?.roomId,
          'stable-room-id',
        );
        expect((await repository.getRoom('stable-room-id'))?.occupiedSeats, 1);
        expect(await repository.getRoomSnapshot('missing'), isNull);
        expect(await repository.getRoom('missing'), isNull);
      },
    );

    test(
      'room list observation emits its initial value and newly created rooms',
      () async {
        final repository = _repository();
        addTearDown(repository.dispose);
        final events = repository.watchRooms('subgroup-a').take(2);
        final expectation = expectLater(
          events,
          emitsInOrder([
            isEmpty,
            predicate<List<RoomSnapshot>>(
              (rooms) =>
                  rooms.length == 1 && rooms.single.roomId == 'room-000001',
            ),
          ]),
        );

        await repository.createRoom(
          subgroupId: 'subgroup-a',
          title: 'Observed',
        );
        await expectation;
      },
    );

    test(
      'room and seat observations emit room creation and exactly six seats',
      () async {
        final repository = _repository();
        addTearDown(repository.dispose);
        final roomEvents = repository.watchRoom('room-000001').take(2);
        final seatEvents = repository.watchSeats('room-000001').take(2);
        final roomExpectation = expectLater(
          roomEvents,
          emitsInOrder([
            isNull,
            predicate<RoomSnapshot?>((room) => room?.roomId == 'room-000001'),
          ]),
        );
        final seatExpectation = expectLater(
          seatEvents,
          emitsInOrder([
            isEmpty,
            predicate<List<SeatState>>(
              (seats) =>
                  seats.length == 6 &&
                  seats.every((seat) => seat.status == SeatStatus.available),
            ),
          ]),
        );

        await repository.createRoom(subgroupId: 'subgroup-a', title: 'Watched');
        await Future.wait([roomExpectation, seatExpectation]);
      },
    );

    test(
      'supports empty, partially occupied, and full room state fixtures',
      () async {
        final repository = _repository(
          initialRooms: [
            _roomFixture(id: 'empty', subgroupId: 'subgroup-a', occupied: 0),
            _roomFixture(id: 'partial', subgroupId: 'subgroup-a', occupied: 2),
            _roomFixture(id: 'full', subgroupId: 'subgroup-a', occupied: 6),
          ],
        );
        addTearDown(repository.dispose);

        final summaries = await repository.listRooms('subgroup-a');
        expect(summaries.map((room) => room.occupiedSeats), [0, 2, 6]);
        expect(summaries.map((room) => room.isFull), [false, false, true]);
        expect(await repository.watchSeats('partial').first, hasLength(6));
      },
    );

    test('rejects empty room data and unknown subgroup', () async {
      final repository = _repository();
      addTearDown(repository.dispose);

      await expectLater(
        repository.createRoom(subgroupId: 'subgroup-a', title: '  '),
        throwsA(
          isA<RoomRepositoryException>().having(
            (error) => error.code,
            'code',
            RoomRepositoryError.invalidData,
          ),
        ),
      );
      await expectLater(
        repository.createRoom(subgroupId: 'unknown', title: 'Room'),
        throwsA(
          isA<RepositoryException>().having(
            (error) => error.code,
            'code',
            RepositoryError.notFound,
          ),
        ),
      );
      expect(await repository.listRoomSnapshots('subgroup-a'), isEmpty);
    });

    test('rejects creation when fixture membership check fails', () async {
      final repository = _repository(
        membership: FixtureMembershipCheckResult.nonMember,
      );
      addTearDown(repository.dispose);

      await expectLater(
        repository.createRoom(subgroupId: 'subgroup-a', title: 'Denied'),
        throwsA(
          isA<RoomRepositoryException>().having(
            (error) => error.code,
            'code',
            RoomRepositoryError.membershipRequired,
          ),
        ),
      );
      expect(await repository.listRoomSnapshots('subgroup-a'), isEmpty);
    });

    test('rejects an empty authenticated identity', () async {
      final repository = _repository(userId: '  ');
      addTearDown(repository.dispose);

      await expectLater(
        repository.createRoom(subgroupId: 'subgroup-a', title: 'Denied'),
        throwsA(
          isA<RoomRepositoryException>().having(
            (error) => error.code,
            'code',
            RoomRepositoryError.permissionDenied,
          ),
        ),
      );
    });
  });
}
