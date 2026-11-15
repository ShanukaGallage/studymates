import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/widgets/app_button.dart';
import '../features/communities/presentation/controllers/community_providers.dart';
import '../features/rooms/data/room_providers.dart';
import 'preview_repositories.dart';
import 'preview_scope.dart';

class PreviewDataScreen extends ConsumerWidget {
  const PreviewDataScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Preview data'),
      leading: IconButton(
        tooltip: 'Back to preview',
        icon: const Icon(Icons.arrow_back),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/discover'),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Development controls. Switching scenarios resets local memberships. Nothing is saved after app restart.',
          ),
          const SizedBox(height: 24),
          for (final entry in const [
            (
              PreviewScenario.sample,
              'Sample data',
              'IoT / ESP32, Programming / Flutter, empty and full rooms.',
            ),
            (PreviewScenario.empty, 'Empty data', 'No communities or rooms.'),
            (
              PreviewScenario.loading,
              'Loading',
              'Stay loading until another scenario is selected here.',
            ),
            (
              PreviewScenario.errorOnce,
              'Error once',
              'Each repository fails its first read. Retry recovers.',
            ),
          ])
            ListTile(
              title: Text(entry.$2),
              subtitle: Text(entry.$3),
              leading: Icon(
                ref.watch(previewScenarioProvider) == entry.$1
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              selected: ref.watch(previewScenarioProvider) == entry.$1,
              onTap: () =>
                  ref.read(previewScenarioProvider.notifier).select(entry.$1),
            ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Reset current scenario',
            variant: AppButtonVariant.secondary,
            onPressed: () {
              ref.invalidate(communityRepositoryProvider);
              ref.invalidate(roomRepositoryProvider);
            },
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Open Discover',
            onPressed: () => context.go('/discover'),
          ),
        ],
      ),
    ),
  );
}
