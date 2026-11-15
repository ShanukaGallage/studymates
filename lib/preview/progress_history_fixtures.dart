import 'dart:async';

import '../core/models/completion_record.dart';
import '../features/sessions/data/completion_history_repository.dart';
import 'completion_fixtures.dart';

const progressLongGoalText =
    'Build a working sensor sketch and explain each connection between the '
    'microcontroller and the sensor. Record several readings, compare them '
    'with the expected range, and document the changes needed when readings '
    'are inconsistent. Review the experiment with a study partner, write down '
    'the remaining questions, and prepare a clear explanation of the next '
    'experiment without losing the original notes or assuming every task is finished.';

final progressLongGoalFixture = CompletionRecord(
  recordId: multipleCompletionHistoryFixture.first.recordId,
  userId: multipleCompletionHistoryFixture.first.userId,
  sessionId: multipleCompletionHistoryFixture.first.sessionId,
  goalText: progressLongGoalText,
  endedAt: multipleCompletionHistoryFixture.first.endedAt,
  creditedSeconds: multipleCompletionHistoryFixture.first.creditedSeconds,
  timerStatus: multipleCompletionHistoryFixture.first.timerStatus,
  goalOutcome: multipleCompletionHistoryFixture.first.goalOutcome,
  isDemo: multipleCompletionHistoryFixture.first.isDemo,
);

/// Explicit local preview repository. Never a production fallback.
/// Summary values come from M3's agreed complete fixture set, not loaded pages.
class ProgressHistoryFixtureRepository implements CompletionHistoryRepository {
  ProgressHistoryFixtureRepository({
    this.scenario = ProgressHistoryScenario.sample,
  });
  final ProgressHistoryScenario scenario;
  bool _summaryFailed = false;
  bool _pageFailed = false;

  @override
  Future<CompletionHistorySummary> loadCurrentUserSummary() async {
    if (scenario == ProgressHistoryScenario.loading) {
      return Completer<CompletionHistorySummary>().future;
    }
    if (scenario == ProgressHistoryScenario.errorOnce && !_summaryFailed) {
      _summaryFailed = true;
      throw StateError('Preview summary error.');
    }
    if (scenario == ProgressHistoryScenario.empty ||
        scenario == ProgressHistoryScenario.cancelledSample) {
      return const CompletionHistorySummary(
        creditedSeconds: 0,
        completedSessionCount: 0,
      );
    }
    return const CompletionHistorySummary(
      creditedSeconds: 3900,
      completedSessionCount: 2,
    );
  }

  @override
  Future<CompletionHistoryPage> loadCurrentUserHistoryPage({
    String? pageToken,
  }) async {
    if (scenario == ProgressHistoryScenario.empty) {
      return CompletionHistoryPage(records: emptyCompletionHistoryFixture);
    }
    if (scenario == ProgressHistoryScenario.cancelledSample) {
      // Display-only provisional M3 example, not a cancellation credit rule.
      return CompletionHistoryPage(
        records: provisionalCancelledCompletionHistoryFixture,
      );
    }
    if (pageToken == null) {
      final first = scenario == ProgressHistoryScenario.longGoal
          ? progressLongGoalFixture
          : multipleCompletionHistoryFixture.first;
      return CompletionHistoryPage(
        records: [first, first],
        nextPageToken: 'fixture-older',
      );
    }
    if (pageToken == 'fixture-older') {
      if (scenario == ProgressHistoryScenario.pageErrorOnce && !_pageFailed) {
        _pageFailed = true;
        throw StateError('Preview page error.');
      }
      return CompletionHistoryPage(
        records: [
          multipleCompletionHistoryFixture.first,
          multipleCompletionHistoryFixture.last,
          ...earlyLeftCompletionHistoryFixture,
          ...demoCompletionHistoryFixture,
        ],
      );
    }
    throw ArgumentError.value(pageToken, 'pageToken', 'Unknown fixture page.');
  }
}

enum ProgressHistoryScenario {
  sample,
  empty,
  loading,
  errorOnce,
  pageErrorOnce,
  longGoal,
  cancelledSample,
}
