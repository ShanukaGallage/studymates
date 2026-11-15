import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/app_button.dart';
import '../features/invites/presentation/screens/invite_scanner_screen.dart';

/// Independent development entry point; no production router or backend wiring.
void main() => runApp(const InvitesScannerSpike());

class InvitesScannerSpike extends StatefulWidget {
  const InvitesScannerSpike({super.key});

  @override
  State<InvitesScannerSpike> createState() => _InvitesScannerSpikeState();
}

class _InvitesScannerSpikeState extends State<InvitesScannerSpike> {
  final _observer = RouteObserver<ModalRoute<dynamic>>();
  String? _result;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    navigatorObservers: [_observer],
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Scanner spike only')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const Text(
                'Standalone camera test. No invitation lookup or room join.',
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Open scanner',
                onPressed: () async {
                  final result = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (scanContext) => Stack(
                        children: [
                          InviteScannerScreen(
                            routeObserver: _observer,
                            onResult: (value) =>
                                Navigator.of(scanContext).pop(value),
                            onCancel: () => Navigator.of(scanContext).pop(),
                          ),
                          Positioned(
                            top: 0,
                            right: 8,
                            child: SafeArea(
                              child: IconButton(
                                tooltip: 'Cover scanner for lifecycle test',
                                icon: const Icon(Icons.layers_outlined),
                                onPressed: () => showDialog<void>(
                                  context: scanContext,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Scanner covered'),
                                    content: const Text(
                                      'The camera should be stopped while this dialog is open.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(),
                                        child: const Text('Return to scanner'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (mounted) setState(() => _result = result);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_result != null) ...[
                const Text('Test callback returned once:'),
                SelectableText(_result!),
              ] else
                const Text('No test result returned.'),
              const SizedBox(height: AppSpacing.lg),
              const Text('Known QR payload: STUDYMATES_CAMERA_SPIKE_ONLY'),
            ],
          ),
        ),
      ),
    ),
  );
}
