import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/core/models/completion_record.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/features/progress/presentation/controllers/progress_history_controller.dart';
import 'package:studymates/features/progress/presentation/screens/progress_history_screen.dart';
import 'package:studymates/features/sessions/data/completion_history_repository.dart';
import 'package:studymates/preview/progress_history_fixtures.dart';
import 'package:studymates/preview/progress_history_preview.dart';
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
        goalText: 'Complete a focused study session',
        endedAt: DateTime.utc(2026, 11, 15),
        creditedSeconds: 1200,
        timerStatus: TimerCompletionStatus.completed,
        goalOutcome: GoalOutcome.unfinished,
        isDemo: false,
      ),
    ],
  );
}

void main() {
  testWidgets(
    'preview scenario switch resets repository and supports error retry',
    (tester) async {
      await tester.pumpWidget(const ProgressHistoryPreview());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Preview scenarios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empty history'));
      await tester.pumpAndSettle();
      expect(find.text('No recorded sessions yet.'), findsOneWidget);
      await tester.tap(find.byTooltip('Preview scenarios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Initial error once'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not load your history'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Eligible recorded time: 1h 5m'), findsOneWidget);
    },
  );

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

  Future<void> tapVisible(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'paging preserves summary and separates demo from normal records',
    (tester) async {
      await open(tester, ProgressHistoryFixtureRepository());
      expect(find.text('Eligible recorded time: 1h 5m'), findsOneWidget);
      expect(find.text('Completed sessions: 2'), findsOneWidget);
      expect(find.text('Goal: Unfinished'), findsOneWidget);
      expect(find.text('Build a working sensor sketch'), findsOneWidget);
      expect(find.text('Recorded time: 20m'), findsOneWidget);
      await tapVisible(tester, 'Load more history');
      expect(
        find.byKey(
          const ValueKey('progress-record-completion-user-1-session-1'),
        ),
        findsOneWidget,
      );
      expect(find.text('Session: demo-session'), findsNothing);
      await tapVisible(tester, 'Demo history');
      expect(find.text('Demo history · rehearsal only'), findsOneWidget);
      expect(find.text('Recorded time: 1m 15s'), findsOneWidget);
      expect(find.text('Session: session-1'), findsNothing);
      expect(find.text('Eligible recorded time: 1h 5m'), findsOneWidget);
    },
  );

  testWidgets('page retry retains summary and existing rows', (tester) async {
    await open(
      tester,
      ProgressHistoryFixtureRepository(
        scenario: ProgressHistoryScenario.pageErrorOnce,
      ),
    );
    await tapVisible(tester, 'Load more history');
    expect(
      find.textContaining('Your loaded records and summary'),
      findsOneWidget,
    );
    expect(find.text('Completed sessions: 2'), findsOneWidget);
    await tapVisible(tester, 'Retry loading more');
    expect(find.textContaining('Could not load more history'), findsNothing);
    expect(find.text('Timer: Ended early'), findsOneWidget);
  });

  testWidgets('failed initial read retries to fixture data', (tester) async {
    await open(
      tester,
      ProgressHistoryFixtureRepository(
        scenario: ProgressHistoryScenario.errorOnce,
      ),
    );
    expect(find.text('Eligible recorded time: 0m'), findsNothing);
    await tapVisible(tester, 'Retry');
    expect(find.text('Eligible recorded time: 1h 5m'), findsOneWidget);
  });

  testWidgets(
    'empty history shows zero only from a successful complete summary',
    (tester) async {
      await open(
        tester,
        ProgressHistoryFixtureRepository(
          scenario: ProgressHistoryScenario.empty,
        ),
      );
      expect(find.text('Eligible recorded time: 0m'), findsOneWidget);
      expect(find.text('No recorded sessions yet.'), findsOneWidget);
      await tapVisible(tester, 'Demo history');
      expect(find.text('No demo records.'), findsOneWidget);
    },
  );

  testWidgets(
    'demo absence on a partial page is not claimed as globally empty',
    (tester) async {
      await open(tester, ProgressHistoryFixtureRepository());
      await tapVisible(tester, 'Demo history');
      expect(
        find.textContaining('No demo records in loaded pages.'),
        findsOneWidget,
      );
      expect(find.text('No demo records.'), findsNothing);
    },
  );

  testWidgets(
    '320px large text scrolls full long goal and session identifier without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, _LongSessionRepository(), largeText: true);
      await tester.ensureVisible(find.text('Goal: Unfinished'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Recorded time: 20m'), findsOneWidget);
      expect(find.text(progressLongGoalText), findsOneWidget);
      final goal = tester.widget<Text>(find.text(progressLongGoalText));
      expect(goal.maxLines, isNull);
      expect(goal.overflow, isNull);
    },
  );

  testWidgets(
    'long-goal preview keeps text and credit after paging duplicates',
    (tester) async {
      await open(
        tester,
        ProgressHistoryFixtureRepository(
          scenario: ProgressHistoryScenario.longGoal,
        ),
      );
      expect(find.text(progressLongGoalText), findsOneWidget);
      await tapVisible(tester, 'Load more history');
      expect(find.text(progressLongGoalText), findsOneWidget);
      expect(find.text('Build a working sensor sketch'), findsNothing);
      expect(find.text('Eligible recorded time: 1h 5m'), findsOneWidget);
      expect(find.text('Completed sessions: 2'), findsOneWidget);
    },
  );

  testWidgets(
    'blank stored goal has a readable fallback without hiding credited time',
    (tester) async {
      await open(tester, _LongSessionRepository(goalText: '   '));
      expect(find.text('No goal text recorded.'), findsOneWidget);
      expect(find.text('Recorded time: 20m'), findsOneWidget);
      expect(find.text('Goal: Unfinished'), findsOneWidget);
    },
  );

  for (final sample in {0: '0m', 125: '2m 5s'}.entries) {
    testWidgets(
      'cancelled record displays supplied ${sample.key}s without awarding or erasing credit',
      (tester) async {
        await open(tester, _CancelledRepository(sample.key));
        expect(find.text('Timer: Cancelled'), findsOneWidget);
        expect(find.text('Recorded time: ${sample.value}'), findsOneWidget);
        expect(
          find.text('Eligible recorded time: ${sample.value}'),
          findsOneWidget,
        );
        expect(find.text('Completed sessions: 0'), findsOneWidget);
        expect(find.text('Read the assigned chapter'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'long goal survives portrait to landscape with large text and accessible pagination',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(
        tester,
        ProgressHistoryFixtureRepository(
          scenario: ProgressHistoryScenario.longGoal,
        ),
        largeText: true,
      );
      tester.view.physicalSize = const Size(568, 320);
      await tester.pumpAndSettle();
      expect(find.text(progressLongGoalText), findsOneWidget);
      await tapVisible(tester, 'Load more history');
      expect(tester.takeException(), isNull);
      expect(find.text('Eligible recorded time: 1h 5m'), findsOneWidget);
      expect(find.text('Completed sessions: 2'), findsOneWidget);
      await tapVisible(tester, 'Demo history');
      await tester.ensureVisible(find.text('Recorded time: 1m 15s'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Recorded time: 1m 15s'), findsOneWidget);
    },
  );
}
