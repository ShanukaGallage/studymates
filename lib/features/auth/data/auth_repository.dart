import '../domain/auth_state.dart';

abstract interface class AuthRepository {
  Stream<AuthState> watchAuthState();

  Future<void> createAccount({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signIn({required String email, required String password});

  Future<void> sendPasswordReset({required String email});

  Future<void> signOut();
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.code);

  final AuthErrorCode code;
}
