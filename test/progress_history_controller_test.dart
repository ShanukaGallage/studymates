import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/features/progress/presentation/controllers/progress_history_controller.dart';
import 'package:studymates/features/sessions/data/completion_history_repository.dart';
import 'package:studymates/preview/completion_fixtures.dart';
import 'package:studymates/preview/progress_history_fixtures.dart';

class _Repository extends ProgressHistoryFixtureRepository {
  int summaryReads = 0;
  int olderReads = 0;
  bool failSummary = false;
  bool failOlder = false;
  Completer<CompletionHistoryPage>? pendingOlder;

  @override
  Future<CompletionHistorySummary> loadCurrentUserSummary() async {
    summaryReads++;
    if (failSummary) throw StateError('summary unavailable');
    return super.loadCurrentUserSummary();
  }

  @override
  Future<CompletionHistoryPage> loadCurrentUserHistoryPage({
    String? pageToken,
  }) async {
    if (pageToken != null) {
      olderReads++;
      if (failOlder) throw StateError('page unavailable');
      if (pendingOlder != null) return pendingOlder!.future;
    }
    return super.loadCurrentUserHistoryPage(pageToken: pageToken);
  }
}

void main() {
  ProviderContainer containerFor(CompletionHistoryRepository repository) {
    final container = ProviderContainer(
      overrides: [
        progressHistoryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'pages deduplicate and preserve all-history summary and unfinished credit',
    () async {
      final repository = _Repository();
      final container = containerFor(repository);
      final initial = await container.read(progressHistoryProvider.future);
      expect(initial.records.length, 1);
      expect(initial.records.single.creditedSeconds, 1200);
      expect(
        initial.records.single.goalOutcome,
        multipleCompletionHistoryFixture.first.goalOutcome,
      );
      expect(initial.summary.creditedSeconds, 3900);
      expect(initial.summary.completedSessionCount, 2);
      await container.read(progressHistoryProvider.notifier).loadNextPage();
      final loaded = container.read(progressHistoryProvider).requireValue;
      expect(loaded.records.length, 4);
      expect(loaded.summary, same(initial.summary));
      expect(repository.summaryReads, 1);
      expect(
        loaded.normalRecords.fold<int>(
          0,
          (total, record) => total + record.creditedSeconds,
        ),
        3900,
      );
      expect(loaded.demoRecords.single.creditedSeconds, 75);
      expect(loaded.nextPageToken, isNull);
      expect(() => loaded.records.clear(), throwsUnsupportedError);
    },
  );

  test('page error retains records/summary/token and retries without double counting', () async {
    final repository = _Repository()..failOlder = true;
    final container = containerFor(repository);
    final initial = await container.read(progressHistoryProvider.future);
    final controller = container.read(progressHistoryProvider.notifier);
    await controller.loadNextPage();
    final failed = container.read(progressHistoryProvider).requireValue;
    expect(failed.pageError, isStateError);
    expect(failed.records.single.recordId, initial.records.single.recordId);
    expect(failed.summary, same(initial.summary));
    repository.failOlder = false;
    await controller.loadNextPage();
    final recovered = container.read(progressHistoryProvider).requireValue;
    expect(recovered.pageError, isNull);
    expect(recovered.records.length, 4);
    expect(repository.summaryReads, 1);
  });

  test('concurrent load-more taps issue one request', () async {
    final repository = _Repository()
      ..pendingOlder = Completer<CompletionHistoryPage>();
    final container = containerFor(repository);
    await container.read(progressHistoryProvider.future);
    final controller = container.read(progressHistoryProvider.notifier);
    final first = controller.loadNextPage();
    await controller.loadNextPage();
    expect(repository.olderReads, 1);
    repository.pendingOlder!.complete(CompletionHistoryPage(records: []));
    await first;
    expect(
      container.read(progressHistoryProvider).requireValue.isLoadingMore,
      isFalse,
    );
  });

  test('refresh discards an older page result in flight', () async {
    final repository = _Repository()
      ..pendingOlder = Completer<CompletionHistoryPage>();
    final container = containerFor(repository);
    await container.read(progressHistoryProvider.future);
    final pending = container
        .read(progressHistoryProvider.notifier)
        .loadNextPage();
    container.invalidate(progressHistoryProvider);
    await container.read(progressHistoryProvider.future);
    repository.pendingOlder!.complete(
      CompletionHistoryPage(records: demoCompletionHistoryFixture),
    );
    await pending;
    expect(
      container.read(progressHistoryProvider).requireValue.demoRecords,
      isEmpty,
    );
  });

  test('initial summary failure stays an error until explicit retry', () async {
    final repository = _Repository()..failSummary = true;
    final container = containerFor(repository);
    await expectLater(
      container.read(progressHistoryProvider.future),
      throwsStateError,
    );
    expect(container.read(progressHistoryProvider).hasError, isTrue);
    repository.failSummary = false;
    container.invalidate(progressHistoryProvider);
    final retried = await container.read(progressHistoryProvider.future);
    expect(retried.summary.creditedSeconds, 3900);
  });
}
