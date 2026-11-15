import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/core/models/completion_record.dart';
import 'package:studymates/features/sessions/data/completion_history_repository.dart';
import 'package:studymates/preview/completion_fixtures.dart';

void main() {
  group('CompletionRecord', () {
    test('keeps timer status and goal outcome separate', () {
      final record = multipleCompletionHistoryFixture.first;

      expect(record.timerStatus, TimerCompletionStatus.completed);
      expect(record.goalOutcome, GoalOutcome.unfinished);
      expect(record.creditedSeconds, 1200);
    });

    test('normalizes endedAt to UTC', () {
      final localEndedAt = DateTime(2026, 11, 15, 10);
      final record = _record(endedAt: localEndedAt);

      expect(record.endedAt, localEndedAt.toUtc());
      expect(record.endedAt.isUtc, isTrue);
    });

    test('requires stable identity fields and non-negative credited time', () {
      expect(() => _record(recordId: ''), throwsArgumentError);
      expect(() => _record(userId: ' '), throwsArgumentError);
      expect(() => _record(sessionId: ''), throwsArgumentError);
      expect(() => _record(creditedSeconds: -1), throwsArgumentError);
    });

    test(
      'preserves the record identity without claiming duplicate prevention',
      () {
        final record = _record(recordId: 'stable-user-session-id');

        expect(record.recordId, 'stable-user-session-id');
      },
    );
  });

  group('completion fixtures', () {
    test(
      'provide empty, multiple, unfinished-goal, early-left, and demo records',
      () {
        expect(emptyCompletionHistoryFixture, isEmpty);
        expect(multipleCompletionHistoryFixture, hasLength(2));
        expect(
          multipleCompletionHistoryFixture.first.goalOutcome,
          GoalOutcome.unfinished,
        );
        expect(multipleCompletionHistoryFixture.first.creditedSeconds, 1200);
        expect(earlyLeftCompletionHistoryFixture, hasLength(1));
        expect(
          earlyLeftCompletionHistoryFixture.single.timerStatus,
          TimerCompletionStatus.endedEarly,
        );
        expect(earlyLeftCompletionHistoryFixture.single.creditedSeconds, 900);
        expect(demoCompletionHistoryFixture, hasLength(1));
        expect(demoCompletionHistoryFixture.single.isDemo, isTrue);
        expect(
          multipleCompletionHistoryFixture.every((record) => !record.isDemo),
          isTrue,
        );
      },
    );

    test('cancelled zero-credit fixture is explicitly provisional', () {
      final record = provisionalCancelledCompletionHistoryFixture.single;

      expect(record.timerStatus, TimerCompletionStatus.cancelled);
      expect(record.creditedSeconds, 0);
      expect(record.isDemo, isFalse);
    });
  });

  group('CompletionHistoryRepository contract', () {
    test('keeps user scoping at the current-user boundary', () async {
      final records = [
        ...multipleCompletionHistoryFixture,
        _record(recordId: 'other-user-record', userId: 'preview-user-2'),
      ];
      final firstUserRepository = _FixtureHistoryRepository(
        currentUserId: 'preview-user-1',
        allRecords: records,
      );
      final secondUserRepository = _FixtureHistoryRepository(
        currentUserId: 'preview-user-2',
        allRecords: records,
      );

      final firstUserPage = await firstUserRepository
          .loadCurrentUserHistoryPage();
      final secondUserPage = await secondUserRepository
          .loadCurrentUserHistoryPage();

      expect(
        firstUserPage.records.every(
          (record) => record.userId == 'preview-user-1',
        ),
        isTrue,
      );
      expect(secondUserPage.records.map((record) => record.userId), [
        'preview-user-2',
      ]);
    });

    test(
      'counts only completed non-demo timers, independently of goal outcome',
      () async {
        final repository = _FixtureHistoryRepository(
          currentUserId: 'preview-user-1',
          allRecords: [
            ...multipleCompletionHistoryFixture,
            ...earlyLeftCompletionHistoryFixture,
            ...provisionalCancelledCompletionHistoryFixture,
            ...demoCompletionHistoryFixture,
          ],
        );

        final summary = await repository.loadCurrentUserSummary();

        expect(summary.creditedSeconds, 3900);
        expect(summary.completedSessionCount, 2);
      },
    );

    test(
      'early-left records retain credited time but are not completed',
      () async {
        final repository = _FixtureHistoryRepository(
          currentUserId: 'preview-user-1',
          allRecords: earlyLeftCompletionHistoryFixture,
        );

        final summary = await repository.loadCurrentUserSummary();

        expect(summary.creditedSeconds, 900);
        expect(summary.completedSessionCount, 0);
      },
    );

    test(
      'provisional cancelled example contributes zero and is not completed',
      () async {
        final repository = _FixtureHistoryRepository(
          currentUserId: 'preview-user-1',
          allRecords: provisionalCancelledCompletionHistoryFixture,
        );

        final summary = await repository.loadCurrentUserSummary();

        expect(summary.creditedSeconds, 0);
        expect(summary.completedSessionCount, 0);
      },
    );

    test('summary remains stable as additional pages are loaded', () async {
      final allRecords = [
        ...multipleCompletionHistoryFixture,
        ...earlyLeftCompletionHistoryFixture,
        ...provisionalCancelledCompletionHistoryFixture,
        ...demoCompletionHistoryFixture,
      ];
      final repository = _FixtureHistoryRepository(
        currentUserId: 'preview-user-1',
        allRecords: allRecords,
        pageSize: 1,
      );

      final summaryBeforePaging = await repository.loadCurrentUserSummary();
      var pageToken = await repository.loadCurrentUserHistoryPage();
      var loadedRecords = pageToken.records.length;
      while (pageToken.nextPageToken != null) {
        pageToken = await repository.loadCurrentUserHistoryPage(
          pageToken: pageToken.nextPageToken,
        );
        loadedRecords += pageToken.records.length;
      }
      final summaryAfterPaging = await repository.loadCurrentUserSummary();

      expect(loadedRecords, allRecords.length);
      expect(summaryBeforePaging.creditedSeconds, 3900);
      expect(summaryBeforePaging.completedSessionCount, 2);
      expect(
        summaryAfterPaging.creditedSeconds,
        summaryBeforePaging.creditedSeconds,
      );
      expect(
        summaryAfterPaging.completedSessionCount,
        summaryBeforePaging.completedSessionCount,
      );
    });
  });
}

