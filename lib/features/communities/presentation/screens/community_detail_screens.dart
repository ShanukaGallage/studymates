import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../rooms/data/room_providers.dart';
import '../controllers/community_providers.dart';
import '../widgets/community_management_dialogs.dart';
import '../widgets/catalog_view.dart';

class SigDetailScreen extends ConsumerWidget {
  const SigDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      CatalogView(
        builder: (catalog) {
          final sig = catalog.sig(id);
          if (sig == null) return const MissingPreviewItem();
          final isOwner = sig.ownerId == catalog.profile.id;
          final groups = catalog.activeSubgroups.where(
            (group) => group.sigId == id,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/discover'),
                child: const Text('Back to Discover'),
              ),
              Text(sig.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(sig.description),
              const SizedBox(height: 16),
              Text(
                sig.membership == MembershipState.joined
                    ? 'You joined this SIG in preview.'
                    : 'Join this SIG to join its subgroups.',
              ),
              const SizedBox(height: 12),
              MembershipAction(
                key: ValueKey(id),
                subject: 'SIG',
                joined: sig.membership == MembershipState.joined,
                leaveMessage: 'Leaving this SIG also clears its subgroup memberships in this preview.',
                onChange: (value) => ref
                    .read(communityCatalogProvider.notifier)
                    .setSigMembership(id, value),
              ),
              const SizedBox(height: 24),
              Text('Subgroups', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (isOwner)
                AppButton(
                  label: 'Create subgroup',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => showCreateSubgroupDialog(context, sigId: id),
                ),
              if (isOwner) const SizedBox(height: 16),
              if (groups.isEmpty)
                EmptyView(
                  title: 'No subgroups yet',
                  message: isOwner
                      ? 'Create a subgroup for members to explore.'
                      : 'The SIG owner has not added any subgroups yet.',
                ),
              for (final group in groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(group.description),
                        const SizedBox(height: 8),
                        Text(
                          group.membership == MembershipState.joined
                              ? 'Joined • Preview'
                              : 'Not joined',
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Open ${group.name}',
                          variant: AppButtonVariant.secondary,
                          onPressed: () => context.pushNamed(
                            'subgroup-detail',
                            pathParameters: {'subgroupId': group.id},
                          ),
                        ),
                        if (isOwner) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              AppButton(
                                label: 'Edit ${group.name}',
                                variant: AppButtonVariant.secondary,
                                onPressed: () => showEditSubgroupDialog(
                                  context,
                                  sigId: id,
                                  subgroup: group,
                                ),
                              ),
                              AppButton(
                                label: 'Delete ${group.name}',
                                variant: AppButtonVariant.secondary,
                                onPressed: () async {
                                  if (!await confirmSubgroupDeletion(
                                    context,
                                    group.name,
                                  )) {
                                    return;
                                  }
                                  try {
                                    await ref
                                        .read(communityCatalogProvider.notifier)
                                        .deleteSubgroup(
                                          sigId: id,
                                          subgroupId: group.id,
                                        );
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Subgroup could not be deleted. Try again.',
                                              ),
                                            ),
                                          );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

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
                      ? 'You joined this subgroup in preview.'
                      : 'Join this topic to study together.',
                ),
              const SizedBox(height: 12),
              MembershipAction(
                key: ValueKey(id),
                subject: 'subgroup',
                enabled: parentJoined,
                joined: group.membership == MembershipState.joined,
                onChange: (value) => ref
                    .read(communityCatalogProvider.notifier)
                    .setSubgroupMembership(id, value),
              ),
              const SizedBox(height: 24),
              Text(
                'Study rooms',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sample occupancy only. Opening a preview does not reserve a seat.',
              ),
              const SizedBox(height: 16),
              ref
                  .watch(subgroupRoomsProvider(id))
                  .when(
                    skipLoadingOnRefresh: false,
                    loading: () => const LoadingView(message: 'Loading rooms…'),
                    error: (error, stack) => ErrorView(
                      message: 'Rooms are unavailable. Try again.',
                      onRetry: () => ref.invalidate(subgroupRoomsProvider(id)),
                    ),
                    data: (rooms) => rooms.isEmpty
                        ? const EmptyView(
                            title: 'No rooms yet',
                            message:
                                'Room creation will come in a later milestone.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final room in rooms)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: AppCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          room.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          room.isFull
                                              ? 'Full • ${room.capacity} of ${room.capacity} seats'
                                              : '${room.occupiedSeats} of ${room.capacity} seats occupied',
                                        ),
                                        const SizedBox(height: 12),
                                        AppButton(
                                          label: 'Preview ${room.title}',
                                          variant: AppButtonVariant.secondary,
                                          onPressed: () => context.pushNamed(
                                            'room-preview',
                                            pathParameters: {'roomId': room.id},
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
            ],
          );
        },
      ),
    ],
  );
}
