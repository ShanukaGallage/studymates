import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/completion_record.dart';
import '../../../sessions/data/completion_history_repository.dart';
import '../../../study/data/firestore_study_repository.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../../app/app_mode.dart';

final progressHistoryRepositoryProvider = Provider<CompletionHistoryRepository>(
  (ref) => ref.watch(studyRepositoryProvider),
);

final progressHistoryProvider =
    AsyncNotifierProvider<ProgressHistoryController, ProgressHistoryData>(
      ProgressHistoryController.new,
      retry: (count, error) => null,
      dependencies: [appModeProvider],
    );

/// Summary is provided by the complete source, never computed from loaded pages.
class ProgressHistoryData {
  ProgressHistoryData({
    required this.summary,
    required Iterable<CompletionRecord> records,
    this.nextPageToken,
    this.isLoadingMore = false,
    this.pageError,
  }) : records = List.unmodifiable(records);

  final CompletionHistorySummary summary;
  final List<CompletionRecord> records;
  final String? nextPageToken;
  final bool isLoadingMore;
  final Object? pageError;

  List<CompletionRecord> get normalRecords =>
      List.unmodifiable(records.where((record) => !record.isDemo));
  List<CompletionRecord> get demoRecords =>
      List.unmodifiable(records.where((record) => record.isDemo));
}

class ProgressHistoryController extends AsyncNotifier<ProgressHistoryData> {
  Object _generation = Object();

  @override
  Future<ProgressHistoryData> build() async {
    if (ref.watch(appModeProvider) == AppMode.connected) {
      ref.watch(authStateProvider.select((value) => value.userId));
    }
    _generation = Object();
    final repository = ref.watch(progressHistoryRepositoryProvider);
    // Start both independent reads together and observe errors from either.
    final results = await Future.wait<Object>([
      repository.loadCurrentUserSummary(),
      repository.loadCurrentUserHistoryPage(),
    ]);
    final page = results[1] as CompletionHistoryPage;
    return ProgressHistoryData(
      summary: results[0] as CompletionHistorySummary,
      records: _mergeRecords(const [], page.records),
      nextPageToken: page.nextPageToken,
    );
  }

  /// Also retries a failed next-page request without reloading the summary.
  Future<void> loadNextPage() async {
    final current = state.asData?.value;
    if (current == null ||
        current.isLoadingMore ||
        current.nextPageToken == null) {
      return;
    }
    final generation = _generation;
    final repository = ref.read(progressHistoryRepositoryProvider);
    state = AsyncData(
      ProgressHistoryData(
        summary: current.summary,
        records: current.records,
        nextPageToken: current.nextPageToken,
        isLoadingMore: true,
      ),
    );
    try {
      final page = await repository.loadCurrentUserHistoryPage(
        pageToken: current.nextPageToken,
      );
      if (!ref.mounted || !identical(generation, _generation)) return;
      if (page.nextPageToken == current.nextPageToken) {
        throw StateError(
          'History repository returned a non-advancing page token.',
        );
      }
      state = AsyncData(
        ProgressHistoryData(
          summary: current.summary,
          records: _mergeRecords(current.records, page.records),
          nextPageToken: page.nextPageToken,
        ),
      );
    } on Object catch (error) {
      if (!ref.mounted || !identical(generation, _generation)) return;
      state = AsyncData(
        ProgressHistoryData(
          summary: current.summary,
          records: current.records,
          nextPageToken: current.nextPageToken,
          pageError: error,
        ),
      );
    }
  }
}

List<CompletionRecord> _mergeRecords(
  Iterable<CompletionRecord> existing,
  Iterable<CompletionRecord> incoming,
) {
  final unique = <String, CompletionRecord>{};
  // Retain the first occurrence; do not invent reconciliation of conflicting
  // versions. Backend finalization must enforce stable immutable completions.
  for (final record in [...existing, ...incoming]) {
    unique.putIfAbsent(record.recordId, () => record);
  }
  return unique.values.toList()..sort((a, b) {
    final byTime = b.endedAt.compareTo(a.endedAt);
    return byTime == 0 ? a.recordId.compareTo(b.recordId) : byTime;
  });
}
