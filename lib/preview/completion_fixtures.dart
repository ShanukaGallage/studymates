import '../core/models/completion_record.dart';

final emptyCompletionHistoryFixture = List<CompletionRecord>.unmodifiable(
  const <CompletionRecord>[],
);

final multipleCompletionHistoryFixture = List<CompletionRecord>.unmodifiable([
  CompletionRecord(
    recordId: 'completion-user-1-session-1',
    userId: 'preview-user-1',
    sessionId: 'session-1',
    goalText: 'Build a working sensor sketch',
    endedAt: DateTime.utc(2026, 11, 15, 10),
    creditedSeconds: 1200,
    timerStatus: TimerCompletionStatus.completed,
    goalOutcome: GoalOutcome.unfinished,
    isDemo: false,
  ),
  CompletionRecord(
    recordId: 'completion-user-1-session-2',
    userId: 'preview-user-1',
    sessionId: 'session-2',
    goalText: 'Review the sensor notes',
    endedAt: DateTime.utc(2026, 11, 14, 10),
    creditedSeconds: 1800,
    timerStatus: TimerCompletionStatus.completed,
    goalOutcome: GoalOutcome.completed,
    isDemo: false,
  ),
]);

final earlyLeftCompletionHistoryFixture = List<CompletionRecord>.unmodifiable([
  CompletionRecord(
    recordId: 'completion-user-1-early-session',
    userId: 'preview-user-1',
    sessionId: 'early-session',
    goalText: 'Finish the practice questions',
    endedAt: DateTime.utc(2026, 11, 12, 10),
    creditedSeconds: 900,
    timerStatus: TimerCompletionStatus.endedEarly,
    goalOutcome: GoalOutcome.unfinished,
    isDemo: false,
  ),
]);

// Provisional example only: use this zero-credit cancellation if M2/M3 confirm
// that cancellation means participation with no eligible credited time.
final provisionalCancelledCompletionHistoryFixture =
    List<CompletionRecord>.unmodifiable([
      CompletionRecord(
        recordId: 'completion-user-1-cancelled-session',
        userId: 'preview-user-1',
        sessionId: 'cancelled-session',
        goalText: 'Read the assigned chapter',
        endedAt: DateTime.utc(2026, 11, 11, 10),
        creditedSeconds: 0,
        timerStatus: TimerCompletionStatus.cancelled,
        goalOutcome: GoalOutcome.unfinished,
        isDemo: false,
      ),
    ]);

final demoCompletionHistoryFixture = List<CompletionRecord>.unmodifiable([
  CompletionRecord(
    recordId: 'completion-user-1-demo-session',
    userId: 'preview-user-1',
    sessionId: 'demo-session',
    goalText: 'Try a sample goal',
    endedAt: DateTime.utc(2026, 11, 13, 10),
    creditedSeconds: 75,
    timerStatus: TimerCompletionStatus.completed,
    goalOutcome: GoalOutcome.unfinished,
    isDemo: true,
  ),
]);

// Duplicate backend read result for exercising M4's defensive adapter behavior.
final duplicateCompletionHistoryFixture = List<CompletionRecord>.unmodifiable([
  multipleCompletionHistoryFixture.first,
  multipleCompletionHistoryFixture.first,
]);
