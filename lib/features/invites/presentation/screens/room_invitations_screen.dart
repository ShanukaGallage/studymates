import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../study/data/firestore_invitation_service.dart';
import 'invitation_display_screen.dart';

class RoomInvitationsScreen extends ConsumerStatefulWidget {
  const RoomInvitationsScreen({
    super.key,
    required this.subgroup,
    required this.room,
    required this.title,
  });
  final String subgroup, room, title;
  @override
  ConsumerState<RoomInvitationsScreen> createState() => _RoomInvitationsState();
}

class _RoomInvitationsState extends ConsumerState<RoomInvitationsScreen> {
  late Stream<List<RoomInvitation>> _invitations;
  bool _creating = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _invitations = ref
      .read(firestoreInvitationServiceProvider)
      .watchRoomInvitations(widget.subgroup, widget.room);

  Future<void> _create() async {
    if (_creating) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final token = await ref
          .read(firestoreInvitationServiceProvider)
          .issue(widget.subgroup, widget.room);
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ManagedInvitationScreen(token: token, roomTitle: widget.title),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not create an invitation. Check your host access and connection, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Room invitations')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const Text(
            'Revoke a code to stop new admissions. Learners already admitted keep their room access.',
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'New invitation',
            isLoading: _creating,
            onPressed: _create,
          ),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          const SizedBox(height: 16),
          const Text(
            'Showing up to 50 stored codes. Open a code to view, share or revoke it.',
          ),
          StreamBuilder<List<RoomInvitation>>(
            stream: _invitations,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorView(
                  message: 'Invitations unavailable. Check your host access and connection.',
                  onRetry: () => setState(_load),
                );
              }
              if (!snapshot.hasData) {
                return const LoadingView(message: 'Loading invitations…');
              }
              if (snapshot.data!.isEmpty) {
                return const EmptyView(
                  title: 'No invitations yet',
                  message: 'Create a code to invite a learner.',
                );
              }
              return Column(
                children: [
                  for (final invite in snapshot.data!)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: Icon(
                        invite.revoked ? Icons.link_off : Icons.qr_code,
                      ),
                      title: Text(invite.manualCode),
                      subtitle: Text(
                        invite.revoked
                            ? 'Revoked'
                            : invite.expired
                            ? 'Expired'
                            : 'Expires ${invite.expiresAt.toLocal()}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ManagedInvitationScreen(
                            token: invite.token,
                            roomTitle: widget.title,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// Watches the issued code so another host's revocation removes QR/share actions.
class ManagedInvitationScreen extends ConsumerStatefulWidget {
  const ManagedInvitationScreen({
    super.key,
    required this.token,
    required this.roomTitle,
  });
  final String token, roomTitle;
  @override
  ConsumerState<ManagedInvitationScreen> createState() =>
      _ManagedInvitationState();
}

class _ManagedInvitationState extends ConsumerState<ManagedInvitationScreen> {
  late Stream<RoomInvitation?> _invitation;
  Timer? _clock;
  bool _revoking = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _load() => _invitation = ref
      .read(firestoreInvitationServiceProvider)
      .watchInvitation(widget.token);
  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _revoke() async {
    if (_revoking) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke this invitation?'),
        content: const Text(
          'This code will stop accepting new learners. Existing room access and seats are unchanged. Revocation cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep code'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke code'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _revoking = true;
      _error = null;
    });
    try {
      await ref
          .read(firestoreInvitationServiceProvider)
          .revokeInvitation(widget.token);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Revocation could not be confirmed. Check your access and connection, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _revoking = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<RoomInvitation?>(
    stream: _invitation,
    builder: (context, snapshot) {
      final invite = snapshot.data;
      if (snapshot.hasData &&
          invite != null &&
          !invite.revoked &&
          !invite.expired) {
        return InvitationDisplayScreen(
          opaqueToken: widget.token,
          roomTitle: widget.roomTitle,
          management: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text('Expires ${invite.expiresAt.toLocal()}'),
              if (_error != null)
                Semantics(liveRegion: true, child: Text(_error!)),
              AppButton(
                label: 'Revoke invitation',
                variant: AppButtonVariant.secondary,
                isLoading: _revoking,
                onPressed: _revoke,
              ),
            ],
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Room invitation')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (snapshot.hasError)
                ErrorView(
                  message:
                      'Could not verify this code. Reconnect before sharing.',
                  onRetry: () => setState(_load),
                )
              else if (snapshot.connectionState == ConnectionState.waiting)
                const LoadingView(message: 'Checking invitation…')
              else
                EmptyView(
                  title: invite?.revoked == true
                      ? 'Invitation revoked'
                      : invite?.expired == true
                      ? 'Invitation expired'
                      : 'Invitation unavailable',
                  message: 'This code cannot be used for new admissions. Existing learners keep their room access.',
                ),
            ],
          ),
        ),
      );
    },
  );
}
