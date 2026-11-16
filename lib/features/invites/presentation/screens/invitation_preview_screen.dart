import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/invitation_service.dart';
import '../controllers/invitation_providers.dart';

class InvitationPreviewScreen extends ConsumerStatefulWidget {
  const InvitationPreviewScreen({
    super.key,
    required this.opaqueToken,
    this.onAdmitted,
    this.onRequestMembership,
    this.isFixture = false,
  });
  final String opaqueToken;
  final ValueChanged<InvitationPreview>? onAdmitted;
  final Future<void> Function(InvitationPreview)? onRequestMembership;
  final bool isFixture;

  @override
  ConsumerState<InvitationPreviewScreen> createState() =>
      _InvitationPreviewScreenState();
}

class _InvitationPreviewScreenState
    extends ConsumerState<InvitationPreviewScreen> {
  bool _busy = false;
  bool _consent = false;
  bool _joined = false;
  bool _mustRecheck = false;
  String? _message;
  int _generation = 0;

  @override
  void didUpdateWidget(covariant InvitationPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opaqueToken != widget.opaqueToken) {
      _generation++;
      _busy = _consent = _joined = _mustRecheck = false;
      _message = null;
    }
  }

  Future<void> _join(InvitationPreview preview) async {
    if (_busy || _joined || _mustRecheck) return;
    final generation = _generation;
    final token = widget.opaqueToken;
    bool notifyAdmission = false;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(invitationServiceProvider)
          .admitInvitation(
            opaqueToken: token,
            membershipConsentGranted: _consent,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _joined = result.status == InvitationAdmissionStatus.admitted;
        _mustRecheck = !_joined;
        _message = switch (result.status) {
          InvitationAdmissionStatus.admitted =>
            widget.isFixture
                ? 'Fixture admission returned admitted. No live seat was reserved.'
                : 'Room admission confirmed.',
          InvitationAdmissionStatus.fullRoom =>
            'The room became full. No admission was confirmed.',
          InvitationAdmissionStatus.membershipRequired =>
            'Active membership is still required. Recheck the invitation.',
          InvitationAdmissionStatus.expiredOrRevoked =>
            'This invitation expired or was revoked.',
          InvitationAdmissionStatus.invalid =>
            'This invitation is no longer valid.',
          InvitationAdmissionStatus.unavailable =>
            'Admission is unavailable. Recheck before trying again.',
        };
      });
      notifyAdmission = _joined;
    } on Object {
      if (mounted && generation == _generation) {
        setState(() {
          _mustRecheck = true;
          _message =
              'Could not confirm admission. Recheck before trying again.';
        });
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
    if (notifyAdmission && mounted && generation == _generation) {
      widget.onAdmitted?.call(preview);
    }
  }

  Future<void> _requestMembership(InvitationPreview preview) async {
    if (!_consent || _busy || widget.onRequestMembership == null) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.onRequestMembership!(preview);
      if (!mounted || generation != _generation) return;
      ref.invalidate(invitationPreviewProvider(widget.opaqueToken));
    } on Object {
      if (mounted && generation == _generation) {
        setState(
          () => _message =
              'Membership could not be confirmed. Please retry or recheck.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  void _recheck() {
    if (_busy || _joined) return;
    setState(() {
      _mustRecheck = false;
      _message = null;
      _consent = false;
    });
    ref.invalidate(invitationPreviewProvider(widget.opaqueToken));
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(invitationPreviewProvider(widget.opaqueToken));
    return Scaffold(
      appBar: AppBar(title: const Text('Review invitation')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (widget.isFixture)
              const Text('Fixture preview only · no live room admission.'),
            result.when(
              skipLoadingOnRefresh: false,
              loading: () => const LoadingView(message: 'Checking invitation…'),
              error: (_, _) => ErrorView(
                message: 'Could not check this invitation. Please retry.',
                onRetry: _recheck,
              ),
              data: (value) => _details(context, value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(BuildContext context, InvitationPreviewResult result) {
    final preview = result.preview;
    final ready =
        result.status == InvitationPreviewStatus.ready && preview != null;
    final needsMembership =
        result.status == InvitationPreviewStatus.membershipRequired &&
        preview != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        if (preview != null) ...[
          Text(
            preview.room.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Study group: ${preview.sig.name}'),
          Text('Subgroup: ${preview.subgroup.name}'),
          Text(
            'Preview occupancy: ${preview.room.occupiedSeats} of ${preview.room.capacity} seats',
          ),
          const Text(
            'A preview is not a reservation. Membership and capacity are checked when you join.',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(switch (result.status) {
          InvitationPreviewStatus.ready =>
            preview == null
                ? 'Invitation details are unavailable.'
                : 'Review the room before choosing Join.',
          InvitationPreviewStatus.membershipRequired => 'You need active study-group and subgroup membership before joining.',
          InvitationPreviewStatus.fullRoom =>
            'This room is full. Try another invitation or recheck later.',
          InvitationPreviewStatus.invalid =>
            'This invitation is invalid. Ask the host for a new code.',
          InvitationPreviewStatus.expiredOrRevoked => 'This invitation expired or was revoked. Ask the host for a new code.',
          InvitationPreviewStatus.unavailable =>
            'This invitation is unavailable. Please recheck later.',
        }),
        if (needsMembership && !_joined) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'I agree to request membership in ${preview.sig.name} and ${preview.subgroup.name}.',
            ),
            subtitle: const Text(
              'Checking this box does not enroll you or reserve a seat.',
            ),
            value: _consent,
            onChanged: _busy
                ? null
                : (value) => setState(() => _consent = value ?? false),
          ),
          if (widget.onRequestMembership == null)
            const Text(
              'Membership navigation is not connected. Join the communities first, then recheck.',
            ),
          AppButton(
            label: 'Continue to membership',
            isLoading: _busy,
            onPressed: _consent && widget.onRequestMembership != null
                ? () => _requestMembership(preview)
                : null,
          ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Semantics(liveRegion: true, child: Text(_message!)),
          ),
        if (ready && !_joined) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Join room',
            isLoading: _busy,
            onPressed: _mustRecheck ? null : () => _join(preview),
          ),
        ],
        if (!_joined) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Recheck invitation',
            variant: AppButtonVariant.secondary,
            onPressed: _busy ? null : _recheck,
          ),
        ],
      ],
    );
  }
}
