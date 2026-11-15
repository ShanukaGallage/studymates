import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/models/community_models.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../controllers/community_providers.dart';

class CatalogView extends ConsumerWidget {
  const CatalogView({super.key, required this.builder});
  final Widget Function(CommunityCatalog) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(communityCatalogProvider)
      .when(
        skipLoadingOnReload: false,
        skipLoadingOnRefresh: false,
        data: builder,
        loading: () => const LoadingView(message: 'Loading communities…'),
        error: (error, stack) => ErrorView(
          message: 'Communities are unavailable. Try again.',
          onRetry: () => ref.invalidate(communityCatalogProvider),
        ),
      );
}

class MissingPreviewItem extends StatelessWidget {
  const MissingPreviewItem({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const EmptyView(
        title: 'Not found',
        message: 'This item is not in the current preview data.',
      ),
      const SizedBox(height: 16),
      AppButton(
        label: 'Back to Discover',
        onPressed: () => context.go('/discover'),
      ),
    ],
  );
}

class MembershipAction extends StatefulWidget {
  const MembershipAction({
    super.key,
    required this.joined,
    required this.subject,
    required this.onChange,
    this.enabled = true,
    this.leaveMessage,
  });
  final bool joined, enabled;
  final String subject;
  final String? leaveMessage;
  final Future<void> Function(MembershipState) onChange;
  @override
  State<MembershipAction> createState() => _MembershipActionState();
}

class _MembershipActionState extends State<MembershipAction> {
  bool _busy = false;
  bool _confirming = false;
  String? _error;
  Future<void> _change() async {
    if (_busy || _confirming) return;
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      if (widget.joined) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Leave ${widget.subject}?'),
            content: Text(
              widget.leaveMessage ??
                  'This changes your preview membership only.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      setState(() {
        _confirming = false;
        _busy = true;
      });
      await widget.onChange(
        widget.joined ? MembershipState.notJoined : MembershipState.joined,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              error is RepositoryException &&
                  error.code == RepositoryError.membershipRequired
              ? 'Join the parent SIG first.'
              : 'Membership could not be updated. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppButton(
        label: '${widget.joined ? 'Leave' : 'Join'} ${widget.subject}',
        variant: widget.joined
            ? AppButtonVariant.secondary
            : AppButtonVariant.primary,
        isLoading: _busy,
        onPressed: widget.enabled && !_confirming ? _change : null,
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
    ],
  );
}
