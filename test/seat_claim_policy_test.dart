import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/core/models/room_models.dart';
import 'package:studymates/features/rooms/data/seat_claim_policy.dart';
import 'package:studymates/features/rooms/data/seat_claim_result.dart';

final _now = DateTime.utc(2026, 11, 16, 10);

List<SeatState> _seats({
  int occupied = 0,
  DateTime? expiry,
  String occupantPrefix = 'other',
}) => [
  for (var number = 1; number <= 6; number++)
    if (number <= occupied)
      SeatState(
        seatId: 'seat-$number',
        status: SeatStatus.occupied,
        userId: '$occupantPrefix-$number',
        claimedAt: _now.subtract(const Duration(minutes: 1)),
        leaseExpiresAt: expiry ?? _now.add(const Duration(minutes: 1)),
        lastRenewedAt: _now.subtract(const Duration(minutes: 1)),
      )
    else
      SeatState(seatId: 'seat-$number', status: SeatStatus.available),
];

SeatClaimPolicyDecision _evaluate({
  RoomStatus status = RoomStatus.waiting,
  List<SeatState>? seats,
  String seatId = 'seat-1',
  String userId = 'user-a',
  DateTime? nowUtc,
  Map<String, ActiveSeatClaimSnapshot> activeClaims = const {},
}) => SeatClaimPolicy.evaluate(
  roomStatus: status,
  subgroupId: 'subgroup-a',
  roomId: 'room-a',
  seats: seats ?? _seats(),
  requestedSeatId: seatId,
  userId: userId,
  nowUtc: nowUtc ?? _now,
  activeClaimsByUser: activeClaims,
);

