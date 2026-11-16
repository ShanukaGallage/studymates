import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/features/sessions/presentation/widgets/keep_awake_control.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native screen-awake toggles and releases after leaving', (
    tester,
  ) async {
    await tester.runAsync(WakelockPlus.disable);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: KeepAwakeControl())),
    );
    expect(await tester.runAsync(() => WakelockPlus.enabled), isFalse);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => WakelockPlus.enabled), isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => WakelockPlus.enabled), isFalse);
  });
}
