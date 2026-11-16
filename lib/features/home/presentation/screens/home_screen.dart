import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_mode.dart';
import '../../../study/presentation/active_session_card.dart';
import '../../../../core/models/community_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/avatar_badge.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../communities/presentation/controllers/community_providers.dart';
import '../../../profile/presentation/controllers/profile_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.mode});
  final AppMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = mode == AppMode.preview;
    final catalog = mode != AppMode.foundation
        ? ref.watch(communityCatalogProvider)
        : null;
    final profile = mode == AppMode.connected
        ? ref.watch(currentProfileProvider).asData?.value
        : catalog?.asData?.value.profile;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.background,
            AppColors.softAccent,
            AppColors.background,
          ],
          stops: [0, .55, 1],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (profile?.photo != null)
                        AvatarBadge(
                          name: profile!.displayName,
                          photo: profile.photo,
                        )
                      else
                        const _TileIcon(
                          icon: Icons.school_outlined,
                          color: AppColors.softAccent,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'A little focus, together.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              profile == null
                                  ? 'Welcome to StudyMates'
                                  : 'Hello, ${profile.displayName}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _FocusCard(
                    preview: preview,
                    connected: mode == AppMode.connected,
                  ),
                  if (mode == AppMode.connected) ...[
                    const SizedBox(height: 16),
                    const ActiveSessionCard(),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'Your communities',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (catalog != null)
                    catalog.when(
                      skipLoadingOnRefresh: false,
                      loading: () => const LoadingView(
                        message: 'Loading your communities…',
                      ),
                      error: (_, _) => ErrorView(
                        message: 'Could not load your communities.',
                        onRetry: () => ref.invalidate(communityCatalogProvider),
                      ),
                      data: (value) =>
                          _Communities(catalog: value, preview: preview),
                    )
                  else
                    const AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TileIcon(
                            icon: Icons.groups_outlined,
                            color: AppColors.blueAccent,
                          ),
                          SizedBox(height: 12),
                          Text('Community connection coming next'),
                          SizedBox(height: 8),
                          Text(
                            'Your account is ready. Joined communities will appear here once the community service is connected.',
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 28),
                  Text(
                    'Make space to study',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.track_changes,
                    tint: AppColors.mintAccent,
                    title: 'One small goal',
                    subtitle: preview
                        ? 'Explore a community, choose a room and try a local focus session.'
                        : 'Choose one achievable task for your next study session.',
                    onTap: () => context.go('/discover'),
                  ),
                  const SizedBox(height: 12),
                  if (preview)
                    _ActionCard(
                      icon: Icons.insights_outlined,
                      tint: AppColors.blueAccent,
                      title: 'Your study journey',
                      subtitle: 'Explore sample history. Preview sessions do not add to these totals.',
                      onTap: () => context.go('/progress'),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    preview
                        ? 'Preview space • Communities and activity are local samples.'
                        : 'One goal at a time. Your saved sessions appear in Progress.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.preview, required this.connected});
  final bool preview, connected;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.heroEnd],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR NEXT CHAPTER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Small steps.\nShared focus.',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            if (MediaQuery.sizeOf(context).width >= 360 &&
                MediaQuery.textScalerOf(context).scale(16) <= 22)
              const ExcludeSemantics(child: _BookArt()),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Find your people. Pick one goal. Make a little progress together.',
          style: TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
          ),
          onPressed: preview
              ? () => context.go('/discover')
              : connected
              ? () => context.go('/profile')
              : null,
          child: Text(preview ? 'Explore communities' : 'View my profile'),
        ),
      ],
    ),
  );
}

// Original code-drawn decoration; no image assets or AI feature implied.
class _BookArt extends StatelessWidget {
  const _BookArt();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 98,
    height: 115,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          bottom: 12,
          right: 0,
          child: Transform.rotate(
            angle: -.12,
            child: _book(AppColors.mintAccent, 84),
          ),
        ),
        Positioned(
          bottom: 40,
          right: 6,
          child: Transform.rotate(
            angle: .1,
            child: _book(AppColors.blueAccent, 80),
          ),
        ),
        const Positioned(
          top: 0,
          right: 20,
          child: Icon(Icons.auto_awesome, color: Colors.white, size: 26),
        ),
      ],
    ),
  );
  Widget _book(Color color, double width) => Container(
    width: width,
    height: 36,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24000000),
          offset: Offset(0, 5),
          blurRadius: 8,
        ),
      ],
    ),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 8,
        margin: const EdgeInsets.fromLTRB(9, 0, 4, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
  );
}

class _Communities extends StatelessWidget {
  const _Communities({required this.catalog, required this.preview});
  final CommunityCatalog catalog;
  final bool preview;
  @override
  Widget build(BuildContext context) {
    final joined = catalog.sigs
        .where((sig) => sig.membership == MembershipState.joined)
        .toList();
    if (joined.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TileIcon(
              icon: Icons.groups_outlined,
              color: AppColors.softAccent,
            ),
            const SizedBox(height: 12),
            Text(
              'Find your study circle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Join a community around something you want to learn. Your joined communities will appear here.',
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Find a community',
              variant: AppButtonVariant.secondary,
              onPressed: () => context.go('/discover'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final sig in joined)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ActionCard(
              icon: Icons.menu_book_outlined,
              tint: AppColors.softAccent,
              title: sig.name,
              subtitle:
                  '${sig.category} • ${preview ? 'Joined in preview' : 'Joined'}',
              onTap: () => context.goNamed(
                'sig-detail',
                pathParameters: {'sigId': sig.id},
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final Color tint;
  final String title, subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TileIcon(icon: icon, color: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.secondaryText),
          ],
        ),
      ),
    ),
  );
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Icon(icon, color: AppColors.primary),
  );
}
