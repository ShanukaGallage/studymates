import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/state_views.dart';

enum _ProgressStatus { loading, empty, error }

/// Presentation-only history states. Embed in the owning screen's scroll view.
/// An empty state means a successful empty read, never a failed/loading request.
class ProgressStatusView extends StatelessWidget {
  const ProgressStatusView.loading({super.key})
    : _status = _ProgressStatus.loading,
      onRetry = null;

  const ProgressStatusView.empty({super.key})
    : _status = _ProgressStatus.empty,
      onRetry = null;

  const ProgressStatusView.error({
    super.key,
    required VoidCallback this.onRetry,
  }) : _status = _ProgressStatus.error;

  final _ProgressStatus _status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Personal history',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: AppSpacing.xl),
      switch (_status) {
        _ProgressStatus.loading => const LoadingView(
          message: 'Loading your recorded sessions…',
        ),
        _ProgressStatus.empty => const EmptyView(
          title: 'No recorded sessions yet',
          message: 'Your saved study sessions will appear here.',
        ),
        _ProgressStatus.error => Semantics(
          liveRegion: true,
          child: ErrorView(
            message: 'Could not load your history. Please try again.',
            onRetry: onRetry!,
          ),
        ),
      },
    ],
  );
}
