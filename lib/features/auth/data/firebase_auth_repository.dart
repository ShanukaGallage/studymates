import 'package:firebase_auth/firebase_auth.dart';

import '../../profile/data/profile_repository.dart';
import '../domain/auth_state.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._identity, this._profiles);

  final AuthIdentityClient _identity;
  final ProfileRepository _profiles;

  @override
  Stream<AuthState> watchAuthState() async* {
    try {
      await for (final user in _identity.watchAuthState().asyncMap((
        user,
      ) async {
        if (user == null) return const AuthState.signedOut();

        // A Firebase Auth name is not proof that the Firestore profile exists.
        final profile = await _profiles.getCurrentProfile();
        if (profile == null) {
          return AuthState.incompleteProfile(userId: user.uid);
        }
        if (user.displayName?.trim() != profile.displayName) {
          await _identity.updateDisplayName(profile.displayName);
        }
        return AuthState.fromPersistedProfile(
          userId: user.uid,
          displayName: profile.displayName,
        );
      })) {
        yield user;
      }
    } on FirebaseAuthException catch (error) {
      throw _toRepositoryException(error);
    } on ProfileRepositoryException catch (error) {
      throw AuthRepositoryException(
        error.code == ProfileRepositoryError.unavailable
            ? AuthErrorCode.unavailable
            : AuthErrorCode.unknown,
      );
    }
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
    required String displayName,
  }) => _run(() async {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      throw const AuthRepositoryException(AuthErrorCode.unknown);
    }
    await _identity.createAccount(email: email.trim(), password: password);
    await _profiles.createCurrentProfile(displayName: normalizedName);
  });

  @override
  Future<void> signIn({required String email, required String password}) =>
      _run(() async {
        await _identity.signIn(email: email.trim(), password: password);
      });

  @override
  Future<void> sendPasswordReset({required String email}) =>
      _run(() => _identity.sendPasswordReset(email: email.trim()));

  @override
  Future<void> signOut() => _run(_identity.signOut);

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      throw _toRepositoryException(error);
    } on ProfileRepositoryException catch (error) {
      throw AuthRepositoryException(
        error.code == ProfileRepositoryError.unavailable
            ? AuthErrorCode.unavailable
            : AuthErrorCode.unknown,
      );
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

/// Narrow identity boundary keeps Firebase calls testable without a device.
abstract interface class AuthIdentityClient {
  Stream<AuthIdentity?> watchAuthState();
  Future<void> createAccount({required String email, required String password});
  Future<void> signIn({required String email, required String password});
  Future<void> sendPasswordReset({required String email});
  Future<void> signOut();
  Future<void> updateDisplayName(String displayName);
}

class AuthIdentity {
  const AuthIdentity({required this.uid, this.displayName});
  final String uid;
  final String? displayName;
}

class FirebaseAuthIdentityClient implements AuthIdentityClient {
  FirebaseAuthIdentityClient(this._firebaseAuth);
  final FirebaseAuth _firebaseAuth;

  @override
  Stream<AuthIdentity?> watchAuthState() => _firebaseAuth.userChanges().map(
    (user) => user == null
        ? null
        : AuthIdentity(uid: user.uid, displayName: user.displayName),
  );

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> sendPasswordReset({required String email}) =>
      _firebaseAuth.sendPasswordResetEmail(email: email);

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  @override
  Future<void> updateDisplayName(String displayName) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthRepositoryException(AuthErrorCode.unknown);
    }
    await user.updateDisplayName(displayName);
  }
}
