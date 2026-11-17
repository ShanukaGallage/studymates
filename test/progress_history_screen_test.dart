import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/core/models/completion_record.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/features/progress/presentation/controllers/progress_history_controller.dart';
import 'package:studymates/features/progress/presentation/screens/progress_history_screen.dart';
import 'package:studymates/features/sessions/data/completion_history_repository.dart';
import 'package:studymates/preview/progress_history_fixtures.dart';
import 'package:studymates/preview/completion_fixtures.dart';

/// Supplied credit is read-only test data, not a decision about cancellation.
class _CancelledRepository extends ProgressHistoryFixtureRepository {
  _CancelledRepository(this.credit);
  final int credit;

  @override
  Future<CompletionHistorySummary> loadCurrentUserSummary() async =>
      CompletionHistorySummary(
        creditedSeconds: credit,
        completedSessionCount: 0,
      );

  @override
  Future<CompletionHistoryPage> loadCurrentUserHistoryPage({
    String? pageToken,
  }) async {
    final source = provisionalCancelledCompletionHistoryFixture.single;
    return CompletionHistoryPage(
      records: [
        CompletionRecord(
          recordId: source.recordId,
          userId: source.userId,
          sessionId: source.sessionId,
          goalText: source.goalText,
          endedAt: source.endedAt,
          creditedSeconds: credit,
          timerStatus: source.timerStatus,
          goalOutcome: source.goalOutcome,
          isDemo: source.isDemo,
        ),
      ],
    );
  }
}

class _LongSessionRepository extends ProgressHistoryFixtureRepository {
  _LongSessionRepository({this.goalText = progressLongGoalText});
  final String goalText;
  @override
  Future<CompletionHistoryPage> loadCurrentUserHistoryPage({
    String? pageToken,
  }) async => CompletionHistoryPage(
    records: [
      CompletionRecord(
        recordId: 'long',
        userId: 'preview-user-1',
        sessionId: 'Long session identifier ' * 15,
        goalText: goalText,
        endedAt: DateTime.utc(2026, 11, 15),
        creditedSeconds: 1200,
        timerStatus: TimerCompletionStatus.completed,
        goalOutcome: GoalOutcome.unfinished,
        isDemo: false,
      ),
    ],
  );
}

class _ScopedRepository extends ProgressHistoryFixtureRepository {
  _ScopedRepository(this.records, {this.partial = false});
  final List<CompletionRecord> records;
  final bool partial;
  @override
  Future<CompletionHistoryPage> loadCurrentUserHistoryPage({
    String? pageToken,
  }) async => CompletionHistoryPage(
    records: records,
    nextPageToken: partial ? 'older' : null,
  );
}

