import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/core/models/active_room_session.dart';
import 'package:studymates/features/auth/domain/auth_state.dart';
import 'package:studymates/features/auth/presentation/controllers/auth_providers.dart';
import 'package:studymates/features/sessions/data/active_session_providers.dart';
import 'package:studymates/preview/active_session_fixtures.dart';

class _TestAuthController extends AuthStateController {
  @override
  AuthState build() => const AuthState.loading();

  void setIdentity(AuthState identity) => state = identity;
}

void main() {
  test('account change never exposes the previous user session', () async {
    final fixture = FixtureActiveSessionRepository(
      currentUserId: 'preview-user-1',
      sessionsByUser: {
        'preview-user-1': ActiveSessionFixtures.validActiveSession,
        'preview-user-2': ActiveSessionFixtures.otherUserActiveSession,
      },
    );
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(_TestAuthController.new),
        activeSessionRepositoryProvider.overrideWithValue(fixture),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fixture.dispose);
    final stateChanges = <AsyncValue<ActiveRoomSession?>>[];
    final providerSubscription = container.listen(
      currentUserActiveSessionProvider,
      (_, state) => stateChanges.add(state),
      fireImmediately: true,
    );
    addTearDown(providerSubscription.close);
    final auth =
        container.read(authStateProvider.notifier) as _TestAuthController;

    expect(
      container.read(currentUserActiveSessionProvider),
      isA<AsyncLoading>(),
    );

    auth.setIdentity(
      const AuthState.ready(userId: 'preview-user-1', displayName: 'One'),
    );
    await _until(
      () => _session(container.read(currentUserActiveSessionProvider)) != null,
    );
    expect(
      container.read(currentUserActiveSessionProvider),
      isA<AsyncData<ActiveRoomSession?>>(),
    );

    fixture.switchUserForTest('preview-user-2');
    auth.setIdentity(
      const AuthState.ready(userId: 'preview-user-2', displayName: 'Two'),
    );
    expect(
      _session(container.read(currentUserActiveSessionProvider))?.userId,
      isNot('preview-user-1'),
    );
    await _until(
      () =>
          _session(container.read(currentUserActiveSessionProvider))?.userId ==
          'preview-user-2',
    );
    expect(
      _session(container.read(currentUserActiveSessionProvider))?.userId,
      'preview-user-2',
    );
    expect(
      stateChanges.whereType<AsyncData<ActiveRoomSession?>>().any(
        (value) => value.value?.userId == 'preview-user-1',
      ),
      isTrue,
    );
  });
}

ActiveRoomSession? _session(AsyncValue<ActiveRoomSession?> value) =>
    value is AsyncData<ActiveRoomSession?> ? value.value : null;

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Provider did not reach the expected state.');
}
