import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/core/models/completion_record.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/features/progress/presentation/widgets/study_year_heatmap.dart';

CompletionRecord entry(
  String id,
  DateTime date,
  int seconds, {
  bool demo = false,
}) => CompletionRecord(
  recordId: id,
  userId: 'u',
  sessionId: id,
  goalText: 'Read',
  endedAt: date,
  creditedSeconds: seconds,
  timerStatus: TimerCompletionStatus.endedEarly,
  goalOutcome: GoalOutcome.unfinished,
  isDemo: demo,
);

void main() {
  test('daily aggregation retains early time, deduplicates and handles leap day and year boundaries', () {
    final a = entry('a', DateTime(2024, 2, 29, 10), 1800);
    final totals = studySecondsByDay([
      a,
      a,
      entry('b', DateTime(2024, 2, 29, 23, 59), 600),
      entry('c', DateTime(2023, 12, 31), 100),
      entry('d', DateTime(2025), 100),
    ], 2024);
    expect(totals, {DateTime(2024, 2, 29): 2400});
    expect([0, 1, 1799, 1800, 7199, 7200, 14399, 14400].map(studyIntensity), [
      0,
      1,
      1,
      2,
      2,
      3,
      3,
      4,
    ]);
  });

  testWidgets(
    'year navigation, partial coverage and day inspection work at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: StudyYearHeatmap(
                  records: [
                    entry('normal', DateTime(2024, 2, 29), 3600),
                    entry('demo', DateTime(2024, 2, 29), 7200, demo: true),
                  ],
                  hasMore: true,
                  now: DateTime(2024, 3, 1),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('1 active days · 1h 0m 0s'), findsOneWidget);
      expect(find.textContaining('Partial year'), findsOneWidget);
      await tester.ensureVisible(find.text('Inspect a study day'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inspect a study day'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Previous study year'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous study year'));
      await tester.pumpAndSettle();
      expect(find.text('2023'), findsOneWidget);
      expect(find.textContaining('0 active days'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
