import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_mode.dart';
import '../../../../core/models/community_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/state_views.dart';
import '../controllers/community_providers.dart';
import '../widgets/catalog_view.dart';
import '../widgets/community_management_dialogs.dart';
import '../widgets/community_subgroup_card.dart';

class SigDetailScreen extends ConsumerStatefulWidget {
  const SigDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<SigDetailScreen> createState() => _SigDetailScreenState();
}

class _SigDetailScreenState extends ConsumerState<SigDetailScreen> {
  final _scroll = ScrollController();
  String? _expandedSubgroup;

  @override
  void didUpdateWidget(covariant SigDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _expandedSubgroup = null;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CatalogView(
    builder: (catalog) {
      final sig = catalog.sig(widget.id);
      if (sig == null) {
        return const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: MissingPreviewItem(),
        );
      }
      final joined = sig.membership == MembershipState.joined;
      final owner = sig.ownerId == catalog.profile.id;
      final groups = catalog.activeSubgroups
          .where((group) => group.sigId == sig.id)
          .toList();
      final preview = ref.watch(appModeProvider) == AppMode.preview;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            key: PageStorageKey('community-${catalog.profile.id}-${sig.id}'),
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.builder(
                  itemCount: 3 + (groups.isEmpty ? 1 : groups.length),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  key: const ValueKey(
                                    'community-back-discover',
                                  ),
                                  onPressed: () => context.go('/discover'),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Discover'),
                                ),
                              ),
                            ),
                            if (joined)
                              MembershipAction(
                                key: ValueKey('community-menu-${sig.id}'),
                                subject: 'community',
                                joined: true,
                                inMenu: true,
                                leaveMessage: preview
                                    ? 'Leaving this SIG also clears its subgroup memberships in this preview.'
                                    : 'Leaving ends your related participation and releases your seat. Hosting passes to the longest-seated eligible learner; an empty hosted room closes. Other learners can save their own participation.',
                                onChange: (value) => ref
                                    .read(communityCatalogProvider.notifier)
                                    .setSigMembership(sig.id, value),
                              ),
                          ],
                        ),
                      );
                    }
                    if (index == 1) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppColors.softAccent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.people_outline,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            sig.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall,
                                          ),
                                          if (joined) const JoinedBadge(),
                                        ],
                                      ),
                                      if (sig.description
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(sig.description),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (!joined) ...[
                              const SizedBox(height: 16),
                              MembershipAction(
                                key: ValueKey('join-community-${sig.id}'),
                                subject: 'community',
                                joined: false,
                                onChange: (value) => ref
                                    .read(communityCatalogProvider.notifier)
                                    .setSigMembership(sig.id, value),
                              ),
                            ],
                          ],
                        ),
                      );
                    }
                    if (index == 2) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Subgroups',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Container(
                                  key: const ValueKey(
                                    'community-subgroup-count',
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.softAccent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${groups.length}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            if (owner)
                              TextButton.icon(
                                onPressed: () => showCreateSubgroupDialog(
                                  context,
                                  sigId: sig.id,
                                ),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Create subgroup'),
                              ),
                          ],
                        ),
                      );
                    }
                    if (groups.isEmpty) {
                      return EmptyView(
                        title: 'No subgroups yet',
                        message: owner
                            ? 'Create a subgroup for members to explore.'
                            : 'The community owner has not added any subgroups yet.',
                      );
                    }
                    final group = groups[index - 3];
                    return Padding(
                      key: ValueKey(group.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CommunitySubgroupCard(
                        group: group,
                        community: sig,
                        isOwner: owner,
                        expanded: _expandedSubgroup == group.id,
                        onToggle: () => setState(
                          () => _expandedSubgroup =
                              _expandedSubgroup == group.id ? null : group.id,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
