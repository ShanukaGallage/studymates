enum AuthStatus { loading, signedOut, incompleteProfile, ready }

enum AuthErrorCode {
  emailAlreadyInUse,
  invalidEmail,
  weakPassword,
  userDisabled,
  userNotFound,
  wrongPassword,
  invalidCredential,
  tooManyRequests,
  networkRequestFailed,
  operationNotAllowed,
  unavailable,
  unknown,
}

/// Authentication identity state, without duplicating the shared UserProfile.
class AuthState {
  const AuthState._({
    required this.status,
    this.userId,
    this.displayName,
    this.errorCode,
  });

  const AuthState.loading() : this._(status: AuthStatus.loading);

  const AuthState.signedOut({AuthErrorCode? errorCode})
    : this._(status: AuthStatus.signedOut, errorCode: errorCode);

  const AuthState.incompleteProfile({
    required String userId,
    AuthErrorCode? errorCode,
  }) : this._(
         status: AuthStatus.incompleteProfile,
         userId: userId,
         errorCode: errorCode,
       );

  const AuthState.ready({
    required String userId,
    required String displayName,
    AuthErrorCode? errorCode,
  }) : this._(
         status: AuthStatus.ready,
         userId: userId,
         displayName: displayName,
         errorCode: errorCode,
       );

  /// Resolves readiness from persisted profile data, never Auth metadata alone.
  factory AuthState.fromPersistedProfile({
    required String userId,
    String? displayName,
  }) {
    final stableId = userId.trim();
    final name = displayName?.trim();
    if (stableId.isEmpty || name == null || name.isEmpty) {
      return AuthState.incompleteProfile(userId: stableId);
    }
    return AuthState.ready(userId: stableId, displayName: name);
  }

  final AuthStatus status;
  final String? userId;
  final String? displayName;
  final AuthErrorCode? errorCode;

  AuthState withError(AuthErrorCode code) => AuthState._(
    status: status,
    userId: userId,
    displayName: displayName,
    errorCode: code,
  );
}
