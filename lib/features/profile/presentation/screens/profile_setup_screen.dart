import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../controllers/profile_providers.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key, this.onComplete, this.onCancel});

  final ValueChanged<UserProfile>? onComplete;
  final VoidCallback? onCancel;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(profileMutationProvider).isLoading ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final profile = await ref
          .read(profileMutationProvider.notifier)
          .createProfile(displayName: _displayName.text.trim());
      if (mounted) {
        setState(() => _successMessage = 'Your profile is ready.');
        widget.onComplete?.call(profile);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = profileErrorMessage(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(profileMutationProvider).isLoading;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'Set up your profile',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Choose the name other StudyMates members will see.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              label: 'Display name',
                              controller: _displayName,
                              textInputAction: TextInputAction.done,
                              validator: _validateDisplayName,
                            ),
                            if (_errorMessage != null)
                              _FeedbackMessage(
                                message: _errorMessage!,
                                isError: true,
                              ),
                            if (_successMessage != null)
                              _FeedbackMessage(message: _successMessage!),
                            const SizedBox(height: AppSpacing.lg),
                            AppButton(
                              label: 'Save profile',
                              isLoading: isLoading,
                              onPressed: isLoading ? null : _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.onCancel != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Cancel',
                        variant: AppButtonVariant.secondary,
                        onPressed: isLoading ? null : widget.onCancel,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _validateDisplayName(String? value) =>
    value == null || value.trim().isEmpty ? 'Enter your display name.' : null;

class _FeedbackMessage extends StatelessWidget {
  const _FeedbackMessage({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: TextStyle(
          color: isError
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}
