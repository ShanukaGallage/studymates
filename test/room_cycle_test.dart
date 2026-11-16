import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/features/sessions/presentation/widgets/cycle_timer_card.dart';
import 'package:studymates/features/study/data/room_cycle_repository.dart';

void main() {
  final start = DateTime.utc(2026, 11, 16, 10);
  test('room cycles count once at schedule end and keep demo separate', () {
    final cycles = [
      {'startsAt': Timestamp.fromDate(start), 'isDemo': false},
      {
        'startsAt': Timestamp.fromDate(start.add(const Duration(minutes: 30))),
        'isDemo': false,
      },
      {'startsAt': Timestamp.fromDate(start), 'isDemo': true},
      {'startsAt': null, 'isDemo': false},
    ];
    expect(
      completedRoomCycles(
        cycles,
        start.add(const Duration(minutes: 29, seconds: 59)),
      ),
      0,
    );
    expect(
      completedRoomCycles(cycles, start.add(const Duration(minutes: 30))),
      1,
    );
    expect(
      completedRoomCycles(cycles, start.add(const Duration(minutes: 60))),
      2,
    );
    expect(
      completedRoomCycles(
        cycles,
        start.add(const Duration(seconds: 60)),
        demo: true,
      ),
      1,
    );
  });

  testWidgets('normal cycle displays 25 minute focus then 5 minute break', (
    tester,
  ) async {
    Future<void> show(int seconds) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: CycleTimerCard(
              startsAt: start,
              isDemo: false,
              now: start.add(Duration(seconds: seconds)),
            ),
          ),
        ),
      );
    }

    await show(0);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Focus time'), findsOneWidget);
    await show(1500);
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('Break time'), findsOneWidget);
    await show(1800);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('Cycle complete'), findsOneWidget);
  });

  testWidgets('timer fits narrow large-text screen and demo is explicit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CycleTimerCard(startsAt: start, isDemo: true, now: start),
          ),
        ),
      ),
    );
    expect(find.text('DEMO · 45s focus + 15s break'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
