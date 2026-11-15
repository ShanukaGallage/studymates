import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/features/auth/data/auth_repository.dart';
import 'package:studymates/features/auth/domain/auth_state.dart';
import 'package:studymates/features/auth/presentation/controllers/auth_providers.dart';

void main() {
  test('identity mapping distinguishes signed-out and incomplete profiles', () {
    final signedOut = AuthState.fromIdentity(userId: null);
    expect(signedOut.status, AuthStatus.signedOut);
    expect(signedOut.userId, isNull);

    final incomplete = AuthState.fromIdentity(
      userId: '  firebase-uid  ',
      displayName: '  ',
    );
    expect(incomplete.status, AuthStatus.incompleteProfile);
    expect(incomplete.userId, 'firebase-uid');
    expect(incomplete.displayName, isNull);
  });

  test('identity mapping marks a named Firebase identity ready', () {
    final ready = AuthState.fromIdentity(
      userId: 'firebase-uid',
      displayName: '  Poojani  ',
    );

    expect(ready.status, AuthStatus.ready);
    expect(ready.userId, 'firebase-uid');
    expect(ready.displayName, 'Poojani');
  });

  test(
    'auth state controller follows identity stream and delegates actions',
    () async {
      final repository = _FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });

      expect(container.read(authStateProvider).status, AuthStatus.loading);
      repository.emit(const AuthState.signedOut());
      await _flushStream();
      expect(container.read(authStateProvider).status, AuthStatus.signedOut);

      repository.emit(const AuthState.incompleteProfile(userId: 'uid-1'));
      await _flushStream();
      expect(
        container.read(authStateProvider).status,
        AuthStatus.incompleteProfile,
      );
      expect(container.read(authStateProvider).userId, 'uid-1');

      repository.emit(
        const AuthState.ready(userId: 'uid-1', displayName: 'Learner'),
      );
      await _flushStream();
      expect(container.read(authStateProvider).status, AuthStatus.ready);

      final controller = container.read(authStateProvider.notifier);
      await controller.createAccount(
        email: 'new@example.com',
        password: 'secret',
      );
      await controller.signIn(email: 'learner@example.com', password: 'secret');
      await controller.sendPasswordReset(email: 'learner@example.com');
      await controller.signOut();

      expect(repository.actions, [
        'create:new@example.com:secret',
        'sign-in:learner@example.com:secret',
        'reset:learner@example.com',
        'sign-out',
      ]);
    },
  );

  test(
    'auth failures remain errors and do not become signed-out state',
    () async {
      final repository = _FakeAuthRepository()
        ..createAccountFailure = const AuthRepositoryException(
          AuthErrorCode.emailAlreadyInUse,
        );
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(() async {
        container.dispose();
        await repository.dispose();
      });

      final controller = container.read(authStateProvider.notifier);
      await expectLater(
        controller.createAccount(
          email: 'existing@example.com',
          password: 'secret',
        ),
        throwsA(isA<AuthRepositoryException>()),
      );

      final state = container.read(authStateProvider);
      expect(state.status, AuthStatus.loading);
      expect(state.errorCode, AuthErrorCode.emailAlreadyInUse);
    },
  );
}

Future<void> _flushStream() => Future<void>.delayed(Duration.zero);

class _FakeAuthRepository implements AuthRepository {
  final _authState = StreamController<AuthState>.broadcast();
  final List<String> actions = [];
  AuthRepositoryException? createAccountFailure;

  @override
  Stream<AuthState> watchAuthState() => _authState.stream;

  void emit(AuthState value) => _authState.add(value);

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    actions.add('create:$email:$password');
    if (createAccountFailure case final failure?) throw failure;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    actions.add('sign-in:$email:$password');
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    actions.add('reset:$email');
  }

  @override
  Future<void> signOut() async {
    actions.add('sign-out');
  }

  Future<void> dispose() => _authState.close();
}
