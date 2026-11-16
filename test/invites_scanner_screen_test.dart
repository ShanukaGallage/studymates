import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/app/app.dart';
import 'package:studymates/preview/preview_scope.dart';
import 'package:studymates/features/invites/presentation/screens/invite_scanner_screen.dart';
import 'package:studymates/preview/invites_scanner_spike.dart';

class _Camera extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  int starts = 0;
  int stops = 0;
  bool denied = false;
  bool running = false;
  bool failStop = false;
  Completer<void>? startGate;

  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox.expand();
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    await startGate?.future;
    if (denied) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    running = true;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {
    stops++;
    if (failStop) throw StateError('shutdown failed');
    running = false;
  }

  void detect(String raw) => captures.add(
    BarcodeCapture(
      barcodes: [Barcode(rawValue: raw, format: BarcodeFormat.qrCode)],
    ),
  );
}

void main() {
  late _Camera camera;
  late MobileScannerPlatform original;
  setUp(() {
    original = MobileScannerPlatform.instance;
    camera = _Camera();
    MobileScannerPlatform.instance = camera;
  });
  tearDown(() async {
    await camera.captures.close();
    MobileScannerPlatform.instance = original;
  });

  Future<void> open(
    WidgetTester tester, {
    required ValueChanged<String> onResult,
    RouteObserver<ModalRoute<dynamic>>? observer,
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    final routes = observer ?? RouteObserver<ModalRoute<dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        navigatorKey: navigatorKey,
        navigatorObservers: [routes],
        home: InviteScannerScreen(
          routeObserver: routes,
          onResult: onResult,
          onCancel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'denied camera has guidance, explicit retry and manual fallback',
    (tester) async {
      camera.denied = true;
      final results = <String>[];
      await open(tester, onResult: results.add);
      expect(
        find.textContaining('Camera permission was denied'),
        findsOneWidget,
      );
      expect(camera.starts, 1);
      await tester.tap(find.text('Enter code manually'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        ' STUDYMATES_CAMERA_SPIKE_ONLY ',
      );
      await tester.ensureVisible(find.text('Return test code'));
      await tester.tap(find.text('Return test code'));
      await tester.pumpAndSettle();
      expect(results, ['STUDYMATES_CAMERA_SPIKE_ONLY']);
      expect(camera.running, isFalse);
      await close(tester);
    },
  );

  testWidgets('repeated QR detections stop camera then invoke callback once', (
    tester,
  ) async {
    final results = <String>[];
    await open(
      tester,
      onResult: (value) {
        expect(camera.running, isFalse);
        results.add(value);
      },
    );
    camera.detect('known');
    camera.detect('known');
    await tester.pumpAndSettle();
    expect(results, ['known']);
    expect(camera.stops, greaterThanOrEqualTo(1));
    await close(tester);
  });

  testWidgets('route coverage and app lifecycle stop and restart camera', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await open(tester, onResult: (_) {}, navigatorKey: navigator);
    expect(camera.running, isTrue);
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Covered')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(camera.running, isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(camera.running, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(camera.running, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(camera.running, isTrue);
    await close(tester);
    expect(camera.running, isFalse);
  });

  testWidgets(
    'stop failure keeps callback blocked until native stop retry succeeds',
    (tester) async {
      final results = <String>[];
      await open(tester, onResult: results.add);
      camera.failStop = true;
      camera.detect('known');
      await tester.pumpAndSettle();
      expect(results, isEmpty);
      expect(camera.running, isTrue);
      camera.failStop = false;
      await tester.tap(find.text('Retry camera operation'));
      await tester.pumpAndSettle();
      expect(camera.running, isFalse);
      expect(results, ['known']);
      await close(tester);
    },
  );

  testWidgets('standalone launcher can cancel and reopen a fresh camera', (
    tester,
  ) async {
    await tester.pumpWidget(const InvitesScannerSpike());
    await tester.tap(find.text('Open scanner'));
    await tester.pumpAndSettle();
    expect(camera.running, isTrue);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(camera.running, isFalse);
    await tester.tap(find.text('Open scanner'));
    await tester.pumpAndSettle();
    expect(camera.running, isTrue);
    await close(tester);
  });

  testWidgets('covering the route during initial start releases late camera', (
    tester,
  ) async {
    camera.startGate = Completer<void>();
    final navigator = GlobalKey<NavigatorState>();
    final routes = RouteObserver<ModalRoute<dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [routes],
        home: InviteScannerScreen(
          routeObserver: routes,
          onResult: (_) {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pump();
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Covered')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    camera.startGate!.complete();
    await tester.pumpAndSettle();
    expect(camera.running, isFalse);
    await close(tester);
  });
  testWidgets(
    'app scanner route stops when covered and returns raw capture to preview',
    (tester) async {
      await tester.pumpWidget(const PreviewScope(child: StudyMatesApp()));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Scanner preview'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open scanner'));
      await tester.pumpAndSettle();
      expect(camera.running, isTrue);
      final context = tester.element(find.byType(InviteScannerScreen));
      unawaited(
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Covered scanner'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close cover'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(camera.running, isFalse);
      await tester.tap(find.text('Close cover'));
      await tester.pumpAndSettle();
      expect(camera.running, isTrue);
      camera.detect('STUDYMATES_CAMERA_SPIKE_ONLY');
      await tester.pumpAndSettle();
      expect(camera.running, isFalse);
      expect(find.text('Captured text — unverified:'), findsOneWidget);
      expect(find.text('STUDYMATES_CAMERA_SPIKE_ONLY'), findsOneWidget);
      expect(find.byType(InviteScannerScreen), findsNothing);
      await close(tester);
    },
  );
}
