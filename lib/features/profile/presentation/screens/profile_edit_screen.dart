import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../controllers/profile_providers.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.profile,
    this.onSaved,
    this.onCancel,
  });

  final UserProfile profile;
  final ValueChanged<UserProfile>? onSaved;
  final VoidCallback? onCancel;

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayName;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _displayName = TextEditingController(text: widget.profile.displayName);
  }

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
          .updateProfile(
            existingProfile: widget.profile,
            displayName: _displayName.text.trim(),
          );
      if (mounted) {
        setState(() => _successMessage = 'Your profile was updated.');
        widget.onSaved?.call(profile);
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
                      'Edit your profile',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Update the name shown to other members.'),
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
                              label: 'Save changes',
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
