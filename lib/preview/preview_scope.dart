import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app/app_mode.dart';
import '../core/models/community_models.dart';
import '../features/communities/presentation/controllers/community_providers.dart';
import '../features/rooms/data/room_providers.dart';
import 'preview_repositories.dart';
import 'progress_history_fixtures.dart';
import '../features/progress/presentation/controllers/progress_history_controller.dart';
import 'room_scene_fixtures.dart';
import '../features/rooms/presentation/controllers/room_scene_provider.dart';

final previewScenarioProvider =
    NotifierProvider<PreviewScenarioController, PreviewScenario>(
      PreviewScenarioController.new,
    );

class PreviewScenarioController extends Notifier<PreviewScenario> {
  @override
  PreviewScenario build() => PreviewScenario.sample;
  void select(PreviewScenario value) => state = value;
}

// The only runtime composition point for fake feature services.
class PreviewScope extends StatelessWidget {
  const PreviewScope({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      appModeProvider.overrideWithValue(AppMode.preview),
      progressHistoryRepositoryProvider.overrideWith((ref) {
        final scenario = ref.watch(previewScenarioProvider);
        return ProgressHistoryFixtureRepository(
          scenario: switch (scenario) {
            PreviewScenario.sample => ProgressHistoryScenario.sample,
            PreviewScenario.empty => ProgressHistoryScenario.empty,
            PreviewScenario.loading => ProgressHistoryScenario.loading,
            PreviewScenario.errorOnce => ProgressHistoryScenario.errorOnce,
          },
        );
      }),
      roomSceneSeatsProvider.overrideWith((ref, roomId) {
        ref.watch(
          roomRepositoryProvider,
        ); // Reset scene drafts with the scenario.
        return roomSceneFixtures(roomId);
      }),
      communityRepositoryProvider.overrideWith(
        (ref) => MemoryCommunityRepository(
          scenario: ref.watch(previewScenarioProvider),
        ),
      ),
      roomRepositoryProvider.overrideWith((ref) {
        final communityRepository = ref.watch(communityRepositoryProvider);
        return MemoryRoomRepository(
          scenario: ref.watch(previewScenarioProvider),
          isSubgroupActive: (subgroupId) async {
            final subgroup = (await communityRepository.loadCatalog()).subgroup(
              subgroupId,
            );
            return subgroup?.status == SubgroupStatus.active;
          },
        );
      }),
    ],
    child: child,
  );
}