CompletionRecord _record({
  String recordId = 'completion-user-1-session-1',
  String userId = 'preview-user-1',
  String sessionId = 'session-1',
  DateTime? endedAt,
  int creditedSeconds = 600,
}) => CompletionRecord(
  recordId: recordId,
  userId: userId,
  sessionId: sessionId,
  endedAt: endedAt ?? DateTime.utc(2026, 11, 15),
  creditedSeconds: creditedSeconds,
  timerStatus: TimerCompletionStatus.completed,
  goalOutcome: GoalOutcome.completed,
  isDemo: false,
);

class _FixtureHistoryRepository implements CompletionHistoryRepository {
  _FixtureHistoryRepository({
    required String currentUserId,
    required Iterable<CompletionRecord> allRecords,
    this.pageSize = 2,
  }) : _records = List.unmodifiable(
         allRecords.where((record) => record.userId == currentUserId),
       );

  final List<CompletionRecord> _records;
  final int pageSize;

  @override
  Future<CompletionHistoryPage> loadCurrentUserHistoryPage({
    String? pageToken,
  }) async {
    final start = int.tryParse(pageToken ?? '') ?? 0;
    final end = (start + pageSize).clamp(0, _records.length);
    final pageRecords = _records.sublist(start.clamp(0, _records.length), end);
    final nextPageToken = end < _records.length ? '$end' : null;
    return CompletionHistoryPage(
      records: pageRecords,
      nextPageToken: nextPageToken,
    );
  }

  @override
  Future<CompletionHistorySummary> loadCurrentUserSummary() async {
    final normalRecords = _records.where((record) => !record.isDemo);
    return CompletionHistorySummary(
      creditedSeconds: normalRecords.fold(
        0,
        (total, record) => total + record.creditedSeconds,
      ),
      completedSessionCount: normalRecords
          .where(
            (record) => record.timerStatus == TimerCompletionStatus.completed,
          )
          .length,
    );
  }
}
