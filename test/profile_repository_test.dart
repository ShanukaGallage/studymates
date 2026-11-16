import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/core/models/community_models.dart';
import 'package:studymates/features/profile/data/firestore_profile_repository.dart';
import 'package:studymates/features/profile/data/profile_repository.dart';

void main() {
  group('FirestoreProfileRepository', () {
    late _FakeProfileDocumentStore store;
    late FirestoreProfileRepository repository;
    final syncedDisplayNames = <String>[];

    setUp(() {
      store = _FakeProfileDocumentStore();
      syncedDisplayNames.clear();
      repository = FirestoreProfileRepository(
        documentStore: store,
        currentUserId: () => 'firebase-uid-1',
        updateAuthDisplayName: (name) async => syncedDisplayNames.add(name),
      );
    });

    test('creates at the authenticated UID path with model defaults', () async {
      final profile = await repository.createCurrentProfile(
        displayName: '  Learner  ',
      );

      expect(profile.id, 'firebase-uid-1');
      expect(profile.displayName, 'Learner');
      expect(profile.avatarId, 'default');
      expect(profile.interestIds, isEmpty);
      expect(store.documents.keys, ['firebase-uid-1']);
      expect(store.documents['firebase-uid-1'], {
        'displayName': 'Learner',
        'avatarId': 'default',
        'interestIds': <String>[],
        'institution': null,
        'programme': null,
        'yearOfStudy': null,
        'bio': null,
      });
    });

    test('does not overwrite an existing profile on create', () async {
      store.documents['firebase-uid-1'] = {
        'displayName': 'Existing name',
        'avatarId': 'mint',
        'interestIds': <String>['iot'],
      };

      await expectLater(
        repository.createCurrentProfile(displayName: 'Replacement'),
        throwsA(
          isA<ProfileRepositoryException>().having(
            (error) => error.code,
            'code',
            ProfileRepositoryError.profileAlreadyExists,
          ),
        ),
      );
      expect(
        store.documents['firebase-uid-1']!['displayName'],
        'Existing name',
      );
    });

    test(
      'returns null for a missing profile and uses document ID on read',
      () async {
        expect(await repository.getCurrentProfile(), isNull);

        store.documents['firebase-uid-1'] = {
          'displayName': 'Ari',
          // Optional fields missing from older documents use model defaults.
        };
        final profile = await repository.getCurrentProfile();

        expect(profile, isA<UserProfile>());
        expect(profile!.id, 'firebase-uid-1');
        expect(profile.displayName, 'Ari');
        expect(profile.avatarId, 'default');
        expect(profile.interestIds, isEmpty);
      },
    );

    test('reports malformed Firestore profile data distinctly', () async {
      store.documents['firebase-uid-1'] = {
        'displayName': '   ',
        'avatarId': 'default',
        'interestIds': <String>[],
      };

      await expectLater(
        repository.getCurrentProfile(),
        throwsA(
          isA<ProfileRepositoryException>().having(
            (error) => error.code,
            'code',
            ProfileRepositoryError.malformedProfile,
          ),
        ),
      );
    });

    test('watches missing and present profile snapshots', () async {
      expect(await repository.watchCurrentProfile().first, isNull);

      store.documents['firebase-uid-1'] = {'displayName': 'Watched learner'};
      final profile = await repository.watchCurrentProfile().first;

      expect(profile?.id, 'firebase-uid-1');
      expect(profile?.displayName, 'Watched learner');
    });

    test('updates an existing profile', () async {
      await repository.createCurrentProfile(displayName: 'Before');

      final updated = await repository.updateCurrentProfile(
        displayName: 'After',
        avatarId: 'amber',
        interestIds: ['design'],
      );

      expect(updated, isA<UserProfile>());
      expect(updated.id, 'firebase-uid-1');
      expect(updated.displayName, 'After');
      expect(updated.avatarId, 'amber');
      expect(updated.interestIds, ['design']);
      expect(store.documents['firebase-uid-1']!['displayName'], 'After');
      expect(syncedDisplayNames, ['Before', 'After']);
    });

    test('saves, reloads and clears every optional detail', () async {
      await repository.createCurrentProfile(
        displayName: 'Learner',
        institution: '  University of Kelaniya  ',
        interestIds: ['Software engineering', 'Design'],
      );
      final created = await repository.getCurrentProfile();
      expect(created!.institution, 'University of Kelaniya');
      expect(created.interestIds, ['Software engineering', 'Design']);

      await repository.updateCurrentProfile(
        displayName: 'Learner',
        institution: created.institution,
        programme: '  BSc IT  ',
        yearOfStudy: 'Year 2',
        bio: '  Learning together.  ',
        interestIds: created.interestIds,
      );
      final saved = await repository.getCurrentProfile();
      expect(saved!.programme, 'BSc IT');
      expect(saved.yearOfStudy, 'Year 2');
      expect(saved.bio, 'Learning together.');

      // Optional text is explicitly cleared, rather than skipped in update().
      await repository.updateCurrentProfile(
        displayName: 'Learner',
        institution: '  ',
        programme: '',
        bio: '',
      );
      final cleared = await repository.getCurrentProfile();
      expect(cleared!.institution, isNull);
      expect(cleared.programme, isNull);
      expect(cleared.yearOfStudy, isNull);
      expect(cleared.bio, isNull);
      expect(cleared.interestIds, isEmpty);
    });

    test(
      'edits a legacy name-only profile without replacing other data',
      () async {
        store.documents['firebase-uid-1'] = {
          'displayName': 'Legacy learner',
          'unrelatedMetadata': 'retained',
        };
        final legacy = await repository.getCurrentProfile();
        expect(legacy!.institution, isNull);
        expect(legacy.programme, isNull);
        expect(legacy.yearOfStudy, isNull);
        expect(legacy.bio, isNull);
        await repository.updateCurrentProfile(
          displayName: legacy.displayName,
          institution: 'School',
        );
        final updated = await repository.getCurrentProfile();
        expect(updated!.institution, 'School');
        expect(
          store.documents['firebase-uid-1']!['unrelatedMetadata'],
          'retained',
        );
      },
    );

    test('profile data remains readable after repository recreation', () async {
      await repository.createCurrentProfile(displayName: 'Persisted learner');
      final restartedRepository = FirestoreProfileRepository(
        documentStore: store,
        currentUserId: () => 'firebase-uid-1',
        updateAuthDisplayName: (_) async {},
      );

      final restored = await restartedRepository.getCurrentProfile();

      expect(restored?.id, 'firebase-uid-1');
      expect(restored?.displayName, 'Persisted learner');
    });

    test('fails when updating a profile that does not exist', () async {
      await expectLater(
        repository.updateCurrentProfile(displayName: 'New name'),
        throwsA(
          isA<ProfileRepositoryException>().having(
            (error) => error.code,
            'code',
            ProfileRepositoryError.profileNotFound,
          ),
        ),
      );
    });

    test('rejects an empty or whitespace-only display name', () async {
      for (final name in ['', '  \n ']) {
        await expectLater(
          repository.createCurrentProfile(displayName: name),
          throwsA(
            isA<ProfileRepositoryException>().having(
              (error) => error.code,
              'code',
              ProfileRepositoryError.invalidData,
            ),
          ),
        );
      }
      expect(store.documents, isEmpty);
    });

    test('distinguishes permission and network failures', () async {
      store.failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      await expectLater(
        repository.getCurrentProfile(),
        throwsA(
          isA<ProfileRepositoryException>().having(
            (error) => error.code,
            'code',
            ProfileRepositoryError.permissionDenied,
          ),
        ),
      );

      store.failure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await expectLater(
        repository.getCurrentProfile(),
        throwsA(
          isA<ProfileRepositoryException>().having(
            (error) => error.code,
            'code',
            ProfileRepositoryError.unavailable,
          ),
        ),
      );
    });

    test(
      'requires an authenticated UID for profile access and writes',
      () async {
        final signedOutRepository = FirestoreProfileRepository(
          documentStore: store,
          currentUserId: () => null,
        );

        await expectLater(
          signedOutRepository.createCurrentProfile(displayName: 'Learner'),
          throwsA(
            isA<ProfileRepositoryException>().having(
              (error) => error.code,
              'code',
              ProfileRepositoryError.notAuthenticated,
            ),
          ),
        );
        await expectLater(
          signedOutRepository.getCurrentProfile(),
          throwsA(isA<ProfileRepositoryException>()),
        );
      },
    );
  });

  test(
    'UserProfile defaults optional fields and keeps interests immutable',
    () {
      final profile = UserProfile(id: 'uid', displayName: 'Learner');

      expect(profile.avatarId, 'default');
      expect(profile.interestIds, isEmpty);
      expect(() => profile.interestIds.add('iot'), throwsUnsupportedError);
    },
  );
}

