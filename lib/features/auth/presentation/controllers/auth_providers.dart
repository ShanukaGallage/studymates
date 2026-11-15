import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../data/firebase_auth_repository.dart';
import '../../domain/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(FirebaseAuth.instance),
);

final authStateProvider = NotifierProvider<AuthStateController, AuthState>(
  AuthStateController.new,
);

class AuthStateController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final subscription = ref
        .watch(authRepositoryProvider)
        .watchAuthState()
        .listen(_setIdentity, onError: _setStreamError);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return const AuthState.loading();
  }

  Future<void> createAccount({
    required String email,
    required String password,
  }) => _run(
    () => ref
        .read(authRepositoryProvider)
        .createAccount(email: email, password: password),
  );

  Future<void> signIn({required String email, required String password}) =>
      _run(
        () => ref
            .read(authRepositoryProvider)
            .signIn(email: email, password: password),
      );

  Future<void> sendPasswordReset({required String email}) => _run(
    () => ref.read(authRepositoryProvider).sendPasswordReset(email: email),
  );

  Future<void> signOut() =>
      _run(() => ref.read(authRepositoryProvider).signOut());

  void _setIdentity(AuthState identity) {
    state = identity;
  }

  void _setStreamError(Object error, StackTrace stackTrace) {
    state = state.withError(
      error is AuthRepositoryException ? error.code : AuthErrorCode.unavailable,
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      state = state.withError(
        error is AuthRepositoryException ? error.code : AuthErrorCode.unknown,
      );
      rethrow;
    }
  }
}
