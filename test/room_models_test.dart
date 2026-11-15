import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/core/models/room_models.dart';

void main() {
  group('RoomSnapshot', () {
    test(
      'stores room metadata without embedding seats and normalizes times',
      () {
        final localCreatedAt = DateTime(2026, 11, 15, 10);
        final localUpdatedAt = localCreatedAt.add(const Duration(minutes: 1));
        final room = RoomSnapshot(
          roomId: 'room-1',
          subgroupId: 'subgroup-1',
          title: 'Study room',
          createdBy: 'user-1',
          hostUid: 'user-1',
          status: RoomStatus.waiting,
          createdAt: localCreatedAt,
          updatedAt: localUpdatedAt,
        );

        expect(room.roomId, 'room-1');
        expect(room.subgroupId, 'subgroup-1');
        expect(room.title, 'Study room');
        expect(room.createdBy, 'user-1');
        expect(room.hostUid, 'user-1');
        expect(room.status, RoomStatus.waiting);
        expect(room.createdAt, localCreatedAt.toUtc());
        expect(room.updatedAt, localUpdatedAt.toUtc());
        expect(room.createdAt.isUtc, isTrue);
        expect(room.updatedAt.isUtc, isTrue);
      },
    );

    test('provides all agreed room statuses', () {
      expect(RoomStatus.values, [
        RoomStatus.waiting,
        RoomStatus.active,
        RoomStatus.completed,
        RoomStatus.closed,
      ]);
    });
  });

  group('SeatState', () {
    test('available seats have no occupant or lease timestamps', () {
      final seat = SeatState(seatId: 'seat-a', status: SeatStatus.available);

      expect(seat.userId, isNull);
      expect(seat.claimedAt, isNull);
      expect(seat.leaseExpiresAt, isNull);
      expect(seat.lastRenewedAt, isNull);
    });

    test('rejects available seats with any occupancy or lease field', () {
      final timestamp = DateTime.utc(2026, 11, 15);
      final invalidSeats = [
        () => SeatState(
          seatId: 'seat-a',
          status: SeatStatus.available,
          userId: 'user-1',
        ),
        () => SeatState(
          seatId: 'seat-a',
          status: SeatStatus.available,
          claimedAt: timestamp,
        ),
        () => SeatState(
          seatId: 'seat-a',
          status: SeatStatus.available,
          leaseExpiresAt: timestamp,
        ),
        () => SeatState(
          seatId: 'seat-a',
          status: SeatStatus.available,
          lastRenewedAt: timestamp,
        ),
      ];

      for (final createSeat in invalidSeats) {
        expect(createSeat, throwsArgumentError);
      }
    });

    test('occupied seats require a user ID and claimedAt', () {
      final invalidSeats = [
        () => SeatState(seatId: 'seat-a', status: SeatStatus.occupied),
        () => SeatState(
          seatId: 'seat-a',
          status: SeatStatus.occupied,
          claimedAt: DateTime.utc(2026, 11, 15),
        ),
        () => SeatState(
          seatId: 'seat-a',
          status: SeatStatus.occupied,
          userId: 'user-1',
        ),
      ];

      for (final createSeat in invalidSeats) {
        expect(createSeat, throwsArgumentError);
      }
    });

    test('occupied seats may have unset lease timestamps and normalize supplied times', () {
      final localClaimedAt = DateTime(2026, 11, 15, 10);
      final localLeaseExpiresAt = localClaimedAt.add(
        const Duration(minutes: 2),
      );
      final localLastRenewedAt = localClaimedAt.add(const Duration(minutes: 1));
      final seat = SeatState(
        seatId: 'seat-a',
        status: SeatStatus.occupied,
        userId: 'user-1',
        claimedAt: localClaimedAt,
        leaseExpiresAt: localLeaseExpiresAt,
        lastRenewedAt: localLastRenewedAt,
      );
      final seatWithoutLeaseTimes = SeatState(
        seatId: 'seat-b',
        status: SeatStatus.occupied,
        userId: 'user-2',
        claimedAt: localClaimedAt,
      );

      expect(seat.claimedAt, localClaimedAt.toUtc());
      expect(seat.leaseExpiresAt, localLeaseExpiresAt.toUtc());
      expect(seat.lastRenewedAt, localLastRenewedAt.toUtc());
      expect(seat.claimedAt!.isUtc, isTrue);
      expect(seat.leaseExpiresAt!.isUtc, isTrue);
      expect(seat.lastRenewedAt!.isUtc, isTrue);
      expect(seatWithoutLeaseTimes.leaseExpiresAt, isNull);
      expect(seatWithoutLeaseTimes.lastRenewedAt, isNull);
    });

    test('provides only the agreed seat statuses', () {
      expect(SeatStatus.values, [SeatStatus.available, SeatStatus.occupied]);
    });
  });

  group('validateSeatCollection', () {
    test(
      'accepts six valid seats with distinct IDs and returns an immutable list',
      () {
        final seats = [
          for (var index = 0; index < 6; index++)
            SeatState(seatId: 'seat-$index', status: SeatStatus.available),
        ];

        final validatedSeats = validateSeatCollection(seats);

        expect(validatedSeats, hasLength(6));
        expect(validatedSeats.map((seat) => seat.seatId).toSet(), hasLength(6));
        expect(() => validatedSeats.add(seats.first), throwsUnsupportedError);
      },
    );

    test('rejects collections with fewer or more than six seats', () {
      final sixSeats = [
        for (var index = 0; index < 6; index++)
          SeatState(seatId: 'seat-$index', status: SeatStatus.available),
      ];

      expect(
        () => validateSeatCollection(sixSeats.take(5)),
        throwsArgumentError,
      );
      expect(
        () => validateSeatCollection([...sixSeats, sixSeats.first]),
        throwsArgumentError,
      );
    });

    test('rejects duplicate seat IDs', () {
      final seats = [
        for (var index = 0; index < 6; index++)
          SeatState(
            seatId: index == 5 ? 'seat-0' : 'seat-$index',
            status: SeatStatus.available,
          ),
      ];

      expect(() => validateSeatCollection(seats), throwsArgumentError);
    });
  });
}