void main() {
  group('SeatClaimPolicy', () {
    test('claims an available fixed seat with a two-minute UTC lease', () {
      final decision = _evaluate();
      final result = decision.result as SeatClaimSucceeded;

      expect(fixedRoomSeatIds, [
        'seat-1',
        'seat-2',
        'seat-3',
        'seat-4',
        'seat-5',
        'seat-6',
      ]);
      expect(result.wasAlreadyClaimed, isFalse);
      expect(result.seat.status, SeatStatus.occupied);
      expect(result.seat.userId, 'user-a');
      expect(result.seat.claimedAt, _now);
      expect(result.seat.leaseExpiresAt, _now.add(const Duration(minutes: 2)));
      expect(result.seat.lastRenewedAt, result.seat.claimedAt);
      expect(result.seat.leaseExpiresAt!.isUtc, isTrue);
    });

    test('same user repeating a live same-seat claim is idempotent', () {
      final existing = SeatState(
        seatId: 'seat-1',
        status: SeatStatus.occupied,
        userId: 'user-a',
        claimedAt: _now.subtract(const Duration(minutes: 1)),
        leaseExpiresAt: _now.add(const Duration(minutes: 1)),
        lastRenewedAt: _now.subtract(const Duration(minutes: 1)),
      );
      final seats = [existing, ..._seats().skip(1)];
      final result =
          _evaluate(
                seats: seats,
                activeClaims: {
                  'user-a': ActiveSeatClaimSnapshot.valid(
                    reference: const ActiveSeatClaimReference(
                      subgroupId: 'subgroup-a',
                      roomId: 'room-a',
                      seatId: 'seat-1',
                    ),
                    referencedSeat: existing,
                  ),
                },
              ).result
              as SeatClaimSucceeded;

      expect(result.wasAlreadyClaimed, isTrue);
      expect(result.seat, same(existing));
      expect(result.seat.leaseExpiresAt, _now.add(const Duration(minutes: 1)));
      expect(result.seat.lastRenewedAt, existing.lastRenewedAt);
    });

    test('live requested seat held by another user returns seatTaken', () {
      final occupied = _seats(occupied: 1).first;
      final result = _evaluate(
        seats: _seats(occupied: 1),
        activeClaims: {
          'other-1': ActiveSeatClaimSnapshot.valid(
            reference: const ActiveSeatClaimReference(
              subgroupId: 'subgroup-a',
              roomId: 'room-a',
              seatId: 'seat-1',
            ),
            referencedSeat: occupied,
          ),
        },
      ).result;

      expect((result as SeatClaimFailed).failure, SeatClaimFailure.seatTaken);
    });

    test('occupied seat without its owner active claim is unavailable', () {
      final result = _evaluate(seats: _seats(occupied: 1)).result;

      expect((result as SeatClaimFailed).failure, SeatClaimFailure.unavailable);
    });

    test('all six valid live leases return fullRoom', () {
      final seats = _seats(occupied: 6);
      final result = _evaluate(
        seats: seats,
        activeClaims: {
          for (var number = 1; number <= 6; number++)
            'other-$number': ActiveSeatClaimSnapshot.valid(
              reference: ActiveSeatClaimReference(
                subgroupId: 'subgroup-a',
                roomId: 'room-a',
                seatId: 'seat-$number',
              ),
              referencedSeat: seats[number - 1],
            ),
        },
      ).result;

      expect((result as SeatClaimFailed).failure, SeatClaimFailure.fullRoom);
    });

    test('valid live active claim for another seat returns alreadySeated', () {
      final existing = SeatState(
        seatId: 'seat-2',
        status: SeatStatus.occupied,
        userId: 'user-a',
        claimedAt: _now.subtract(const Duration(minutes: 1)),
        leaseExpiresAt: _now.add(const Duration(minutes: 1)),
      );
      final result = _evaluate(
        activeClaims: {
          'user-a': ActiveSeatClaimSnapshot.valid(
            reference: const ActiveSeatClaimReference(
              subgroupId: 'subgroup-a',
              roomId: 'room-b',
              seatId: 'seat-2',
            ),
            referencedSeat: existing,
          ),
        },
      ).result;

      expect(
        (result as SeatClaimFailed).failure,
        SeatClaimFailure.alreadySeated,
      );
    });

    test('lease expiry at nowUtc is expired and can be safely reclaimed', () {
      final expired = SeatState(
        seatId: 'seat-1',
        status: SeatStatus.occupied,
        userId: 'old-user',
        claimedAt: _now.subtract(const Duration(minutes: 2)),
        leaseExpiresAt: _now,
      );
      final result = _evaluate(
        seats: [expired, ..._seats().skip(1)],
        activeClaims: {
          'old-user': ActiveSeatClaimSnapshot.valid(
            reference: const ActiveSeatClaimReference(
              subgroupId: 'subgroup-a',
              roomId: 'room-a',
              seatId: 'seat-1',
            ),
            referencedSeat: expired,
          ),
        },
      );

      expect(result.result, isA<SeatClaimSucceeded>());
      expect(result.staleClaimsToClean.single.userId, 'old-user');
    });

    test(
      'does not delete an active claim that points to a different live seat',
      () {
        final expiredTarget = SeatState(
          seatId: 'seat-1',
          status: SeatStatus.occupied,
          userId: 'old-user',
          claimedAt: _now.subtract(const Duration(minutes: 2)),
          leaseExpiresAt: _now,
        );
        final liveReferenced = SeatState(
          seatId: 'seat-3',
          status: SeatStatus.occupied,
          userId: 'old-user',
          claimedAt: _now.subtract(const Duration(minutes: 1)),
          leaseExpiresAt: _now.add(const Duration(minutes: 1)),
        );
        final result = _evaluate(
          seats: [expiredTarget, ..._seats().skip(1)],
          activeClaims: {
            'old-user': ActiveSeatClaimSnapshot.valid(
              reference: const ActiveSeatClaimReference(
                subgroupId: 'subgroup-a',
                roomId: 'room-b',
                seatId: 'seat-3',
              ),
              referencedSeat: liveReferenced,
            ),
          },
        );

        expect(
          (result.result as SeatClaimFailed).failure,
          SeatClaimFailure.unavailable,
        );
        expect(result.staleClaimsToClean, isEmpty);
      },
    );

    test('malformed active-claim record fails without cleanup', () {
      final result = _evaluate(
        activeClaims: {'user-a': const ActiveSeatClaimSnapshot.malformed()},
      );

      expect(
        (result.result as SeatClaimFailed).failure,
        SeatClaimFailure.unavailable,
      );
      expect(result.staleClaimsToClean, isEmpty);
    });

    test('occupied seat without lease expiry is not treated as stale', () {
      final malformed = SeatState(
        seatId: 'seat-1',
        status: SeatStatus.occupied,
        userId: 'old-user',
        claimedAt: _now.subtract(const Duration(minutes: 5)),
      );
      final result = _evaluate(seats: [malformed, ..._seats().skip(1)]).result;

      expect((result as SeatClaimFailed).failure, SeatClaimFailure.unavailable);
    });

    for (final status in [RoomStatus.completed, RoomStatus.closed]) {
      test('$status room rejects a new claim', () {
        final result = _evaluate(status: status).result;

        expect(
          (result as SeatClaimFailed).failure,
          SeatClaimFailure.roomUnavailable,
        );
      });
    }

    test('unknown seat ID returns seatNotFound', () {
      final result = _evaluate(seatId: 'seat-7').result;

      expect(
        (result as SeatClaimFailed).failure,
        SeatClaimFailure.seatNotFound,
      );
    });
  });
}