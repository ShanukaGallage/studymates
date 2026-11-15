import '../../../core/models/community_models.dart';
import 'profile_repository.dart';

abstract final class UserProfileFirestoreMapper {
  static Map<String, dynamic> toFirestore(UserProfile profile) {
    if (profile.displayName.trim().isEmpty) {
      throw const ProfileRepositoryException(
        ProfileRepositoryError.invalidData,
      );
    }

    return {
      'displayName': profile.displayName.trim(),
      'avatarId': profile.avatarId,
      'interestIds': profile.interestIds,
    };
  }

  /// Builds a profile using the document ID as its stable user ID.
  ///
  /// Missing optional fields are supported for older profile documents.
  static UserProfile fromFirestore({
    required String userId,
    required Map<String, dynamic> data,
  }) {
    final displayName = data['displayName'];
    if (displayName is! String || displayName.trim().isEmpty) {
      throw const ProfileRepositoryException(
        ProfileRepositoryError.malformedProfile,
      );
    }

    final avatarId = data['avatarId'];
    if (avatarId != null && avatarId is! String) {
      throw const ProfileRepositoryException(
        ProfileRepositoryError.malformedProfile,
      );
    }

    final interestIds = data['interestIds'];
    if (interestIds != null &&
        (interestIds is! List ||
            interestIds.any((value) => value is! String))) {
      throw const ProfileRepositoryException(
        ProfileRepositoryError.malformedProfile,
      );
    }

    return UserProfile(
      id: userId,
      displayName: displayName.trim(),
      avatarId: avatarId as String? ?? UserProfile.defaultAvatarId,
      interestIds: interestIds == null
          ? const []
          : List<String>.from(interestIds as List),
    );
  }
}
