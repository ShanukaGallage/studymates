import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/core/models/active_room_session.dart';
import 'package:studymates/core/models/room_models.dart';

void main() {
  final nowUtc = DateTime.utc(2026, 11, 16, 8);
  final startsAt = nowUtc.add(const Duration(minutes: 5));

  ActiveRoomSession makeSession({
    DateTime? start,
    DateTime? focusEnd,
    DateTime? breakEnd,
    String userId = 'user-a',
    String sessionId = 'session-a',
    String goalText = 'Review notes',
    SeatState? seat,
    bool verified = true,
  }) => ActiveRoomSession(
    sessionId: sessionId,
    roomId: 'room-a',
    subgroupId: 'subgroup-a',
    roomTitle: 'Study room',
    seatId: 'seat-1',
    userId: userId,
    goalText: goalText,
    isDemo: false,
    startsAt: start ?? startsAt,
    focusEndsAt: focusEnd ?? startsAt.add(const Duration(minutes: 25)),
    breakEndsAt: breakEnd ?? startsAt.add(const Duration(minutes: 30)),
    participationSeat:
        seat ??
        SeatState(
          seatId: 'seat-1',
          status: SeatStatus.occupied,
          userId: userId,
          claimedAt: nowUtc,
          leaseExpiresAt: nowUtc.add(const Duration(minutes: 2)),
        ),
    seatLeaseVerified: verified,
    nowUtc: nowUtc,
  );

  test('validates required strings', () {
    expect(() => makeSession(sessionId: '  '), throwsArgumentError);
    expect(() => makeSession(goalText: ''), throwsArgumentError);
  });

  test('normalizes all schedule timestamps to UTC', () {
    final localStart = DateTime(2026, 11, 16, 13, 5);
    final session = makeSession(
      start: localStart,
      focusEnd: localStart.add(const Duration(minutes: 25)),
      breakEnd: localStart.add(const Duration(minutes: 30)),
    );

    expect(session.startsAt, localStart.toUtc());
    expect(session.startsAt.isUtc, isTrue);
    expect(session.focusEndsAt.isUtc, isTrue);
    expect(session.breakEndsAt.isUtc, isTrue);
  });

  test('rejects invalid timestamp order', () {
    expect(
      () => makeSession(
        focusEnd: startsAt,
        breakEnd: startsAt.add(const Duration(minutes: 30)),
      ),
      throwsArgumentError,
    );
    expect(
      () => makeSession(
        focusEnd: startsAt.add(const Duration(minutes: 25)),
        breakEnd: startsAt.add(const Duration(minutes: 25)),
      ),
      throwsArgumentError,
    );
  });

  test(
    'only confirmed unexpired matching seat lease is valid participation',
    () {
      expect(makeSession().participationStatus, ParticipationStatus.valid);
      expect(
        makeSession(verified: false).participationStatus,
        ParticipationStatus.requiresRevalidation,
      );
      expect(
        makeSession(
          seat: SeatState(
            seatId: 'seat-1',
            status: SeatStatus.occupied,
            userId: 'user-a',
            claimedAt: nowUtc.subtract(const Duration(minutes: 2)),
            leaseExpiresAt: nowUtc,
          ),
        ).participationStatus,
        ParticipationStatus.requiresRevalidation,
      );
      expect(
        makeSession(
          seat: SeatState(seatId: 'seat-1', status: SeatStatus.available),
        ).participationStatus,
        ParticipationStatus.requiresRevalidation,
      );
    },
  );
}
