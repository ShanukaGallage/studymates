import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/core/models/completion_record.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/features/progress/presentation/widgets/progress_dashboard.dart';
import 'package:studymates/features/progress/presentation/widgets/progress_controls.dart';

CompletionRecord record(String id, DateTime date) => CompletionRecord(
  recordId: id,
  userId: 'user',
  sessionId: id,
  goalText: 'Read',
  endedAt: date,
  creditedSeconds: 60,
  timerStatus: TimerCompletionStatus.completed,
  goalOutcome: GoalOutcome.completed,
  isDemo: false,
);

void main() {
  test('local calendar filters include Monday and exclude future and older records', () {
    final now = DateTime(2026, 11, 18, 12);
    final records = [
      record('today', now),
      record('monday', DateTime(2026, 11, 16)),
      record('sunday', DateTime(2026, 11, 15, 23, 59)),
      record('lastMonth', DateTime(2026, 10, 31)),
      record('future', DateTime(2026, 11, 19)),
    ];
    expect(
      filterProgressRecords(
        records,
        ProgressPeriod.day,
        now,
      ).map((r) => r.recordId),
      ['today'],
    );
    expect(
      filterProgressRecords(
        records,
        ProgressPeriod.week,
        now,
      ).map((r) => r.recordId),
      ['today', 'monday'],
    );
    expect(filterProgressRecords(records, ProgressPeriod.month, now).length, 3);
    expect(
      filterProgressRecords(records, ProgressPeriod.allTime, now).length,
      5,
    );
  });

  testWidgets(
    'large-text dashboard keeps chart values accessible and filters actionable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ProgressPeriod? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ProgressPeriodControl(
                        value: ProgressPeriod.allTime,
                        onChanged: (value) => selected = value,
                      ),
                      ProgressActivity(
                        records: [record('one', DateTime(2026, 11, 18))],
                        period: ProgressPeriod.allTime,
                        now: DateTime(2026, 11, 18),
                        hasMore: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Week'));
      expect(selected, ProgressPeriod.week);
      expect(find.textContaining('Loaded records only'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('progress-goals-completed')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('progress-goals-completed')),
        findsOneWidget,
      );
      expect(find.text('1m 0s'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
