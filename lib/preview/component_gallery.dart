import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/avatar_badge.dart';
import '../core/widgets/state_views.dart';

class ComponentGallery extends StatefulWidget {
  const ComponentGallery({super.key});
  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  final _formKey = GlobalKey<FormState>();
  bool _retried = false;
  String _feedback = 'Try a button or validate the sample form.';

  void _showFeedback(String value) => setState(() => _feedback = value);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Components'),
      leading: IconButton(
        tooltip: 'Back to preview',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Component gallery',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text('Development samples only. Nothing is saved or sent.'),
              const SizedBox(height: AppSpacing.xl),
              _section('Buttons'),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppButton(
                    label: 'Primary action',
                    onPressed: () => _showFeedback('Primary action tapped.'),
                  ),
                  AppButton(
                    label: 'Secondary action',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _showFeedback('Secondary action tapped.'),
                  ),
                  AppButton(
                    label: 'Loading',
                    isLoading: true,
                    onPressed: () {},
                  ),
                  const AppButton(label: 'Disabled', onPressed: null),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(liveRegion: true, child: Text(_feedback)),
              const SizedBox(height: AppSpacing.xl),
              _section('Inputs'),
              AppTextField(
                label: 'Display name',
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a display name.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Sample password',
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: (value) => (value?.length ?? 0) < 8
                    ? 'Use at least 8 characters for this sample.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Validate sample',
                onPressed: () {
                  final valid = _formKey.currentState!.validate();
                  _showFeedback(
                    valid
                        ? 'Sample form is valid. Nothing was saved.'
                        : 'Check the highlighted fields.',
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              _section('Card and avatar'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AvatarBadge(name: 'Study Mate'),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'A place to learn together',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Sample card with a longer description that wraps naturally on smaller phones.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _section('Loading, empty and error'),
              const AppCard(child: LoadingView(message: 'Loading sample…')),
              const SizedBox(height: AppSpacing.lg),
              const AppCard(
                child: EmptyView(
                  title: 'No sessions yet',
                  message: 'This is a sample empty state, not your history.',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: _retried
                    ? Column(
                        children: [
                          const Text(
                            'Sample retry succeeded. No network request was made.',
                          ),
                          AppButton(
                            label: 'Show error again',
                            variant: AppButtonVariant.secondary,
                            onPressed: () => setState(() => _retried = false),
                          ),
                        ],
                      )
                    : ErrorView(
                        message: 'Sample error: unable to load sessions.',
                        onRetry: () => setState(() => _retried = true),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}
