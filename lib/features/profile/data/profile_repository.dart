import '../../../core/models/community_models.dart';

abstract interface class ProfileRepository {
  /// Watches the signed-in user's profile. A missing document emits `null`.
  Stream<UserProfile?> watchCurrentProfile();

  /// Reads the signed-in user's profile. A missing document returns `null`.
  Future<UserProfile?> getCurrentProfile();

  /// Creates the signed-in user's profile without replacing an existing one.
  Future<UserProfile> createCurrentProfile({
    required String displayName,
    String avatarId = UserProfile.defaultAvatarId,
    List<String> interestIds = const [],
    String? institution,
    String? programme,
    String? yearOfStudy,
    String? bio,
  });

  /// Replaces the signed-in user's editable profile fields.
  /// Empty/null optional values clear the saved value.
  ///
  /// Fails with [ProfileRepositoryError.profileNotFound] if no profile exists.
  Future<UserProfile> updateCurrentProfile({
    required String displayName,
    String avatarId = UserProfile.defaultAvatarId,
    List<String> interestIds = const [],
    String? institution,
    String? programme,
    String? yearOfStudy,
    String? bio,
  });
}

/// Small document-store boundary so repository behavior can be tested without
/// Firebase initialization or another mocking dependency.
abstract interface class ProfileDocumentStore {
  Future<Map<String, dynamic>?> getDocument(String userId);

  Stream<Map<String, dynamic>?> watchDocument(String userId);

  Future<void> createDocumentIfAbsent(String userId, Map<String, dynamic> data);

  Future<void> updateExistingDocument(String userId, Map<String, dynamic> data);
}

enum ProfileRepositoryError {
  notAuthenticated,
  profileAlreadyExists,
  profileNotFound,
  permissionDenied,
  unavailable,
  invalidData,
  malformedProfile,
  unknown,
}

class ProfileRepositoryException implements Exception {
  const ProfileRepositoryException(this.code);

  final ProfileRepositoryError code;

  @override
  String toString() => 'ProfileRepositoryException($code)';
}
