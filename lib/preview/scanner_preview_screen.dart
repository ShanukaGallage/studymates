import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/widgets/app_button.dart';

class ScannerPreviewScreen extends StatefulWidget {
  const ScannerPreviewScreen({super.key});
  @override
  State<ScannerPreviewScreen> createState() => _ScannerPreviewScreenState();
}

class _ScannerPreviewScreenState extends State<ScannerPreviewScreen> {
  String? _result;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Scanner preview'),
      leading: IconButton(
        tooltip: 'Back to preview',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Camera/manual capture test only. No invitation is verified and no room is joined.',
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Open scanner',
            onPressed: () async {
              final result = await context.push<String>(
                '/preview-scanner/capture',
              );
              if (mounted && result != null) setState(() => _result = result);
            },
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            const Text('Captured text — unverified:'),
            SelectableText(_result!),
          ],
        ],
      ),
    ),
  );
}
