import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_mode.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../data/invitation_service.dart';
import '../../../study/data/firestore_invitation_service.dart';
import '../../data/invitation_token.dart';

final invitationServiceProvider = Provider<InvitationService>(
  (ref) => ref.watch(firestoreInvitationServiceProvider),
);

final invitationPreviewProvider = FutureProvider.autoDispose
    .family<InvitationPreviewResult, String>(
      (ref, token) {
        if (ref.watch(appModeProvider) == AppMode.connected) {
          // Membership-sensitive previews must not survive an account change.
          final userId = ref.watch(
            authStateProvider.select((value) => value.userId),
          );
          if (userId == null) {
            return const InvitationPreviewResult(
              status: InvitationPreviewStatus.unavailable,
            );
          }
        }
        if (!InvitationTokenParser.isOpaqueToken(token)) {
          return const InvitationPreviewResult(
            status: InvitationPreviewStatus.invalid,
          );
        }
        return ref.watch(invitationServiceProvider).resolveInvitation(token);
      },
      retry: (count, error) => null,
      dependencies: [appModeProvider],
    );
