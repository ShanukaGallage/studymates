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

class _LongSessionRepository extends ProgressHistoryFixtureRepository {
  @override
  Future<CompletionHistoryPage> loadCurrentUserHistoryPage({
    String? pageToken,
  }) async => CompletionHistoryPage(
    records: [
      CompletionRecord(
        recordId: 'long',
        userId: 'preview-user-1',
        sessionId: 'Long session identifier ' * 15,
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
    '320px large text scrolls long session identifiers without overflow',
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
    },
  );
}
