import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/community_providers.dart';
import '../widgets/catalog_view.dart';
import '../widgets/subgroup_study_rooms.dart';

export 'sig_detail_screen.dart';
import '../../../../app/app_mode.dart';

class SubgroupDetailScreen extends ConsumerWidget {
  const SubgroupDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      CatalogView(
        builder: (catalog) {
          final group = catalog.subgroup(id);
          if (group == null) return const MissingPreviewItem();
          final sig = catalog.sig(group.sigId);
          if (sig == null) return const MissingPreviewItem();
          if (group.status == SubgroupStatus.closed) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.goNamed(
                          'sig-detail',
                          pathParameters: {'sigId': sig.id},
                        ),
                  child: Text('Back to ${sig.name}'),
                ),
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(group.description),
                const SizedBox(height: 16),
                const Text(
                  'This subgroup is closed. Its membership and history are retained.',
                ),
              ],
            );
          }
          final parentJoined = sig.membership == MembershipState.joined;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.goNamed(
                        'sig-detail',
                        pathParameters: {'sigId': sig.id},
                      ),
                child: Text('Back to ${sig.name}'),
              ),
              Text(
                group.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(group.description),
              const SizedBox(height: 16),
              if (!parentJoined)
                Text('Join ${sig.name} first to join this subgroup.'),
              if (parentJoined)
                Text(
                  group.membership == MembershipState.joined
                      ? ref.watch(appModeProvider) == AppMode.preview
                            ? 'You joined this subgroup in preview.'
                            : 'You joined this subgroup.'
                      : 'Join this topic to study together.',
                ),
              const SizedBox(height: 12),
              MembershipAction(
                key: ValueKey(id),
                subject: 'subgroup',
                leaveMessage: ref.watch(appModeProvider) == AppMode.preview
                    ? null
                    : 'Leaving ends your participation and releases your seat. Hosting passes to the longest-seated eligible learner; an empty hosted room closes.',
                enabled: parentJoined,
                joined: group.membership == MembershipState.joined,
                onChange: (value) => ref
                    .read(communityCatalogProvider.notifier)
                    .setSubgroupMembership(id, value),
              ),
              const SizedBox(height: 24),
              SubgroupStudyRooms(
                subgroupId: id,
                canCreate:
                    parentJoined && group.membership == MembershipState.joined,
              ),
            ],
          );
        },
      ),
    ],
  );
}
