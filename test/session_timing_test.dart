import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/features/sessions/data/session_timing.dart';

void main() {
  final startsAt = DateTime.utc(2026, 1, 1, 12);
  final focusEndsAt = startsAt.add(const Duration(minutes: 25));
  final breakEndsAt = focusEndsAt.add(const Duration(minutes: 5));

  SessionTiming timingAt(DateTime nowUtc) {
    final result = calculateSessionTiming(
      nowUtc: nowUtc,
      startsAt: startsAt,
      focusEndsAt: focusEndsAt,
      breakEndsAt: breakEndsAt,
    );
    expect(result, isA<SessionTiming>());
    return result as SessionTiming;
  }

  test('is waiting before the session starts', () {
    final timing = timingAt(startsAt.subtract(const Duration(seconds: 1)));

    expect(timing.phase, SessionPhase.waiting);
    expect(timing.remainingSeconds, 1);
  });

  test('starts the focus phase exactly at startsAt', () {
    final timing = timingAt(startsAt);

    expect(timing.phase, SessionPhase.focus);
    expect(timing.remainingSeconds, const Duration(minutes: 25).inSeconds);
  });

  test('counts down during focus', () {
    final timing = timingAt(startsAt.add(const Duration(minutes: 5)));

    expect(timing.phase, SessionPhase.focus);
    expect(timing.remainingSeconds, const Duration(minutes: 20).inSeconds);
  });

  test('remains in focus just before focusEndsAt', () {
    final timing = timingAt(focusEndsAt.subtract(const Duration(seconds: 1)));

    expect(timing.phase, SessionPhase.focus);
    expect(timing.remainingSeconds, 1);
  });

  test('starts the break phase exactly at focusEndsAt', () {
    final timing = timingAt(focusEndsAt);

    expect(timing.phase, SessionPhase.breakTime);
    expect(timing.remainingSeconds, const Duration(minutes: 5).inSeconds);
  });

  test('counts down during the break', () {
    final timing = timingAt(focusEndsAt.add(const Duration(minutes: 2)));

    expect(timing.phase, SessionPhase.breakTime);
    expect(timing.remainingSeconds, const Duration(minutes: 3).inSeconds);
  });

  test('completes exactly at breakEndsAt', () {
    final timing = timingAt(breakEndsAt);

    expect(timing.phase, SessionPhase.completed);
    expect(timing.remainingSeconds, 0);
  });

  test('stays completed after breakEndsAt', () {
    final timing = timingAt(breakEndsAt.add(const Duration(minutes: 1)));

    expect(timing.phase, SessionPhase.completed);
    expect(timing.remainingSeconds, 0);
  });

  test('rounds positive fractional seconds up', () {
    final timing = timingAt(
      focusEndsAt.subtract(const Duration(microseconds: 1)),
    );

    expect(timing.phase, SessionPhase.focus);
    expect(timing.remainingSeconds, 1);
  });

  test('returns an invalid result when any timestamp is missing', () {
    final schedules = [
      (null, focusEndsAt, breakEndsAt),
      (startsAt, null, breakEndsAt),
      (startsAt, focusEndsAt, null),
    ];

    for (final (start, focusEnd, breakEnd) in schedules) {
      final result = calculateSessionTiming(
        nowUtc: startsAt,
        startsAt: start,
        focusEndsAt: focusEnd,
        breakEndsAt: breakEnd,
      );

      expect(result, isA<InvalidSessionTiming>());
      expect(
        (result as InvalidSessionTiming).error,
        SessionTimingError.missingTimestamp,
      );
    }
  });

  test('returns an invalid result for equal or incorrectly ordered times', () {
    final schedules = [
      (startsAt, startsAt, breakEndsAt),
      (startsAt, focusEndsAt, focusEndsAt),
      (focusEndsAt, startsAt, breakEndsAt),
      (startsAt, breakEndsAt, focusEndsAt),
    ];

    for (final (start, focusEnd, breakEnd) in schedules) {
      final result = calculateSessionTiming(
        nowUtc: startsAt,
        startsAt: start,
        focusEndsAt: focusEnd,
        breakEndsAt: breakEnd,
      );

      expect(result, isA<InvalidSessionTiming>());
      expect(
        (result as InvalidSessionTiming).error,
        SessionTimingError.invalidTimestampOrder,
      );
    }
  });

  test('treats equivalent instants in local and UTC time as equal', () {
    final localStartsAt = DateTime.fromMillisecondsSinceEpoch(
      startsAt.millisecondsSinceEpoch,
    );
    final localFocusEndsAt = DateTime.fromMillisecondsSinceEpoch(
      focusEndsAt.millisecondsSinceEpoch,
    );
    final localBreakEndsAt = DateTime.fromMillisecondsSinceEpoch(
      breakEndsAt.millisecondsSinceEpoch,
    );
    final localNow = DateTime.fromMillisecondsSinceEpoch(
      startsAt.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
    );

    final utcTiming = timingAt(startsAt.add(const Duration(minutes: 5)));
    final localResult = calculateSessionTiming(
      nowUtc: localNow,
      startsAt: localStartsAt,
      focusEndsAt: localFocusEndsAt,
      breakEndsAt: localBreakEndsAt,
    );

    expect(localResult, isA<SessionTiming>());
    final localTiming = localResult as SessionTiming;
    expect(localTiming.phase, utcTiming.phase);
    expect(localTiming.remainingSeconds, utcTiming.remainingSeconds);
  });

  test('recalculates the phase after a background and resume interval', () {
    final beforeBackground = timingAt(
      startsAt.add(const Duration(minutes: 10)),
    );
    final afterResume = timingAt(focusEndsAt.add(const Duration(minutes: 1)));

    expect(beforeBackground.phase, SessionPhase.focus);
    expect(afterResume.phase, SessionPhase.breakTime);
    expect(afterResume.remainingSeconds, const Duration(minutes: 4).inSeconds);
  });
}
