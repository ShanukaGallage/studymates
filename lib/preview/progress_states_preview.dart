import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/app_button.dart';
import '../features/progress/presentation/widgets/progress_status_view.dart';

/// Isolated development entry point, without repository or global route changes.
void main() => runApp(const ProgressStatesPreview());

enum _Scenario { loading, empty, error }

class ProgressStatesPreview extends StatefulWidget {
  const ProgressStatesPreview({super.key});

  @override
  State<ProgressStatesPreview> createState() => _ProgressStatesPreviewState();
}

class _ProgressStatesPreviewState extends State<ProgressStatesPreview> {
  _Scenario _scenario = _Scenario.loading;
  bool _retried = false;

  void _select(_Scenario scenario) => setState(() {
    _scenario = scenario;
    _retried = false;
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      appBar: AppBar(title: const Text('Progress states preview')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text(
              'UI preview only. These states are selected manually; '
              'no account or history service is connected.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final scenario in _Scenario.values)
                  AppButton(
                    label: switch (scenario) {
                      _Scenario.loading => 'Show loading',
                      _Scenario.empty => 'Show empty',
                      _Scenario.error => 'Show error',
                    },
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _select(scenario),
                  ),
              ],
            ),
            if (_retried) ...[
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Preview Retry callback received. Select Show empty to inspect '
                'recovery; no network request was made.',
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            switch (_scenario) {
              _Scenario.loading => const ProgressStatusView.loading(),
              _Scenario.empty => const ProgressStatusView.empty(),
              _Scenario.error => ProgressStatusView.error(
                onRetry: () => setState(() {
                  _retried = true;
                  _scenario = _Scenario.loading;
                }),
              ),
            },
          ],
        ),
      ),
    ),
  );
}