void main() {
  testWidgets('partial-history notices stay beside each affected section', (
    tester,
  ) async {
    await open(tester, _ScopedRepository([], partial: true));
    expect(metric(tester, 'progress-total-time', '1h 5m'), findsOneWidget);
    expect(find.text('Partial history · Loaded records only'), findsOneWidget);
    expect(find.text('All time · Partial history'), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('study-calendar-toggle')));
    expect(
      find.textContaining('0 active days · Partial history'),
      findsOneWidget,
    );
  });
  testWidgets(
    'all-time Normal totals stay constant across period and Demo controls',
    (tester) async {
      await open(tester, ProgressHistoryFixtureRepository());
      expect(find.text('All-time totals'), findsOneWidget);
      expect(find.text('Normal sessions · Demo excluded'), findsOneWidget);
      expect(metric(tester, 'progress-total-time', '1h 5m'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('progress-total-time')))
            .height,
        tester
            .getSize(find.byKey(const ValueKey('progress-total-count')))
            .height,
      );
      for (final period in ['Day', 'Week', 'Month', 'All time']) {
        await tapVisible(tester, find.text(period));
        expect(metric(tester, 'progress-total-time', '1h 5m'), findsOneWidget);
        expect(
          find.text(
            period == 'All time'
                ? 'Last 7 days'
                : 'Last 7 days · $period filter',
          ),
          findsOneWidget,
        );
      }
      await tapVisible(tester, find.text('Demo'));
      expect(
        find.text('Demo data · Excluded from Normal totals'),
        findsOneWidget,
      );
      expect(metric(tester, 'progress-total-time', '1h 5m'), findsOneWidget);
      expect(metric(tester, 'progress-total-count', '2'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('About your progress'));
      expect(
        find.textContaining('All-time totals cover all Normal sessions'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Close'));
    },
  );

  testWidgets(
    'paging keeps newest-first rows and separates Normal/Demo details',
    (tester) async {
      await open(tester, ProgressHistoryFixtureRepository());
      await reveal(tester, find.text('Session history'));
      expect(find.text('Session history'), findsOneWidget);
      expect(find.textContaining('Session: '), findsNothing);
      final first = find.byKey(
        const ValueKey('progress-record-completion-user-1-session-1'),
      );
      await tapVisible(tester, first);
      expect(find.text('Build a working sensor sketch'), findsOneWidget);
      expect(find.text('Recorded time: 20m'), findsOneWidget);
      expect(find.text('Goal: Unfinished'), findsOneWidget);
      expect(find.text('Session: session-1'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Close session details'));
      await tapVisible(tester, find.text('Load more history'));
      await top(tester);
      await tapVisible(tester, find.text('Demo'));
      await tapVisible(
        tester,
        find.byKey(
          const ValueKey('progress-record-completion-user-1-demo-session'),
        ),
      );
      expect(find.text('Recorded time: 1m 15s'), findsOneWidget);
      expect(find.text('Session: demo-session'), findsOneWidget);
      expect(find.text('Session: session-1'), findsNothing);
      await tapVisible(tester, find.byTooltip('Close session details'));
      await top(tester);
      expect(metric(tester, 'progress-total-time', '1h 5m'), findsOneWidget);
    },
  );

  testWidgets('page retry retains the complete summary and existing rows', (
    tester,
  ) async {
    await open(
      tester,
      ProgressHistoryFixtureRepository(
        scenario: ProgressHistoryScenario.pageErrorOnce,
      ),
    );
    await tapVisible(tester, find.text('Load more history'));
    expect(
      find.textContaining('Your loaded records and summary'),
      findsOneWidget,
    );
    await top(tester);
    expect(metric(tester, 'progress-total-count', '2'), findsOneWidget);
    await tapVisible(tester, find.text('Retry loading more'));
    expect(find.textContaining('Could not load more history'), findsNothing);
    await tapVisible(
      tester,
      find.byKey(
        const ValueKey('progress-record-completion-user-1-early-session'),
      ),
    );
    expect(find.text('Timer: Ended early'), findsOneWidget);
  });

  testWidgets(
    'failed initial read retries without displaying an invented zero',
    (tester) async {
      await open(
        tester,
        ProgressHistoryFixtureRepository(
          scenario: ProgressHistoryScenario.errorOnce,
        ),
      );
      expect(find.byKey(const ValueKey('progress-total-time')), findsNothing);
      await tapVisible(tester, find.text('Retry'));
      expect(metric(tester, 'progress-total-time', '1h 5m'), findsOneWidget);
    },
  );

  testWidgets(
    'loading retains the filters and never displays a false summary',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressHistoryRepositoryProvider.overrideWithValue(
              ProgressHistoryFixtureRepository(
                scenario: ProgressHistoryScenario.loading,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: ProgressHistoryScreen()),
          ),
        ),
      );
      await tester.pump();
      expect(find.byTooltip('Refresh history'), findsOneWidget);
      expect(find.text('All time'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.byKey(const ValueKey('progress-total-time')), findsNothing);
    },
  );

  testWidgets('empty Normal and Demo history have explicit empty states', (
    tester,
  ) async {
    await open(
      tester,
      ProgressHistoryFixtureRepository(scenario: ProgressHistoryScenario.empty),
    );
    expect(metric(tester, 'progress-total-time', '0m'), findsOneWidget);
    await reveal(tester, find.text('No recorded sessions yet.'));
    expect(find.text('No recorded sessions yet.'), findsOneWidget);
    await top(tester);
    await tapVisible(tester, find.text('Demo'));
    await reveal(tester, find.text('No demo records.'));
    expect(find.text('No demo records.'), findsOneWidget);
  });

  testWidgets('a partial page never claims Demo history is globally empty', (
    tester,
  ) async {
    await open(tester, ProgressHistoryFixtureRepository());
    await tapVisible(tester, find.text('Demo'));
    await reveal(
      tester,
      find.textContaining('No demo records in loaded pages.'),
    );
    expect(
      find.textContaining('No demo records in loaded pages.'),
      findsOneWidget,
    );
    expect(find.text('No demo records.'), findsNothing);
  });

  testWidgets(
    'zero-time unfinished records remain in goals and session history',
    (tester) async {
      final now = DateTime.now();
      final records = [
        CompletionRecord(
          recordId: 'zero',
          userId: 'u',
          sessionId: 'zero-session',
          goalText: 'Unfinished task',
          endedAt: now,
          creditedSeconds: 0,
          timerStatus: TimerCompletionStatus.endedEarly,
          goalOutcome: GoalOutcome.unfinished,
          isDemo: false,
        ),
      ];
      await open(tester, _ScopedRepository(records));
      expect(find.text('Last 7 days'), findsOneWidget);
      expect(
        find.text('No study time recorded for this period'),
        findsOneWidget,
      );
      await reveal(
        tester,
        find.byKey(const ValueKey('progress-goals-unfinished')),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('progress-goals-unfinished')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('progress-record-zero')),
      );
      expect(find.text('Recorded time: 0m'), findsOneWidget);
      expect(find.text('Timer: Ended early'), findsOneWidget);
      expect(find.text('Goal: Unfinished'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Close session details'));
      await reveal(tester, find.byKey(const ValueKey('study-calendar-toggle')));
      expect(find.textContaining('0 active days'), findsOneWidget);
    },
  );

  testWidgets('period filtering and calendar year remain independent', (
    tester,
  ) async {
    final now = DateTime.now();
    CompletionRecord record(String id, DateTime date) => CompletionRecord(
      recordId: id,
      userId: 'u',
      sessionId: id,
      goalText: id,
      endedAt: date,
      creditedSeconds: 600,
      timerStatus: TimerCompletionStatus.completed,
      goalOutcome: GoalOutcome.completed,
      isDemo: false,
    );
    await open(
      tester,
      _ScopedRepository([
        record('today', now),
        record('old', DateTime(now.year - 1, 2, 4)),
      ]),
    );
    await tapVisible(tester, find.text('Day'));
    await reveal(tester, find.text('Session history'));
    expect(find.byKey(const ValueKey('progress-record-old')), findsNothing);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('study-calendar-toggle')),
    );
    await tapVisible(tester, find.byTooltip('Previous study year'));
    expect(find.text('${now.year - 1} · 1 active day'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('study-calendar-toggle')),
    );
    expect(find.text('${now.year - 1} · 1 active day'), findsOneWidget);
    await top(tester);
    await tapVisible(tester, find.text('All time'));
    await reveal(tester, find.byKey(const ValueKey('study-calendar-toggle')));
    expect(find.text('${now.year - 1} · 1 active day'), findsOneWidget);
  });

  for (final credit in {0: '0m', 125: '2m 5s'}.entries) {
    testWidgets('cancelled ${credit.key}s is displayed exactly as supplied', (
      tester,
    ) async {
      await open(tester, _CancelledRepository(credit.key));
      expect(
        metric(tester, 'progress-total-time', credit.value),
        findsOneWidget,
      );
      await tapVisible(
        tester,
        find.byKey(
          const ValueKey('progress-record-completion-user-1-cancelled-session'),
        ),
      );
      expect(find.text('Timer: Cancelled'), findsOneWidget);
      expect(find.text('Recorded time: ${credit.value}'), findsOneWidget);
      expect(find.text('Read the assigned chapter'), findsOneWidget);
    });
  }

  testWidgets(
    'large text supports long goals and identifiers in scrollable session details',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, _LongSessionRepository(), largeText: true);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('progress-total-time')))
            .height,
        tester
            .getSize(find.byKey(const ValueKey('progress-total-count')))
            .height,
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('progress-record-long')),
      );
      await reveal(tester, find.text(progressLongGoalText), inSheet: true);
      expect(
        tester.widget<Text>(find.text(progressLongGoalText)).maxLines,
        isNull,
      );
      await reveal(tester, find.textContaining('Session: '), inSheet: true);
      expect(find.textContaining('Session: '), findsOneWidget);
      tester.view.physicalSize = const Size(568, 320);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('blank stored goal retains its fallback in session details', (
    tester,
  ) async {
    await open(tester, _LongSessionRepository(goalText: '   '));
    await tapVisible(
      tester,
      find.byKey(const ValueKey('progress-record-long')),
    );
    expect(find.text('No goal text recorded.'), findsOneWidget);
    expect(find.text('Recorded time: 20m'), findsOneWidget);
  });
}

Finder metric(WidgetTester tester, String key, String text) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

Future<void> open(
  WidgetTester tester,
  CompletionHistoryRepository repository, {
  bool largeText = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        progressHistoryRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(largeText ? 2 : 1)),
          child: child!,
        ),
        home: const Scaffold(body: ProgressHistoryScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> top(WidgetTester tester) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
}

Future<void> reveal(
  WidgetTester tester,
  Finder target, {
  bool inSheet = false,
}) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}
