import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/invitation_service.dart';
import '../../data/invitation_token.dart';

final invitationServiceProvider = Provider<InvitationService>(
  (ref) => throw StateError('No invitation service configured.'),
);

final invitationPreviewProvider = FutureProvider.autoDispose
    .family<InvitationPreviewResult, String>((ref, token) {
      if (!InvitationTokenParser.isOpaqueToken(token)) {
        return const InvitationPreviewResult(
          status: InvitationPreviewStatus.invalid,
        );
      }
      return ref.watch(invitationServiceProvider).resolveInvitation(token);
    }, retry: (count, error) => null);
