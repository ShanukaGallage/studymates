import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/app/firebase_startup.dart';
import 'package:studymates/app/startup_splash.dart';
import 'package:studymates/core/theme/app_theme.dart';

void main() {
  testWidgets(
    'startup shows branding while pending, then offers retry on failure',
    (tester) async {
      var attempts = 0;
      final gate = Completer<void>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firebaseBootstrapProvider.overrideWith((ref) {
              attempts++;
              return gate.future;
            }),
          ],
          child: const FirebaseStartup(),
        ),
      );
      expect(find.byType(StartupSplash), findsOneWidget);
      expect(find.text('StudyMates'), findsOneWidget);
      gate.completeError(StateError('offline'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(StartupSplash), findsNothing);
      expect(
        find.text('StudyMates could not connect to its account services.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(attempts, 2);
    },
  );

  testWidgets(
    'splash scrolls on narrow and landscape screens with large text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final size in [const Size(320, 568), const Size(568, 320)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const StartupSplash(),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.text('Getting your study space ready…'),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
