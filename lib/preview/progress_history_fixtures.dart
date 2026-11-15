import 'dart:async';

import '../features/sessions/data/completion_history_repository.dart';
import 'completion_fixtures.dart';

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
    if (scenario == ProgressHistoryScenario.empty) {
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
    if (pageToken == null) {
      return CompletionHistoryPage(
        records: [
          multipleCompletionHistoryFixture.first,
          multipleCompletionHistoryFixture.first,
        ],
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
}
