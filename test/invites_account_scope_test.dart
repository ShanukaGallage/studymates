import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/app/app_mode.dart';
import 'package:studymates/features/auth/domain/auth_state.dart';
import 'package:studymates/features/auth/presentation/controllers/auth_providers.dart';
import 'package:studymates/features/invites/data/invitation_service.dart';
import 'package:studymates/features/invites/presentation/controllers/invitation_providers.dart';

class _Identity extends AuthStateController {
  @override
  AuthState build() => const AuthState.ready(userId: 'a', displayName: 'A');

  void emit(AuthState value) => state = value;
}

class _Lookup implements InvitationService {
  final requests = <Completer<InvitationPreviewResult>>[];

  @override
  Future<InvitationPreviewResult> resolveInvitation(String opaqueToken) {
    final request = Completer<InvitationPreviewResult>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<InvitationAdmissionResult> admitInvitation({
    required String opaqueToken,
    required bool membershipConsentGranted,
  }) => throw StateError('Preview must not admit a user.');
}

void main() {
  const token = 'ABCDEFGHJK23MNPQ';
  final provider = invitationPreviewProvider(token);

  test(
    'same token is revalidated for a new account and ignores old lookup',
    () async {
      final service = _Lookup();
      final container = ProviderContainer(
        overrides: [
          appModeProvider.overrideWithValue(AppMode.connected),
          authStateProvider.overrideWith(_Identity.new),
          invitationServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      container.listen(provider, (_, _) {});
      await container.pump();
      expect(service.requests, hasLength(1));

      (container.read(authStateProvider.notifier) as _Identity).emit(
        const AuthState.ready(userId: 'b', displayName: 'B'),
      );
      await container.pump();
      expect(service.requests, hasLength(2));
      service.requests[1].complete(
        const InvitationPreviewResult(
          status: InvitationPreviewStatus.membershipRequired,
        ),
      );
      await container.read(provider.future);
      service.requests[0].complete(
        const InvitationPreviewResult(status: InvitationPreviewStatus.ready),
      );
      await container.pump();
      expect(
        container.read(provider).requireValue.status,
        InvitationPreviewStatus.membershipRequired,
      );
    },
  );

  test(
    'sign-out clears ready lookup without requesting anonymous admission data',
    () async {
      final service = _Lookup();
      final container = ProviderContainer(
        overrides: [
          appModeProvider.overrideWithValue(AppMode.connected),
          authStateProvider.overrideWith(_Identity.new),
          invitationServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      container.listen(provider, (_, _) {});
      await container.pump();
      service.requests.single.complete(
        const InvitationPreviewResult(status: InvitationPreviewStatus.ready),
      );
      await container.read(provider.future);
      (container.read(authStateProvider.notifier) as _Identity).emit(
        const AuthState.signedOut(),
      );
      await container.pump();
      expect(
        container.read(provider).requireValue.status,
        InvitationPreviewStatus.unavailable,
      );
      expect(service.requests, hasLength(1));
    },
  );
}
