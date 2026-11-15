import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/community_models.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../data/firestore_profile_repository.dart';
import '../../data/profile_repository.dart';

final currentProfileProvider = StreamProvider<UserProfile?>((ref) {
  // Rebuild and cancel the previous stream when the signed-in UID changes.
  final userId = ref.watch(
    authStateProvider.select((identity) => identity.userId),
  );
  if (userId == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watchCurrentProfile();
});

final profileMutationProvider =
    NotifierProvider<ProfileMutationController, AsyncValue<UserProfile?>>(
      ProfileMutationController.new,
    );

class ProfileMutationController extends Notifier<AsyncValue<UserProfile?>> {
  @override
  AsyncValue<UserProfile?> build() => const AsyncData(null);

  Future<UserProfile> createProfile({required String displayName}) async {
    state = const AsyncLoading();
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .createCurrentProfile(displayName: displayName);
      state = AsyncData(profile);
      return profile;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<UserProfile> updateProfile({
    required UserProfile existingProfile,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .updateCurrentProfile(
            displayName: displayName,
            avatarId: existingProfile.avatarId,
            interestIds: existingProfile.interestIds,
          );
      state = AsyncData(profile);
      return profile;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

String profileErrorMessage(Object error) {
  final repositoryError = error is ProfileRepositoryException
      ? error.code
      : ProfileRepositoryError.unknown;
  return switch (repositoryError) {
    ProfileRepositoryError.notAuthenticated =>
      'Your session has ended. Please sign in again.',
    ProfileRepositoryError.profileAlreadyExists =>
      'A profile already exists. Open it to make changes.',
    ProfileRepositoryError.profileNotFound =>
      'Your profile could not be found. Please set it up again.',
    ProfileRepositoryError.permissionDenied =>
      'You do not have permission to access this profile.',
    ProfileRepositoryError.unavailable =>
      'We could not reach your profile. Check your connection and try again.',
    ProfileRepositoryError.invalidData => 'Enter a valid display name.',
    ProfileRepositoryError.malformedProfile =>
      'We could not read your saved profile. Please try again later.',
    ProfileRepositoryError.unknown =>
      'We could not save your profile. Please try again.',
  };
}
