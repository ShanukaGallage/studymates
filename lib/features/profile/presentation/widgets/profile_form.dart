import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/avatar_badge.dart';
import '../controllers/profile_providers.dart';
import '../../data/profile_photo_picker.dart';

/// Shared editable fields for setup and the owner's full profile editor.
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key, this.profile, this.onSaved, this.onCancel});

  final UserProfile? profile;
  final ValueChanged<UserProfile>? onSaved;
  final VoidCallback? onCancel;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayName;
  late final TextEditingController _institution;
  late final TextEditingController _programme;
  late final TextEditingController _bio;
  final _newInterest = TextEditingController();
  late final List<String> _interests;
  String? _yearOfStudy;
  String? _errorMessage;
  String? _successMessage;
  ProfilePhoto? _photo;
  bool _isPickingPhoto = false;

  bool get _isEditing => widget.profile != null;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _displayName = TextEditingController(text: profile?.displayName);
    _institution = TextEditingController(text: profile?.institution);
    _programme = TextEditingController(text: profile?.programme);
    _bio = TextEditingController(text: profile?.bio);
    _interests = List.of(profile?.interestIds ?? const <String>[]);
    _yearOfStudy = profile?.yearOfStudy;
    _photo = profile?.photo;
  }

  @override
  void dispose() {
    for (final controller in [
      _displayName,
      _institution,
      _programme,
      _bio,
      _newInterest,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addInterest() {
    final interest = _newInterest.text.trim();
    if (interest.isEmpty) return;
    setState(() {
      if (!_interests.any(
        (existing) => existing.toLowerCase() == interest.toLowerCase(),
      )) {
        _interests.add(interest);
      }
      _newInterest.clear();
    });
  }

  Future<void> _submit() async {
    if (_isPickingPhoto ||
        ref.read(profileMutationProvider).isLoading ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    // Include a typed tag even if the user goes straight to Save.
    _addInterest();
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });
    final mutation = ref.read(profileMutationProvider.notifier);
    try {
      final existing = widget.profile;
      final profile = existing == null
          ? await mutation.createProfile(
              displayName: _displayName.text.trim(),
              institution: _institution.text,
              interestIds: List.of(_interests),
              photo: _photo,
            )
          : await mutation.updateProfile(
              existingProfile: existing,
              displayName: _displayName.text.trim(),
              institution: _institution.text,
              interestIds: List.of(_interests),
              programme: _programme.text,
              yearOfStudy: _yearOfStudy,
              bio: _bio.text,
              photo: _photo,
            );
      if (!mounted) return;
      setState(() {
        _successMessage = _isEditing
            ? 'Your profile has been updated.'
            : 'Your profile is ready.';
      });
      widget.onSaved?.call(profile);
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = profileErrorMessage(error));
      }
    }
  }

  Future<void> _choosePhoto() async {
    if (_isPickingPhoto || ref.read(profileMutationProvider).isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isPickingPhoto = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final selected = await ref.read(profilePhotoPickerProvider).pickPhoto();
      if (mounted && selected != null) setState(() => _photo = selected);
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = error is ProfilePhotoException
              ? error.message
              : 'Could not use that photo. Please try another.',
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(profileMutationProvider).isLoading;
    final colors = Theme.of(context).colorScheme;
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
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      _isEditing ? 'Edit your profile' : 'Set up your profile',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Only your display name is required.'),
                    const SizedBox(height: AppSpacing.xl),
                    AppCard(
                      child: AbsorbPointer(
                        absorbing: isLoading || _isPickingPhoto,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Profile photo (optional)',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Center(
                                child: ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _displayName,
                                  builder: (context, value, _) => AvatarBadge(
                                    name: value.text,
                                    photo: _photo,
                                    size: 80,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              AppButton(
                                key: const ValueKey('profile-choose-photo'),
                                label: _photo == null
                                    ? 'Add photo'
                                    : 'Change photo',
                                variant: AppButtonVariant.secondary,
                                isLoading: _isPickingPhoto,
                                onPressed: _choosePhoto,
                              ),
                              if (_photo != null)
                                TextButton(
                                  key: const ValueKey('profile-remove-photo'),
                                  onPressed: () =>
                                      setState(() => _photo = null),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                  child: const Text('Remove photo'),
                                ),
                              if (_errorMessage != null && !_isPickingPhoto)
                                _FeedbackMessage(
                                  message: _errorMessage!,
                                  isError: true,
                                ),
                              const SizedBox(height: AppSpacing.xl),
                              AppTextField(
                                key: const ValueKey('profile-display-name'),
                                label: 'Display name',
                                labelAbove: true,
                                controller: _displayName,
                                textInputAction: TextInputAction.next,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Enter your display name.'
                                    : null,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              AppTextField(
                                key: const ValueKey('profile-institution'),
                                label: 'University or school (optional)',
                                labelAbove: true,
                                controller: _institution,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                'Study interests (optional)',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if (_interests.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                LayoutBuilder(
                                  builder: (context, constraints) => Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.sm,
                                    children: [
                                      for (final interest in _interests)
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: constraints.maxWidth,
                                          ),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: colors.primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                left: AppSpacing.md,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      interest,
                                                      style: TextStyle(
                                                        color: colors
                                                            .onPrimaryContainer,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Remove $interest',
                                                    constraints:
                                                        const BoxConstraints(
                                                          minWidth: 48,
                                                          minHeight: 48,
                                                        ),
                                                    onPressed: () => setState(
                                                      () => _interests.remove(
                                                        interest,
                                                      ),
                                                    ),
                                                    icon: const Icon(
                                                      Icons.close,
                                                      size: 20,
                                                    ),
                                                    color: colors
                                                        .onPrimaryContainer,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.sm),
                              AppTextField(
                                key: const ValueKey('profile-new-interest'),
                                label: 'Add an interest',
                                labelAbove: true,
                                controller: _newInterest,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _addInterest(),
                                suffixIcon: IconButton(
                                  tooltip: 'Add interest',
                                  onPressed: _addInterest,
                                  icon: const Icon(Icons.add),
                                ),
                              ),
                              if (_isEditing) ...[
                                const SizedBox(height: AppSpacing.xl),
                                AppTextField(
                                  key: const ValueKey('profile-programme'),
                                  label: 'Degree or programme (optional)',
                                  labelAbove: true,
                                  controller: _programme,
                                  textInputAction: TextInputAction.next,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                ExcludeSemantics(
                                  child: Text(
                                    'Year of study (optional)',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Semantics(
                                  label: 'Year of study (optional)',
                                  child: DropdownButtonFormField<String>(
                                    key: const ValueKey('profile-study-year'),
                                    initialValue: _yearOfStudy ?? '',
                                    isExpanded: true,
                                    items: [
                                      const DropdownMenuItem(
                                        value: '',
                                        child: Text('Not set'),
                                      ),
                                      for (final year in UserProfile.studyYears)
                                        DropdownMenuItem(
                                          value: year,
                                          child: Text(year),
                                        ),
                                    ],
                                    onChanged: (value) => setState(
                                      () => _yearOfStudy = value == ''
                                          ? null
                                          : value,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                AppTextField(
                                  key: const ValueKey('profile-bio'),
                                  label: 'Short bio (optional)',
                                  labelAbove: true,
                                  controller: _bio,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  minLines: 2,
                                  maxLines: 4,
                                  maxLength: 160,
                                ),
                              ],
                              if (_successMessage != null)
                                _FeedbackMessage(message: _successMessage!),
                              const SizedBox(height: AppSpacing.xl),
                              AppButton(
                                label: _isEditing
                                    ? 'Save changes'
                                    : 'Save profile',
                                isLoading: isLoading,
                                onPressed: isLoading || _isPickingPhoto
                                    ? null
                                    : _submit,
                              ),
                              if (widget.onCancel != null) ...[
                                const SizedBox(height: AppSpacing.sm),
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
                    ),
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

class _FeedbackMessage extends StatelessWidget {
  const _FeedbackMessage({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: TextStyle(
          color: isError ? Theme.of(context).colorScheme.error : null,
        ),
      ),
    ),
  );
}
