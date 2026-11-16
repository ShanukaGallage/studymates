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
      // Explicit nulls clear these fields in transaction.update as well as set.
      'institution': _optionalText(profile.institution),
      'programme': _optionalText(profile.programme),
      'yearOfStudy': _optionalText(profile.yearOfStudy),
      'bio': _optionalText(profile.bio),
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
      institution: _readOptionalText(data['institution']),
      programme: _readOptionalText(data['programme']),
      yearOfStudy: _readOptionalText(data['yearOfStudy']),
      bio: _readOptionalText(data['bio']),
    );
  }

  static String? _readOptionalText(Object? value) {
    if (value != null && value is! String) {
      throw const ProfileRepositoryException(
        ProfileRepositoryError.malformedProfile,
      );
    }
    return _optionalText(value as String?);
  }

  static String? _optionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
