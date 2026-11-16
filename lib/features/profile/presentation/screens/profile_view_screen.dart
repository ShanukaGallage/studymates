import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/avatar_badge.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../controllers/profile_providers.dart';

class ProfileViewScreen extends ConsumerWidget {
  const ProfileViewScreen({super.key, this.onEdit, this.onSetUpProfile});

  final ValueChanged<UserProfile>? onEdit;
  final VoidCallback? onSetUpProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(authStateProvider);
    final profileState = ref.watch(currentProfileProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Your profile',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (identity.status == AuthStatus.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: LoadingView(message: 'Loading your profile...'),
                ),
              )
            else if (identity.status == AuthStatus.signedOut)
              const EmptyView(
                title: 'Sign in required',
                message: 'Sign in to view your profile.',
              )
            else
              profileState.when(
                skipLoadingOnReload: false,
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: LoadingView(message: 'Loading your profile...'),
                  ),
                ),
                error: (error, _) => ErrorView(
                  message: profileErrorMessage(error),
                  onRetry: () => ref.invalidate(currentProfileProvider),
                ),
                data: (profile) {
                  // A provider may briefly retain its prior AsyncData while a
                  // new UID's stream is being attached. Never render a mismatch.
                  if (profile != null && profile.id != identity.userId) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xxl),
                        child: LoadingView(message: 'Loading your profile...'),
                      ),
                    );
                  }
                  return profile == null
                      ? _MissingProfileView(onSetUpProfile: onSetUpProfile)
                      : _ProfileDetails(profile: profile, onEdit: onEdit);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MissingProfileView extends StatelessWidget {
  const _MissingProfileView({this.onSetUpProfile});

  final VoidCallback? onSetUpProfile;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EmptyView(
          title: 'Profile not set up',
          message: 'Add a display name to finish setting up your profile.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(label: 'Set up profile', onPressed: onSetUpProfile),
      ],
    ),
  );
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.profile, this.onEdit});

  final UserProfile profile;
  final ValueChanged<UserProfile>? onEdit;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: AvatarBadge(
            name: profile.displayName,
            photo: profile.photo,
            size: 80,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          profile.displayName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final detail in [
          ('University or school', profile.institution),
          ('Degree or programme', profile.programme),
          ('Year of study', profile.yearOfStudy),
          ('About', profile.bio),
        ])
          if (detail.$2?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(detail.$1, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(detail.$2!),
          ],
        if (profile.interestIds.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text('Interests', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final interest in profile.interestIds)
                Chip(label: Text(interest)),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Edit profile',
          onPressed: onEdit == null ? null : () => onEdit!(profile),
        ),
      ],
    ),
  );
}
