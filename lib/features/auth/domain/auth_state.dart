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

  /// Maps the currently available Firebase Auth identity fields.
  ///
  /// Until Firestore profile persistence is implemented, a non-empty Firebase
  /// Auth display name is the signal that the required name is available.
  factory AuthState.fromIdentity({String? userId, String? displayName}) {
    final stableId = userId?.trim();
    if (stableId == null || stableId.isEmpty) {
      return const AuthState.signedOut();
    }

    final name = displayName?.trim();
    if (name == null || name.isEmpty) {
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