class _FakeProfileDocumentStore implements ProfileDocumentStore {
  final documents = <String, Map<String, dynamic>>{};
  FirebaseException? failure;

  void _throwFailure() {
    if (failure case final error?) throw error;
  }

  @override
  Future<Map<String, dynamic>?> getDocument(String userId) async {
    _throwFailure();
    final document = documents[userId];
    return document == null ? null : Map.of(document);
  }

  @override
  Stream<Map<String, dynamic>?> watchDocument(String userId) {
    _throwFailure();
    final document = documents[userId];
    return Stream.value(document == null ? null : Map.of(document));
  }

  @override
  Future<void> createDocumentIfAbsent(
    String userId,
    Map<String, dynamic> data,
  ) async {
    _throwFailure();
    if (documents.containsKey(userId)) {
      throw const ProfileRepositoryException(
        ProfileRepositoryError.profileAlreadyExists,
      );
    }
    documents[userId] = Map.of(data);
  }

  @override
  Future<void> updateExistingDocument(
    String userId,
    Map<String, dynamic> data,
  ) async {
    _throwFailure();
    if (!documents.containsKey(userId)) {
      throw const ProfileRepositoryException(
        ProfileRepositoryError.profileNotFound,
      );
    }
    documents[userId]!.addAll(data);
  }
}
