import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_mode.dart';
import '../../../../core/models/community_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_details.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../study/data/firestore_study_repository.dart';
import '../controllers/community_providers.dart';
import '../controllers/discovery_connection_provider.dart';
import '../controllers/pending_leave_providers.dart';
import '../widgets/community_discovery_card.dart';
import '../widgets/community_management_dialogs.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});
  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _joinedOnly = false;
  bool _finishingLeave = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  Future<void> _recoverLeave() async {
    if (_finishingLeave) return;
    setState(() => _finishingLeave = true);
    try {
      final count = await ref.read(pendingLeaveRecoveryProvider).recover();
      ref.invalidate(communityCatalogProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count == 0
                  ? 'No pending leave requests.'
                  : 'Leave requests completed.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StudyFailure ? error.message : 'Could not finish leaving. Check your connection and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        ref.invalidate(pendingLeaveCountProvider);
        setState(() => _finishingLeave = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(communityCatalogProvider);
    final connected = ref.watch(appModeProvider) == AppMode.connected;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.background, Color(0xFFFCFAFF)],
        ),
      ),
      child: AppContentWidth(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final heading = Text(
                          'Discover',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                        );
                        final create = FilledButton.tonalIcon(
                          key: const ValueKey('create-community'),
                          onPressed: () => showCreateSigDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Create'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        );
                        if (constraints.maxWidth < 340 &&
                            MediaQuery.textScalerOf(context).scale(16) > 20) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              heading,
                              const SizedBox(height: 8),
                              create,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: heading),
                            const SizedBox(width: 12),
                            create,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Find your next study circle',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 24),
                    AppTextField(
                      label: 'Search communities',
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.close),
                            ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 20),
                    _CommunityTabs(
                      joinedOnly: _joinedOnly,
                      onChanged: (value) => setState(() => _joinedOnly = value),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            if (connected) _body(_connectionNotice()),
            ...catalog.when<List<Widget>>(
              skipLoadingOnReload: false,
              skipLoadingOnRefresh: false,
              loading: () => [
                _body(const LoadingView(message: 'Loading communities…')),
              ],
              error: (_, _) => [
                _body(
                  ErrorView(
                    message: 'Communities are unavailable. Try again.',
                    onRetry: () => ref.invalidate(communityCatalogProvider),
                  ),
                ),
              ],
              data: (data) {
                final matches = data.sigs
                    .where(
                      (sig) =>
                          (!_joinedOnly ||
                              sig.membership == MembershipState.joined) &&
                          '${sig.name} ${sig.category} ${sig.description}'
                              .toLowerCase()
                              .contains(_query),
                    )
                    .toList();
                return [
                  _body(
                    Text(
                      '${matches.length} ${matches.length == 1 ? 'community' : 'communities'}',
                      key: const ValueKey('community-result-count'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (matches.isEmpty)
                    _body(
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: EmptyView(
                          title: data.sigs.isEmpty
                              ? 'No communities yet'
                              : _joinedOnly && _query.isEmpty
                              ? 'Your study circle starts here'
                              : 'No matches',
                          message: data.sigs.isEmpty
                              ? 'Create a community to start studying together.'
                              : _query.isNotEmpty
                              ? 'Try another name or clear your search.'
                              : 'Explore All communities to find your first group.',
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverList.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final sig = matches[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CommunityDiscoveryCard(
                            key: ValueKey('community-card-${sig.id}'),
                            community: sig,
                            subgroupCount: data.activeSubgroups
                                .where((group) => group.sigId == sig.id)
                                .length,
                            onOpen: () => context.pushNamed(
                              'sig-detail',
                              pathParameters: {'sigId': sig.id},
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ];
              },
            ),
            if (connected) _body(_pendingLeaveLink()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _body(Widget child) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    sliver: SliverToBoxAdapter(child: child),
  );

  Widget _connectionNotice() {
    final connection = ref.watch(discoveryConnectionProvider);
    if (!connection.hasError && connection.asData?.value != false) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.secondaryText),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Connection unverified. Results may be out of date.'),
          ),
          IconButton(
            tooltip: 'Retry connection',
            onPressed: () {
              ref.invalidate(discoveryConnectionProvider);
              ref.invalidate(communityCatalogProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _pendingLeaveLink() => ref
      .watch(pendingLeaveCountProvider)
      .when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => TextButton.icon(
          onPressed: () => ref.invalidate(pendingLeaveCountProvider),
          icon: const Icon(Icons.sync_problem_outlined),
          label: const Text('Could not check leave requests · Retry'),
        ),
        data: (count) => count == 0
            ? const SizedBox.shrink()
            : Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('pending-leave-link'),
                  onPressed: _finishingLeave ? null : _recoverLeave,
                  icon: _finishingLeave
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.info_outline),
                  label: Text(
                    _finishingLeave
                        ? 'Finishing leave requests…'
                        : 'Pending leave requests',
                  ),
                ),
              ),
      );
}

class _CommunityTabs extends StatelessWidget {
  const _CommunityTabs({required this.joinedOnly, required this.onChanged});
  final bool joinedOnly;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.primary.withValues(alpha: .3)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final mine in [false, true])
            Expanded(
              child: Semantics(
                selected: joinedOnly == mine,
                child: TextButton(
                  onPressed: () => onChanged(mine),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    backgroundColor: joinedOnly == mine
                        ? AppColors.softAccent
                        : Colors.transparent,
                    foregroundColor: joinedOnly == mine
                        ? AppColors.primary
                        : AppColors.secondaryText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    mine ? 'My communities' : 'All communities',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: joinedOnly == mine
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
