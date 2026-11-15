import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/app_button.dart';
import '../features/progress/presentation/controllers/progress_history_controller.dart';
import '../features/progress/presentation/screens/progress_history_screen.dart';
import 'progress_history_fixtures.dart';

void main() => runApp(const ProgressHistoryPreview());

class ProgressHistoryPreview extends StatefulWidget {
  const ProgressHistoryPreview({super.key});

  @override
  State<ProgressHistoryPreview> createState() => _ProgressHistoryPreviewState();
}

class _ProgressHistoryPreviewState extends State<ProgressHistoryPreview> {
  var _repository = ProgressHistoryFixtureRepository();
  int _revision = 0;

  @override
  Widget build(BuildContext context) => ProviderScope(
    key: ValueKey(_revision),
    overrides: [
      progressHistoryRepositoryProvider.overrideWithValue(_repository),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Progress · fixture preview'),
          actions: [
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Preview scenarios',
                icon: const Icon(Icons.tune),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Local fixtures only. No account or backend is connected.',
                          ),
                          for (final scenario in ProgressHistoryScenario.values)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                              ),
                              child: AppButton(
                                label: switch (scenario) {
                                  ProgressHistoryScenario.sample =>
                                    'Sample history',
                                  ProgressHistoryScenario.empty =>
                                    'Empty history',
                                  ProgressHistoryScenario.loading =>
                                    'Loading history',
                                  ProgressHistoryScenario.errorOnce =>
                                    'Initial error once',
                                  ProgressHistoryScenario.pageErrorOnce =>
                                    'Next-page error once',
                                  ProgressHistoryScenario.longGoal =>
                                    'Long goal history',
                                  ProgressHistoryScenario.cancelledSample =>
                                    'Cancelled sample (provisional)',
                                },
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  setState(() {
                                    _repository =
                                        ProgressHistoryFixtureRepository(
                                          scenario: scenario,
                                        );
                                    _revision++;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_repository.scenario == ProgressHistoryScenario.cancelledSample)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Provisional fixture only. Its zero credit is sample data, not an approved cancellation rule.',
                ),
              ),
            const Expanded(child: ProgressHistoryScreen()),
          ],
        ),
      ),
    ),
  );
}
