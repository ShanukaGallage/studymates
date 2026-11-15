import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../controllers/scanner_capture.dart';

/// Isolated capture UI. The owner must register [routeObserver] on the Navigator
/// displaying this screen so covering routes stop the camera.
class InviteScannerScreen extends StatefulWidget {
  const InviteScannerScreen({
    super.key,
    required this.onResult,
    required this.onCancel,
    required this.routeObserver,
  });

  final ValueChanged<String> onResult;
  final VoidCallback onCancel;
  final RouteObserver<ModalRoute<dynamic>> routeObserver;

  @override
  State<InviteScannerScreen> createState() => _InviteScannerScreenState();
}

class _InviteScannerScreenState extends State<InviteScannerScreen>
    with WidgetsBindingObserver, RouteAware {
  final _camera = MobileScannerController(
    // Let MobileScanner finish its debug hot-restart cleanup before first start.
    // Subsequent starts/stops are reconciled below.
    autoStart: true,
    formats: const [BarcodeFormat.qrCode],
  );
  final _capture = ScannerCapture();
  final _text = TextEditingController();
  final _form = GlobalKey<FormState>();
  Future<void> _cameraWork = Future<void>.value();
  ModalRoute<dynamic>? _route;
  bool _visible = true;
  bool _resumed = true;
  bool _manual = false;
  bool _cancelled = false;
  bool _closed = false;
  bool _permissionDenied = false;
  bool _retryPlatformStop = false;
  String? _error;
  String? _captureError;

  bool get _canInteract => !_closed && _visible && _resumed && !_cancelled;
  bool get _shouldScan =>
      _canInteract && !_manual && !_capture.hasResult && !_permissionDenied;

  Future<void> _stopCamera() async {
    try {
      if (_retryPlatformStop) {
        await MobileScannerPlatform.instance.stop();
      } else {
        await _camera.stop();
      }
      _retryPlatformStop = false;
    } on Object {
      _retryPlatformStop = true;
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera.addListener(_onCameraState);
    final state = WidgetsBinding.instance.lifecycleState;
    _resumed = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCamera());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      widget.routeObserver.unsubscribe(this);
      _route = route;
      if (route != null) widget.routeObserver.subscribe(this, route);
    }
    _visible = route?.isCurrent ?? true;
  }

  @override
  void didPushNext() {
    _visible = false;
    _syncCamera();
  }

  @override
  void didPopNext() {
    _visible = true;
    _syncCamera();
  }

  @override
  void didPop() {
    _visible = false;
    _syncCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncCamera();
  }

  void _syncCamera() {
    if (_closed) return;
    final requestedStart = _shouldScan;
    // Serialize starts/stops, including permission-dialog lifecycle changes.
    _cameraWork = _cameraWork.then((_) async {
      if (_closed) return;
      try {
        if (requestedStart && _shouldScan) {
          // The widget owns the initial start (including debug cleanup).
          // Its listener reconciles visibility when that start completes.
          if (!_camera.value.isInitialized || _camera.value.isStarting) return;
          if (_retryPlatformStop) await _stopCamera();
          await _camera.start();
          final error = _camera.value.error;
          if (error != null) throw error;
          // Visibility can change while permission/start is in flight.
          if (!_shouldScan) await _stopCamera();
          if (mounted && !_closed) setState(() => _error = null);
        } else {
          await _stopCamera();
        }
        if (_closed) return;
        if (_cancelled) {
          _cancelled = false;
          _closed = true;
          widget.onCancel();
          return;
        }
        await _capture.deliver(
          stop: _stopCamera,
          canDeliver: () => _canInteract,
          onResult: (value) {
            setState(() => _error = null);
            widget.onResult(value);
          },
        );
      } on Object catch (error) {
        _showError(error);
      }
    });
  }

  void _onCameraState() {
    if (_closed || _camera.value.isStarting) return;
    final error = _camera.value.error;
    if (error != null) {
      _showError(error);
    } else if (_camera.value.isInitialized &&
        _camera.value.isRunning != _shouldScan) {
      _syncCamera();
    }
  }

  void _showError(Object error) {
    if (!mounted || _closed) return;
    final denied =
        error is MobileScannerException &&
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    if (denied) _permissionDenied = true;
    setState(() {
      _error = denied
          ? 'Camera permission was denied. Retry, or enable Camera in '
                'Android Settings > Apps > StudyMates > Permissions. '
                'You can also enter the test code manually.'
          : 'The camera is unavailable. Retry or use manual input. '
                'A captured result will only return after the camera stops.';
    });
  }

  void _accept(String? raw) {
    if (!_canInteract || _capture.hasResult) return;
    if (!_capture.accept(raw)) {
      setState(
        () => _captureError = 'No usable text found. Try another QR code.',
      );
      return;
    }
    setState(() => _captureError = null);
    FocusScope.of(context).unfocus();
    _syncCamera();
  }

  @override
  void dispose() {
    _closed = true;
    _capture.close();
    WidgetsBinding.instance.removeObserver(this);
    _camera.removeListener(_onCameraState);
    widget.routeObserver.unsubscribe(this);
    _text.dispose();
    // Release even when a permission request/start was in progress on exit.
    unawaited(
      _cameraWork
          .then((_) async {
            try {
              await _stopCamera();
            } finally {
              await _camera.dispose();
            }
          })
          .catchError((Object _) {
            debugPrint('Scanner camera release failed on exit.');
          }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Scan test QR'),
      automaticallyImplyLeading: false,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text(
            'Camera spike only — this does not join a StudyMates room.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Offstage(
            offstage: _manual || _capture.hasResult,
            child: SizedBox(
              height: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MobileScanner(
                  controller: _camera,
                  useAppLifecycleState: false,
                  onDetect: (capture) {
                    if (!_shouldScan) return;
                    for (final code in capture.barcodes) {
                      if (ScannerCapture.normalize(code.rawValue) != null) {
                        _accept(code.rawValue);
                        break;
                      }
                    }
                  },
                  onDetectError: (_, _) {
                    if (mounted && !_closed) {
                      setState(
                        () => _captureError =
                            'Could not read QR. Retry or enter it manually.',
                      );
                    }
                  },
                  errorBuilder: (_, _) => const Center(
                    child: Text('Camera unavailable. See guidance below.'),
                  ),
                ),
              ),
            ),
          ),
          if (_capture.hasResult)
            Text(
              _capture.delivered
                  ? 'Test result returned. Close and reopen for another scan.'
                  : 'Stopping camera before returning the test result…',
            ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              _error!,
              semanticsLabel: _error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            AppButton(
              label: 'Retry camera operation',
              onPressed: () {
                _permissionDenied = false;
                _syncCamera();
              },
            ),
          ],
          if (_captureError != null) Text(_captureError!),
          const SizedBox(height: AppSpacing.lg),
          if (!_capture.hasResult) ...[
            AppButton(
              label: _manual ? 'Use camera' : 'Enter code manually',
              variant: AppButtonVariant.secondary,
              onPressed: () {
                setState(() => _manual = !_manual);
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _syncCamera(),
                );
              },
            ),
            if (_manual)
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Test code',
                      controller: _text,
                      maxLength: ScannerCapture.maxLength,
                      validator: (value) =>
                          ScannerCapture.normalize(value) == null
                          ? 'Enter a non-empty code without control characters.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Return test code',
                      onPressed: () {
                        if (_form.currentState!.validate()) _accept(_text.text);
                      },
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
            onPressed: () {
              _cancelled = true;
              _capture.close();
              _syncCamera();
            },
          ),
        ],
      ),
    ),
  );
}
