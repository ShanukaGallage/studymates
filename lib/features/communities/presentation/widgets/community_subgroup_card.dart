import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_mode.dart';
import '../../../../core/models/community_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/community_providers.dart';
import 'catalog_view.dart';
import 'community_management_dialogs.dart';
import 'subgroup_study_rooms.dart';

class JoinedBadge extends StatelessWidget {
  const JoinedBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.mintAccent,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check, size: 18, color: Color(0xFF225B3B)),
        SizedBox(width: 4),
        Flexible(
          child: Text('Joined', style: TextStyle(color: Color(0xFF225B3B))),
        ),
      ],
    ),
  );
}

class CommunitySubgroupCard extends ConsumerWidget {
  const CommunitySubgroupCard({
    super.key,
    required this.group,
    required this.community,
    required this.isOwner,
    required this.expanded,
    required this.onToggle,
  });
  final SubgroupSummary group;
  final SigSummary community;
  final bool isOwner, expanded;
  final VoidCallback onToggle;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await confirmSubgroupDeletion(context, group.name) ||
        !context.mounted) {
      return;
    }
    try {
      await ref
          .read(communityCatalogProvider.notifier)
          .deleteSubgroup(sigId: community.id, subgroupId: group.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subgroup could not be deleted. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentJoined = community.membership == MembershipState.joined;
    final joined = group.membership == MembershipState.joined;
    final preview = ref.watch(appModeProvider) == AppMode.preview;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.primary.withValues(alpha: .22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: expanded,
            child: InkWell(
              key: ValueKey('subgroup-toggle-${group.id}'),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (MediaQuery.textScalerOf(context).scale(16) > 22) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.people_outline,
                                color: AppColors.primary,
                                size: 28,
                              ),
                              const Spacer(),
                              Icon(
                                expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: AppColors.text,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            group.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (joined) ...[
                            const SizedBox(height: 8),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: JoinedBadge(),
                            ),
                          ],
                        ],
                      );
                    }
                    final stacked = constraints.maxWidth < 300;
                    return Row(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (stacked && joined) ...[
                                const SizedBox(height: 8),
                                const JoinedBadge(),
                              ],
                            ],
                          ),
                        ),
                        if (!stacked && joined) ...[
                          const SizedBox(width: 8),
                          const JoinedBadge(),
                        ],
                        const SizedBox(width: 8),
                        Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.text,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (group.description.trim().isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(group.description),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!parentJoined) ...[
                    Text('Join ${community.name} first to join this subgroup.'),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: .18),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SubgroupStudyRooms(
                      key: ValueKey('subgroup-rooms-${group.id}'),
                      subgroupId: group.id,
                      canCreate: parentJoined && joined,
                    ),
                  ),
                  if (parentJoined) ...[
                    const SizedBox(height: 12),
                    MembershipAction(
                      key: ValueKey('membership-${group.id}'),
                      subject: 'subgroup',
                      joined: joined,
                      leaveMessage: preview ? null : 'Leaving ends your participation and releases your seat. Hosting passes to the longest-seated eligible learner; an empty hosted room closes.',
                      onChange: (value) => ref
                          .read(communityCatalogProvider.notifier)
                          .setSubgroupMembership(group.id, value),
                    ),
                  ],
                  if (isOwner) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => showEditSubgroupDialog(
                            context,
                            sigId: community.id,
                            subgroup: group,
                          ),
                          child: Text('Edit ${group.name}'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => _delete(context, ref),
                          child: Text('Delete ${group.name}'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
