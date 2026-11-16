import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/widgets/app_button.dart';
import '../core/widgets/state_views.dart';
import '../features/auth/presentation/controllers/auth_providers.dart';
import '../features/profile/presentation/controllers/profile_providers.dart';
import '../features/profile/presentation/screens/profile_edit_screen.dart';
import 'account_access.dart';

Future<void> signOutAccount(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(authStateProvider.notifier).signOut();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }
}

class AccountStatusScreen extends ConsumerWidget {
  const AccountStatusScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accountAccessProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (access == AccountAccess.unavailable) ...[
              ErrorView(
                message: 'We could not verify your account and profile.',
                onRetry: () {
                  ref.invalidate(authStateProvider);
                  ref.invalidate(currentProfileProvider);
                },
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Sign out',
                onPressed: () => signOutAccount(context, ref),
              ),
            ] else
              const LoadingView(message: 'Checking your account…'),
          ],
        ),
      ),
    );
  }
}

class AccountProfileEditScreen extends ConsumerWidget {
  const AccountProfileEditScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final uid = ref.watch(authStateProvider).userId;
    if (profile == null || profile.id != uid) {
      return const AccountStatusScreen();
    }
    return ProfileEditScreen(
      key: ValueKey(profile.id),
      profile: profile,
      onSaved: (_) => context.go('/profile'),
      onCancel: () => context.go('/profile'),
    );
  }
}
