import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/core/widgets/app_details.dart';
import 'package:studymates/features/progress/presentation/controllers/progress_history_controller.dart';
import 'package:studymates/features/progress/presentation/screens/progress_history_screen.dart';
import 'package:studymates/features/study/data/study_providers.dart';
import 'package:studymates/features/study/presentation/seat_recovery_card.dart';
import 'package:studymates/features/sessions/data/active_session_providers.dart';
import 'package:studymates/preview/progress_history_fixtures.dart';

void main() {
  testWidgets(
    'details are hidden initially and stay accessible with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
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
          home: const Scaffold(
            body: AppContentWidth(
              child: SingleChildScrollView(
                child: AppDetails(
                  title: 'Room options',
                  children: [
                    Text('Extra room guidance'),
                    TextButton(onPressed: null, child: Text('Example action')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Extra room guidance'), findsNothing);
      await tester.tap(find.text('Room options'));
      await tester.pumpAndSettle();
      expect(find.text('Extra room guidance'), findsOneWidget);
      expect(find.text('Example action'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Room options'));
      await tester.pumpAndSettle();
      expect(find.text('Extra room guidance'), findsNothing);
    },
  );

  testWidgets('normal own seat does not display a blocking recovery warning', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ownSeatClaimProvider.overrideWith(
            (ref) =>
                Stream.value({'roomId': 'current-room', 'seatId': 'seat-2'}),
          ),
          currentUserActiveSessionProvider.overrideWith(
            (ref) => const AsyncData(null),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SeatRecoveryCard(roomId: 'current-room')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('You’re seated in another room'), findsNothing);
    expect(find.text('Release reserved seat'), findsNothing);
  });

  testWidgets(
    'progress keeps totals visible and session identifiers behind details',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressHistoryRepositoryProvider.overrideWithValue(
              ProgressHistoryFixtureRepository(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: ProgressHistoryScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('progress-total-time')), findsOneWidget);
      expect(find.text('Eligible recorded time: 1h 5m'), findsNothing);
      expect(find.textContaining('Session: '), findsNothing);
      final row = find.byKey(
        const ValueKey('progress-record-completion-user-1-session-1'),
      );
      if (row.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          row,
          200,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.textContaining('Session: '), findsOneWidget);
    },
  );
}
