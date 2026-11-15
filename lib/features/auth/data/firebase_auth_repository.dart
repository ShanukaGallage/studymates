import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_state.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<AuthState> watchAuthState() async* {
    try {
      await for (final user in _firebaseAuth.userChanges()) {
        yield AuthState.fromIdentity(
          userId: user?.uid,
          displayName: user?.displayName,
        );
      }
    } on FirebaseAuthException catch (error) {
      throw _toRepositoryException(error);
    }
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) => _run(() async {
    await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  });

  @override
  Future<void> signIn({required String email, required String password}) =>
      _run(() async {
        await _firebaseAuth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      });

  @override
  Future<void> sendPasswordReset({required String email}) => _run(() async {
    await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  });

  @override
  Future<void> signOut() => _run(_firebaseAuth.signOut);

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      throw _toRepositoryException(error);
    }
  }

  AuthRepositoryException _toRepositoryException(FirebaseAuthException error) {
    final code = switch (error.code) {
      'email-already-in-use' => AuthErrorCode.emailAlreadyInUse,
      'invalid-email' => AuthErrorCode.invalidEmail,
      'weak-password' => AuthErrorCode.weakPassword,
      'user-disabled' => AuthErrorCode.userDisabled,
      'user-not-found' => AuthErrorCode.userNotFound,
      'wrong-password' => AuthErrorCode.wrongPassword,
      'invalid-credential' => AuthErrorCode.invalidCredential,
      'too-many-requests' => AuthErrorCode.tooManyRequests,
      'network-request-failed' => AuthErrorCode.networkRequestFailed,
      'operation-not-allowed' => AuthErrorCode.operationNotAllowed,
      _ => AuthErrorCode.unknown,
    };
    return AuthRepositoryException(code);
  }
}
