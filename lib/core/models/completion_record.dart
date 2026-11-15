enum TimerCompletionStatus { completed, endedEarly, cancelled }

enum GoalOutcome { completed, unfinished }

final class CompletionRecord {
  CompletionRecord({
    required this.recordId,
    required this.userId,
    required this.sessionId,
    required DateTime endedAt,
    required this.creditedSeconds,
    required this.timerStatus,
    required this.goalOutcome,
    required this.isDemo,
  }) : endedAt = endedAt.toUtc() {
    _requireNonEmpty(recordId, 'recordId');
    _requireNonEmpty(userId, 'userId');
    _requireNonEmpty(sessionId, 'sessionId');
    if (creditedSeconds < 0) {
      throw ArgumentError.value(
        creditedSeconds,
        'creditedSeconds',
        'Must not be negative.',
      );
    }
  }

  final String recordId;
  final String userId;
  final String sessionId;
  final DateTime endedAt;
  final int creditedSeconds;
  final TimerCompletionStatus timerStatus;
  final GoalOutcome goalOutcome;
  final bool isDemo;
}

void _requireNonEmpty(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}
