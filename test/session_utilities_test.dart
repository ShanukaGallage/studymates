import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/features/invites/presentation/widgets/share_invitation_button.dart';
import 'package:studymates/features/sessions/presentation/widgets/keep_awake_control.dart';

void main() {
  testWidgets(
    'screen awake is opt-in and released on background and disposal',
    (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeepAwakeControl(
              setScreenAwake: (value) async => changes.add(value),
            ),
          ),
        ),
      );
      expect(changes, isEmpty);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(changes.last, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(changes.last, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(changes.last, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(changes.last, isFalse);
    },
  );

  testWidgets(
    'screen awake plugin failure leaves a retryable disabled switch',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeepAwakeControl(
              setScreenAwake: (_) async =>
                  throw PlatformException(code: 'unavailable'),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(
        find.textContaining('Could not change screen sleep'),
        findsOneWidget,
      );
    },
  );

  testWidgets('share passes the manual code and recovers from native errors', (
    tester,
  ) async {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          throw PlatformException(code: 'unavailable');
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShareInvitationButton(
            roomTitle: 'Study room',
            code: 'ABCD-EFGH-JK23-MNPQ',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share invitation'));
    await tester.pumpAndSettle();
    expect(calls.single.method, 'share');
    expect(calls.single.arguments['text'], contains('ABCD-EFGH-JK23-MNPQ'));
    expect(find.textContaining('Select and copy the code'), findsOneWidget);
    await tester.tap(find.text('Share invitation'));
    await tester.pumpAndSettle();
    expect(calls.length, 2);
  });
}
