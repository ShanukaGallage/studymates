import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../widgets/community_management_dialogs.dart';
import '../widgets/catalog_view.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});
  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _search = TextEditingController();
  String _query = '';
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      Text('Discover', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Find a shared interest. Take the next small step together.'),
      const SizedBox(height: 24),
      AppTextField(
        label: 'Search communities',
        controller: _search,
        onChanged: (value) =>
            setState(() => _query = value.trim().toLowerCase()),
      ),
      const SizedBox(height: 12),
      AppButton(
        label: 'Create a SIG',
        variant: AppButtonVariant.secondary,
        onPressed: () => showCreateSigDialog(context),
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
      CatalogView(
        builder: (catalog) {
          final matches = catalog.sigs
              .where(
                (sig) => '${sig.name} ${sig.category} ${sig.description}'
                    .toLowerCase()
                    .contains(_query),
              )
              .toList();
          if (catalog.sigs.isEmpty) {
            return const EmptyView(
              title: 'No communities yet',
              message:
                  'Choose Sample data in Preview data to restore the examples.',
            );
          }
          if (matches.isEmpty) {
            return const EmptyView(
              title: 'No matches',
              message: 'Try another interest or clear your search.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Browsing as ${catalog.profile.displayName}'),
              const SizedBox(height: 16),
              for (final sig in matches)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sig.category,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          sig.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(sig.description),
                        const SizedBox(height: 12),
                        Text(
                          sig.membership == MembershipState.joined
                              ? 'Joined • Preview'
                              : 'Not joined',
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Explore ${sig.name}',
                          variant: AppButtonVariant.secondary,
                          onPressed: () => context.pushNamed(
                            'sig-detail',
                            pathParameters: {'sigId': sig.id},
                          ),
                        ),
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
