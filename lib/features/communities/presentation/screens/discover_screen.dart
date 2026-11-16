import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../app/app_mode.dart';
import '../../../study/data/firestore_study_repository.dart';
import '../../../study/presentation/study_dialogs.dart';
import '../controllers/community_providers.dart';
import '../widgets/catalog_view.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});
  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _joinedOnly = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.background,
          AppColors.softAccent,
          AppColors.background,
        ],
      ),
    ),
    child: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your next study circle',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.softAccent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Find a shared interest. Take the next small step together.',
        ),
        if (ref.watch(appModeProvider) == AppMode.connected) ...[
          const SizedBox(height: 12),
          AppButton(
            label: 'Create community',
            variant: AppButtonVariant.secondary,
            onPressed: () async {
              final name = await studyTitleDialog(context, 'Create community');
              if (name == null || !context.mounted) return;
              try {
                await ref.read(studyRepositoryProvider).createCommunity(name);
                ref.invalidate(communityCatalogProvider);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Community creation failed. Check your connection and retry.',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
        const SizedBox(height: 24),
        AppTextField(
          label: 'Search communities',
          controller: _search,
          onChanged: (value) =>
              setState(() => _query = value.trim().toLowerCase()),
        ),
        if (_query.isNotEmpty)
          TextButton(
            onPressed: () {
              _search.clear();
              setState(() => _query = '');
            },
            child: const Text('Clear search'),
          ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('All communities'),
              ),
              selected: !_joinedOnly,
              onSelected: (_) => setState(() => _joinedOnly = false),
            ),
            ChoiceChip(
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('My communities'),
              ),
              selected: _joinedOnly,
              onSelected: (_) => setState(() => _joinedOnly = true),
            ),
          ],
        ),
        const SizedBox(height: 20),
        CatalogView(
          builder: (catalog) {
            final matches = catalog.sigs
                .where(
                  (sig) =>
                      (!_joinedOnly ||
                          sig.membership == MembershipState.joined) &&
                      '${sig.name} ${sig.category} ${sig.description}'
                          .toLowerCase()
                          .contains(_query),
                )
                .toList();
            if (catalog.sigs.isEmpty) {
              return EmptyView(
                title: 'No communities yet',
                message: ref.watch(appModeProvider) == AppMode.preview
                    ? 'Choose Sample data in Preview data to restore the examples.'
                    : 'Create a community, or ask a study mate for an invitation.',
              );
            }
            if (matches.isEmpty) {
              return EmptyView(
                title: _joinedOnly && _query.isEmpty
                    ? 'Your study circle starts here'
                    : 'No matches',
                message: _joinedOnly && _query.isEmpty
                    ? 'Choose All communities to find a group and join from its details.'
                    : 'Try another interest or clear your search.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Browsing as ${catalog.profile.displayName}'),
                const SizedBox(height: 16),
                Text(
                  '${matches.length} ${matches.length == 1 ? 'community' : 'communities'}${_joinedOnly ? ' joined' : ' to explore'}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns =
                        constraints.maxWidth >= 340 &&
                        MediaQuery.textScalerOf(context).scale(16) <= 24;
                    final width = twoColumns
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final sig in matches)
                          SizedBox(
                            width: width,
                            child: _CommunityTile(
                              sig: sig,
                              preview:
                                  ref.watch(appModeProvider) == AppMode.preview,
                              subgroupCount: catalog.subgroups
                                  .where((group) => group.sigId == sig.id)
                                  .length,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _CommunityTile extends StatelessWidget {
  const _CommunityTile({
    required this.sig,
    required this.subgroupCount,
    required this.preview,
  });
  final SigSummary sig;
  final int subgroupCount;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final joined = sig.membership == MembershipState.joined;
    final tint = joined ? AppColors.mintAccent : AppColors.softAccent;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              joined ? Icons.groups_outlined : Icons.auto_stories_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(sig.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Tag(label: sig.category, color: AppColors.blueAccent),
              _Tag(
                label: joined
                    ? (preview ? 'Joined • Preview' : 'Joined')
                    : 'Not joined',
                color: tint,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(sig.description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Text(
            '$subgroupCount ${subgroupCount == 1 ? 'subgroup' : 'subgroups'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Explore ${sig.name}',
              variant: AppButtonVariant.secondary,
              onPressed: () => context.pushNamed(
                'sig-detail',
                pathParameters: {'sigId': sig.id},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: Theme.of(context).textTheme.bodySmall),
  );
}
