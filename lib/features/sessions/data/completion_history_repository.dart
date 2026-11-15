import '../../../core/models/completion_record.dart';

final class CompletionHistoryPage {
  CompletionHistoryPage({
    required Iterable<CompletionRecord> records,
    this.nextPageToken,
  }) : records = List.unmodifiable(records);

  final List<CompletionRecord> records;
  final String? nextPageToken;
}

final class CompletionHistorySummary {
  const CompletionHistorySummary({
    required this.creditedSeconds,
    required this.completedSessionCount,
  });

  final int creditedSeconds;

  /// Counts non-demo records with a completed timer, independent of goal outcome.
  final int completedSessionCount;
}

/// Read-only access for the signed-in user's history and complete summary.
/// Implementations must scope both operations through M2's current identity.
/// The M4 history adapter must deduplicate page reads by [CompletionRecord.recordId];
/// this does not replace idempotent completion writes.
abstract interface class CompletionHistoryRepository {
  /// Loads one page. The token is opaque to consumers; null requests the first.
  Future<CompletionHistoryPage> loadCurrentUserHistoryPage({String? pageToken});

  /// Loads totals for all of the current user's eligible non-demo history.
  /// This must not be derived from whichever history page is currently loaded.
  Future<CompletionHistorySummary> loadCurrentUserSummary();
}
