import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/features/progress/presentation/widgets/progress_status_view.dart';
import 'package:studymates/preview/progress_states_preview.dart';

void main() {
  Future<void> show(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(child: ListView(children: [child])),
      ),
    ),
  );

  testWidgets(
    'loading and failed reads never imply an empty history or totals',
    (tester) async {
      await show(tester, const ProgressStatusView.loading());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No recorded sessions yet'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      await show(tester, ProgressStatusView.error(onRetry: () {}));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No recorded sessions yet'), findsNothing);
      expect(find.textContaining('0 sessions'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('retry delegates once without fabricating a successful read', (
    tester,
  ) async {
    var attempts = 0;
    await show(tester, ProgressStatusView.error(onRetry: () => attempts++));
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(attempts, 1);
    expect(
      find.text('Could not load your history. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('No recorded sessions yet'), findsNothing);
  });

  testWidgets(
    'preview states scroll on narrow screens with large text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      for (final child in [
        const ProgressStatusView.loading(),
        const ProgressStatusView.empty(),
        ProgressStatusView.error(onRetry: () {}),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, page) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: page!,
            ),
            home: Scaffold(
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [child],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'standalone preview labels simulated retry and allows empty recovery',
    (tester) async {
      await tester.pumpWidget(const ProgressStatesPreview());
      await tester.tap(find.text('Show error'));
      await tester.pump();
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(
        find.textContaining('no network request was made'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.ensureVisible(find.text('Show empty'));
      await tester.tap(find.text('Show empty'));
      await tester.pump();
      expect(find.text('No recorded sessions yet'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}
