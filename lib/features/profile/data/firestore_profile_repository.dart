import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/community_models.dart';
import 'profile_repository.dart';
import 'user_profile_firestore_mapper.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => FirestoreProfileRepository(),
);

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    ProfileDocumentStore? documentStore,
    String? Function()? currentUserId,
    Future<void> Function(String displayName)? updateAuthDisplayName,
  }) : _currentUserId =
           currentUserId ??
           (() => (firebaseAuth ?? FirebaseAuth.instance).currentUser?.uid),
       _documents =
           documentStore ??
           _FirestoreProfileDocumentStore(
             firestore ?? FirebaseFirestore.instance,
           ),
       _updateAuthDisplayName =
           updateAuthDisplayName ??
           ((displayName) async {
             final user = (firebaseAuth ?? FirebaseAuth.instance).currentUser;
             if (user != null && user.displayName?.trim() != displayName) {
               await user.updateDisplayName(displayName);
             }
           });

  static const collectionName = 'users';

  final String? Function() _currentUserId;
  final ProfileDocumentStore _documents;
  final Future<void> Function(String displayName) _updateAuthDisplayName;

  @override
  Future<UserProfile> createCurrentProfile({
    required String displayName,
    String avatarId = UserProfile.defaultAvatarId,
    List<String> interestIds = const [],
    String? institution,
    String? programme,
    String? yearOfStudy,
    String? bio,
  }) async {
    final profile = _newProfile(
      displayName: displayName,
      avatarId: avatarId,
      interestIds: interestIds,
      institution: institution,
      programme: programme,
      yearOfStudy: yearOfStudy,
      bio: bio,
    );
    try {
      await _documents.createDocumentIfAbsent(
        profile.id,
        UserProfileFirestoreMapper.toFirestore(profile),
      );
      await _updateAuthDisplayName(profile.displayName);
    } on FirebaseException catch (error) {
      throw _mapFirebaseError(error);
    }
    return profile;
  }

  @override
  Future<UserProfile?> getCurrentProfile() async {
    final userId = _requireCurrentUserId();
    try {
      final data = await _documents.getDocument(userId);
      return data == null
          ? null
          : UserProfileFirestoreMapper.fromFirestore(
              userId: userId,
              data: data,
            );
    } on FirebaseException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  @override
  Stream<UserProfile?> watchCurrentProfile() async* {
    final userId = _requireCurrentUserId();
    try {
      await for (final data in _documents.watchDocument(userId)) {
        yield data == null
            ? null
            : UserProfileFirestoreMapper.fromFirestore(
                userId: userId,
                data: data,
              );
      }
    } on FirebaseException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  @override
  Future<UserProfile> updateCurrentProfile({
    required String displayName,
    String avatarId = UserProfile.defaultAvatarId,
    List<String> interestIds = const [],
    String? institution,
    String? programme,
    String? yearOfStudy,
    String? bio,
  }) async {
    final profile = _newProfile(
      displayName: displayName,
      avatarId: avatarId,
      interestIds: interestIds,
      institution: institution,
      programme: programme,
      yearOfStudy: yearOfStudy,
      bio: bio,
    );
    try {
      await _documents.updateExistingDocument(
        profile.id,
        UserProfileFirestoreMapper.toFirestore(profile),
      );
      await _updateAuthDisplayName(profile.displayName);
    } on FirebaseException catch (error) {
      throw _mapFirebaseError(error);
    }
    return profile;
  }

  UserProfile _newProfile({
    required String displayName,
    required String avatarId,
    required List<String> interestIds,
    String? institution,
    String? programme,
    String? yearOfStudy,
    String? bio,
  }) {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      throw const ProfileRepositoryException(
        ProfileRepositoryError.invalidData,
      );
    }
    return UserProfile(
      id: _requireCurrentUserId(),
      displayName: normalizedName,
      avatarId: avatarId,
      interestIds: interestIds,
      institution: _optionalText(institution),
      programme: _optionalText(programme),
      yearOfStudy: _optionalText(yearOfStudy),
      bio: _optionalText(bio),
    );
  }

  String? _optionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _requireCurrentUserId() {
    final userId = _currentUserId()?.trim();
    if (userId == null || userId.isEmpty) {
      throw const ProfileRepositoryException(
        ProfileRepositoryError.notAuthenticated,
      );
    }
    return userId;
  }

  ProfileRepositoryException _mapFirebaseError(FirebaseException error) =>
      switch (error.code) {
        'permission-denied' => const ProfileRepositoryException(
          ProfileRepositoryError.permissionDenied,
        ),
        'unauthenticated' => const ProfileRepositoryException(
          ProfileRepositoryError.notAuthenticated,
        ),
        'already-exists' => const ProfileRepositoryException(
          ProfileRepositoryError.profileAlreadyExists,
        ),
        'not-found' => const ProfileRepositoryException(
          ProfileRepositoryError.profileNotFound,
        ),
        'unavailable' || 'deadline-exceeded' || 'network-request-failed' =>
          const ProfileRepositoryException(ProfileRepositoryError.unavailable),
        'invalid-argument' => const ProfileRepositoryException(
          ProfileRepositoryError.invalidData,
        ),
        _ => const ProfileRepositoryException(ProfileRepositoryError.unknown),
      };
}

class _FirestoreProfileDocumentStore implements ProfileDocumentStore {
  _FirestoreProfileDocumentStore(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _document(String userId) => _firestore
      .collection(FirestoreProfileRepository.collectionName)
      .doc(userId);

  @override
  Future<Map<String, dynamic>?> getDocument(String userId) async {
    final snapshot = await _document(userId).get();
    return snapshot.data();
  }

  @override
  Stream<Map<String, dynamic>?> watchDocument(String userId) =>
      _document(userId).snapshots().map((snapshot) => snapshot.data());

  @override
  Future<void> createDocumentIfAbsent(
    String userId,
    Map<String, dynamic> data,
  ) => _firestore.runTransaction((transaction) async {
    final document = _document(userId);
    final snapshot = await transaction.get(document);
    if (snapshot.exists) {
      throw const ProfileRepositoryException(
        ProfileRepositoryError.profileAlreadyExists,
      );
    }
    transaction.set(document, data);
  });

  @override
  Future<void> updateExistingDocument(
    String userId,
    Map<String, dynamic> data,
  ) => _firestore.runTransaction((transaction) async {
    final document = _document(userId);
    final snapshot = await transaction.get(document);
    if (!snapshot.exists) {
      throw const ProfileRepositoryException(
        ProfileRepositoryError.profileNotFound,
      );
    }
    transaction.update(document, data);
  });
}
