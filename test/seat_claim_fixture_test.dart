import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/core/models/room_models.dart';
import 'package:studymates/features/rooms/data/seat_claim_result.dart';
import 'package:studymates/preview/live_room_repository_fixture.dart';

void main() {
  group('FixtureLiveRoomRepository.claimSeat', () {
    late DateTime nowUtc;
    late String currentUid;
    late FixtureMembershipCheckResult membership;
    late FixtureLiveRoomRepository repository;
    late bool corruptTargetBeforeApply;

    setUp(() {
      nowUtc = DateTime.utc(2026, 11, 16, 10);
      currentUid = 'user-a';
      membership = FixtureMembershipCheckResult.member;
      corruptTargetBeforeApply = false;
      repository = FixtureLiveRoomRepository(
        subgroupSigIds: const {'subgroup-a': 'sig-a'},
        currentUserId: () => currentUid,
        clock: () => nowUtc,
        beforeClaimApplyForTest: () {
          if (corruptTargetBeforeApply) {
            repository.corruptActiveSeatClaimForTest('old-user');
          }
        },
        verifyMembership: ({required sigId, required subgroupId}) async =>
            sigId == 'sig-a' && subgroupId == 'subgroup-a'
            ? membership
            : FixtureMembershipCheckResult.nonMember,
      );
    });

    tearDown(() async => repository.dispose());

    Future<String> createRoom({RoomStatus status = RoomStatus.waiting}) async {
      if (status == RoomStatus.waiting) {
        return (await repository.createRoom(
          subgroupId: 'subgroup-a',
          title: 'Seat test room',
        )).roomId;
      }
      final roomId = 'fixture-${status.name}';
      repository.seedRoomForTest(
        RoomSnapshot(
          roomId: roomId,
          subgroupId: 'subgroup-a',
          title: 'Seat test room',
          createdBy: 'host',
          hostUid: 'host',
          status: status,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        [
          for (final seatId in const [
            'seat-1',
            'seat-2',
            'seat-3',
            'seat-4',
            'seat-5',
            'seat-6',
          ])
            SeatState(seatId: seatId, status: SeatStatus.available),
        ],
      );
      return roomId;
    }

    Future<SeatClaimResult> claim(
      String roomId,
      String seatId, {
      String subgroupId = 'subgroup-a',
    }) => repository.claimSeat(
      subgroupId: subgroupId,
      roomId: roomId,
      seatId: seatId,
    );

    test('claims a free seat with exact two-minute UTC expiry', () async {
      final roomId = await createRoom();

      final result = await claim(roomId, 'seat-1') as SeatClaimSucceeded;
      final seat = (await repository.watchSeats(roomId).first).first;

      expect(result.wasAlreadyClaimed, isFalse);
      expect(result.seat.userId, 'user-a');
      expect(seat.claimedAt, nowUtc);
      expect(seat.leaseExpiresAt, nowUtc.add(const Duration(minutes: 2)));
      expect(seat.lastRenewedAt, seat.claimedAt);
      expect(seat.leaseExpiresAt!.isUtc, isTrue);
    });

    test(
      'same-user same-seat retry succeeds without extending lease',
      () async {
        final roomId = await createRoom();
        final first = await claim(roomId, 'seat-1') as SeatClaimSucceeded;
        nowUtc = nowUtc.add(const Duration(seconds: 30));

        final retry = await claim(roomId, 'seat-1') as SeatClaimSucceeded;

        expect(retry.wasAlreadyClaimed, isTrue);
        expect(retry.seat.claimedAt, first.seat.claimedAt);
        expect(retry.seat.leaseExpiresAt, first.seat.leaseExpiresAt);
        expect(retry.seat.lastRenewedAt, first.seat.lastRenewedAt);
      },
    );

    test(
      'another user targeting a live occupied seat gets seatTaken',
      () async {
        final roomId = await createRoom();
        await claim(roomId, 'seat-1');
        currentUid = 'user-b';

        final result = await claim(roomId, 'seat-1') as SeatClaimFailed;

        expect(result.failure, SeatClaimFailure.seatTaken);
        expect(repository.activeSeatClaimForTest('user-a')?.seatId, 'seat-1');
        expect(repository.activeSeatClaimForTest('user-b'), isNull);
      },
    );

    test('all six live occupied seats produce fullRoom', () async {
      final roomId = await createRoom();
      for (var number = 1; number <= 6; number++) {
        currentUid = 'user-$number';
        final result = await claim(roomId, 'seat-$number');
        expect(result, isA<SeatClaimSucceeded>());
      }
      currentUid = 'user-seven';

      final result = await claim(roomId, 'seat-1') as SeatClaimFailed;

      expect(result.failure, SeatClaimFailure.fullRoom);
      expect(await repository.watchSeats(roomId).first, hasLength(6));
    });

    test(
      'user with another live seat gets alreadySeated and claim is preserved',
      () async {
        final firstRoom = await createRoom();
        final secondRoom = await createRoom();
        await claim(firstRoom, 'seat-1');
        final savedClaim = repository.activeSeatClaimForTest('user-a');

        final result = await claim(secondRoom, 'seat-2') as SeatClaimFailed;

        expect(result.failure, SeatClaimFailure.alreadySeated);
        expect(repository.activeSeatClaimForTest('user-a'), same(savedClaim));
        expect(
          (await repository.watchSeats(firstRoom).first).first.userId,
          'user-a',
        );
        expect(
          (await repository.watchSeats(secondRoom).first)[1].status,
          SeatStatus.available,
        );
      },
    );

    test(
      'non-member and permission/service failures do not write a claim',
      () async {
        final roomId = await createRoom();
        for (final (membershipResult, expectedFailure) in [
          (
            FixtureMembershipCheckResult.nonMember,
            SeatClaimFailure.membershipRequired,
          ),
          (
            FixtureMembershipCheckResult.permissionDenied,
            SeatClaimFailure.permissionDenied,
          ),
          (
            FixtureMembershipCheckResult.unavailable,
            SeatClaimFailure.unavailable,
          ),
        ]) {
          membership = membershipResult;
          final result = await claim(roomId, 'seat-1') as SeatClaimFailed;
          expect(result.failure, expectedFailure);
          expect(repository.activeSeatClaimForTest('user-a'), isNull);
          expect(
            (await repository.watchSeats(roomId).first).first.status,
            SeatStatus.available,
          );
        }
      },
    );

    test('lease expiring exactly now can be reassigned safely', () async {
      final roomId = await createRoom();
      await claim(roomId, 'seat-1');
      final expiry = nowUtc.add(const Duration(minutes: 2));
      nowUtc = expiry;
      currentUid = 'user-b';

      final result = await claim(roomId, 'seat-1') as SeatClaimSucceeded;

      expect(result.wasAlreadyClaimed, isFalse);
      expect(result.seat.userId, 'user-b');
      expect(result.seat.claimedAt, expiry);
      expect(
        result.seat.leaseExpiresAt,
        expiry.add(const Duration(minutes: 2)),
      );
      expect(repository.activeSeatClaimForTest('user-a'), isNull);
      expect(repository.activeSeatClaimForTest('user-b')?.seatId, 'seat-1');
    });

    test(
      'preserves another user’s valid active claim when target is occupied',
      () async {
        final roomId = await createRoom();
        await claim(roomId, 'seat-2');
        final savedClaim = repository.activeSeatClaimForTest('user-a');
        currentUid = 'user-b';

        final result = await claim(roomId, 'seat-2') as SeatClaimFailed;

        expect(result.failure, SeatClaimFailure.seatTaken);
        expect(repository.activeSeatClaimForTest('user-a'), same(savedClaim));
        expect(repository.activeSeatClaimForTest('user-b'), isNull);
      },
    );

    for (final status in [RoomStatus.completed, RoomStatus.closed]) {
      test('$status room returns roomUnavailable', () async {
        final roomId = await createRoom(status: status);

        final result = await claim(roomId, 'seat-1') as SeatClaimFailed;

        expect(result.failure, SeatClaimFailure.roomUnavailable);
        expect(repository.activeSeatClaimForTest('user-a'), isNull);
      });
    }

    test('unknown seat ID returns seatNotFound', () async {
      final roomId = await createRoom();

      final result = await claim(roomId, 'seat-7') as SeatClaimFailed;

      expect(result.failure, SeatClaimFailure.seatNotFound);
      expect(repository.activeSeatClaimForTest('user-a'), isNull);
    });

    test(
      'fixture rejects malformed or inconsistent existing active claims safely',
      () async {
        final roomId = await createRoom();
        await claim(roomId, 'seat-1');
        repository.corruptActiveSeatClaimForTest('user-a');
        currentUid = 'user-a';

        final result = await claim(roomId, 'seat-2') as SeatClaimFailed;

        expect(result.failure, SeatClaimFailure.unavailable);
        expect(repository.activeSeatClaimForTest('user-a'), isNotNull);
        expect(
          (await repository.watchSeats(roomId).first)[1].status,
          SeatStatus.available,
        );
      },
    );

    test('failed cleanup validation leaves every seat and claim unchanged', () async {
      final callerRoom = await createRoom();
      final targetRoom = await createRoom();
      await claim(callerRoom, 'seat-1');
      currentUid = 'old-user';
      await claim(targetRoom, 'seat-1');
      final callerClaim = repository.activeSeatClaimForTest('user-a');
      final oldUserClaim = repository.activeSeatClaimForTest('old-user');

      nowUtc = nowUtc.add(const Duration(minutes: 2));
      currentUid = 'user-a';
      corruptTargetBeforeApply = true;

      final result = await claim(targetRoom, 'seat-1') as SeatClaimFailed;

      expect(result.failure, SeatClaimFailure.unavailable);
      expect(repository.activeSeatClaimForTest('user-a'), same(callerClaim));
      expect(repository.activeSeatClaimForTest('old-user'), same(oldUserClaim));
      expect(
        (await repository.watchSeats(callerRoom).first).first.userId,
        'user-a',
      );
      expect(
        (await repository.watchSeats(targetRoom).first).first.userId,
        'old-user',
      );
    });
  });
}
