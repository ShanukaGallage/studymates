import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../../../../preview/session_preview_screen.dart';
import '../controllers/room_scene_provider.dart';
import '../widgets/room_lobby_preview.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../communities/presentation/widgets/catalog_view.dart';
import '../../data/room_providers.dart';

class RoomPreviewScreen extends ConsumerWidget {
  const RoomPreviewScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      ref
          .watch(roomSummaryProvider(id))
          .when(
            skipLoadingOnRefresh: false,
            loading: () => const LoadingView(message: 'Loading room…'),
            error: (error, stack) => ErrorView(
              message: 'Room is unavailable. Try again.',
              onRetry: () => ref.invalidate(roomSummaryProvider(id)),
            ),
            data: (room) => room == null
                ? const MissingPreviewItem()
                : CatalogView(
                    builder: (catalog) {
                      final subgroup = catalog.subgroup(room.subgroupId);
                      if (subgroup == null) return const MissingPreviewItem();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextButton(
                            onPressed: () => context.canPop()
                                ? context.pop()
                                : context.goNamed(
                                    'subgroup-detail',
                                    pathParameters: {'subgroupId': subgroup.id},
                                  ),
                            child: Text('Back to ${subgroup.name}'),
                          ),
                          Text(
                            room.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            subgroup.membership == MembershipState.joined
                                ? 'Subgroup joined in preview. You have not entered or reserved a seat.'
                                : 'Subgroup membership is required for future room admission.',
                          ),
                          const SizedBox(height: 16),
                          RoomLobbyPreview(
                            key: ObjectKey(
                              ref.watch(roomSceneSeatsProvider(id)),
                            ),
                            room: room,
                            seats: ref.watch(roomSceneSeatsProvider(id)),
                            onStart: (seat, goal) async {
                              final showProgress =
                                  await Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => SessionPreviewScreen(
                                        roomTitle: room.title,
                                        seat: seat,
                                        goal: goal,
                                      ),
                                    ),
                                  );
                              if (context.mounted && showProgress == true) {
                                context.go('/progress');
                              }
                            },
                            isMember:
                                subgroup.membership == MembershipState.joined,
                            onLeave: () => context.canPop()
                                ? context.pop()
                                : context.goNamed(
                                    'subgroup-detail',
                                    pathParameters: {'subgroupId': subgroup.id},
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
    ],
  );
}
