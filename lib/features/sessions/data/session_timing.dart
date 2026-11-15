enum SessionPhase { waiting, focus, breakTime, completed }

enum SessionTimingError { missingTimestamp, invalidTimestampOrder }

sealed class SessionTimingResult {
  const SessionTimingResult();
}

final class SessionTiming extends SessionTimingResult {
  const SessionTiming({required this.phase, required this.remainingSeconds});

  final SessionPhase phase;
  final int remainingSeconds;
}

final class InvalidSessionTiming extends SessionTimingResult {
  const InvalidSessionTiming(this.error);

  final SessionTimingError error;
}

SessionTimingResult calculateSessionTiming({
  required DateTime nowUtc,
  required DateTime? startsAt,
  required DateTime? focusEndsAt,
  required DateTime? breakEndsAt,
}) {
  if (startsAt == null || focusEndsAt == null || breakEndsAt == null) {
    return const InvalidSessionTiming(SessionTimingError.missingTimestamp);
  }

  final start = startsAt.toUtc();
  final focusEnd = focusEndsAt.toUtc();
  final breakEnd = breakEndsAt.toUtc();
  final now = nowUtc.toUtc();

  if (!start.isBefore(focusEnd) || !focusEnd.isBefore(breakEnd)) {
    return const InvalidSessionTiming(SessionTimingError.invalidTimestampOrder);
  }

  if (now.isBefore(start)) {
    return SessionTiming(
      phase: SessionPhase.waiting,
      remainingSeconds: _remainingSeconds(start.difference(now)),
    );
  }

  if (now.isBefore(focusEnd)) {
    return SessionTiming(
      phase: SessionPhase.focus,
      remainingSeconds: _remainingSeconds(focusEnd.difference(now)),
    );
  }

  if (now.isBefore(breakEnd)) {
    return SessionTiming(
      phase: SessionPhase.breakTime,
      remainingSeconds: _remainingSeconds(breakEnd.difference(now)),
    );
  }

  return const SessionTiming(
    phase: SessionPhase.completed,
    remainingSeconds: 0,
  );
}

int _remainingSeconds(Duration remaining) {
  final microseconds = remaining.inMicroseconds;
  if (microseconds <= 0) return 0;

  return (microseconds + Duration.microsecondsPerSecond - 1) ~/
      Duration.microsecondsPerSecond;
}
