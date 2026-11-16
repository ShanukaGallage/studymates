import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/preview/session_preview_screen.dart';

void main() {
  Future<void> open(WidgetTester tester, DateTime Function() clock) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SessionPreviewScreen(
                    roomTitle: 'First Sensor Project',
                    seat: 4,
                    goal: 'Build a sensor',
                    now: clock,
                  ),
                ),
              ),
              child: const Text('Open session'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open session'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'UTC boundaries drive focus, break and completion; goal is independent',
    (tester) async {
      var now = DateTime.utc(2026, 11, 16);
      await open(tester, () => now);
      expect(find.text('Time to focus'), findsOneWidget);
      now = now.add(const Duration(seconds: 46));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Take a short break'), findsOneWidget);
      expect(find.text('00:14'), findsOneWidget);
      now = now.add(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Cycle complete'), findsOneWidget);
      await tester.ensureVisible(find.text('Review preview summary'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review preview summary'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Cycle completed'), findsOneWidget);
      expect(find.text('Goal unfinished'), findsOneWidget);
      expect(find.text('Elapsed preview time: 01:00'), findsOneWidget);
      await tester.tap(find.text('Return to room'));
      await tester.pumpAndSettle();
      expect(find.text('Open session'), findsOneWidget);
    },
  );

  testWidgets(
    'back confirms, failure retries and summary preserves early duration',
    (tester) async {
      var now = DateTime.utc(2026, 11, 16);
      await open(tester, () => now);
      now = now.add(const Duration(seconds: 12));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('End preview session?'), findsOneWidget);
      await tester.tap(find.text('Keep studying'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End preview'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Session preview controls'),
        180,
      );
      await tester.tap(find.text('Session preview controls'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Fail next summary attempt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fail next summary attempt'));
      await tester.ensureVisible(find.text('Review preview summary'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review preview summary'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('Simulated save failed.'), findsOneWidget);
      now = now.add(const Duration(minutes: 5));
      await tester.ensureVisible(find.text('Retry preview summary'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry preview summary'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Ended early'), findsOneWidget);
      expect(find.text('Elapsed preview time: 00:12'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reconnecting blocks review; restoring allows summary and Progress result',
    (tester) async {
      var now = DateTime.utc(2026);
      await open(tester, () => now);
      await tester.scrollUntilVisible(
        find.text('Session preview controls'),
        180,
      );
      await tester.tap(find.text('Session preview controls'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Simulate connection interruption'),
        100,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate connection interruption'));
      now = now.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.text('Review preview summary'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Review preview summary'),
            )
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.text('Simulate connection interruption'),
        100,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate connection interruption'));
      await tester.ensureVisible(find.text('I completed my goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I completed my goal'));
      await tester.ensureVisible(find.text('Review preview summary'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review preview summary'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Goal completed'), findsOneWidget);
      await tester.ensureVisible(find.text('View sample Progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View sample Progress'));
      await tester.pumpAndSettle();
      expect(find.text('Open session'), findsOneWidget);
    },
  );

  testWidgets('narrow large-text session scrolls and disposes safely', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, () => DateTime.utc(2026));
    await tester.scrollUntilVisible(find.text('Session preview controls'), 180);
    await tester.tap(find.text('Session preview controls'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simulate seat unavailable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simulate seat unavailable'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Simulated seat unavailable.'),
      -180,
    );
    expect(find.textContaining('Simulated seat unavailable.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
