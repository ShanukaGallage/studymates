import 'dart:math' as math;

/// Room and hall progress both credit focus only, never the five-minute break.
class HallTiming {
  HallTiming({required DateTime startsAt, required DateTime now}) {
    elapsedSeconds = math.max(
      0,
      now.toUtc().difference(startsAt.toUtc()).inSeconds,
    );
  }
  HallTiming.elapsed(int seconds) : elapsedSeconds = math.max(0, seconds);
  late final int elapsedSeconds;
  static const focusSeconds = 25 * 60;
  static const cycleSeconds = 30 * 60;
  int get completedCycles => elapsedSeconds ~/ cycleSeconds;
  int get cyclePosition => elapsedSeconds % cycleSeconds;
  bool get isBreak => cyclePosition >= focusSeconds;
  int get remainingSeconds =>
      (isBreak ? cycleSeconds : focusSeconds) - cyclePosition;
  int get creditedSeconds =>
      completedCycles * focusSeconds + math.min(cyclePosition, focusSeconds);
}

class HallSession {
  HallSession({
    required this.userId,
    required this.sessionId,
    required this.goalText,
    required DateTime startsAt,
    required DateTime confirmedAt,
  }) : startsAt = startsAt.toUtc(),
       confirmedAt = confirmedAt.toUtc();
  static const presenceLifetime = Duration(minutes: 3);
  final String userId, sessionId, goalText;
  final DateTime startsAt, confirmedAt;
  DateTime get expiresAt => confirmedAt.add(presenceLifetime);
  bool isLive(DateTime now) => expiresAt.isAfter(now.toUtc());
  HallTiming get confirmedTiming =>
      HallTiming(startsAt: startsAt, now: confirmedAt);
}

class HallParticipant {
  const HallParticipant({
    required this.userId,
    required this.sessionId,
    required this.displayName,
    required this.avatarId,
    required this.joinedAt,
    required this.lastSeenAt,
  });
  final String userId, sessionId, displayName, avatarId;
  final DateTime joinedAt, lastSeenAt;
  bool isLive(DateTime now) =>
      lastSeenAt.add(HallSession.presenceLifetime).isAfter(now.toUtc());
}
