import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studymates/core/models/community_models.dart';
import 'package:studymates/features/auth/data/firebase_auth_repository.dart';
import 'package:studymates/features/auth/domain/auth_state.dart';
import 'package:studymates/features/profile/data/profile_repository.dart';

void main() {
  group('FirebaseAuthRepository', () {
    test('restored signed-out identity resolves as signed out', () async {
      final repository = FirebaseAuthRepository(
        _FakeIdentityClient(),
        _FakeProfileRepository(),
      );

      final state = await repository.watchAuthState().first;

      expect(state.status, AuthStatus.signedOut);
    });

    test(
      'registration creates the persisted profile for the Firebase UID',
      () async {
        final identity = _FakeIdentityClient();
        final profiles = _FakeProfileRepository();
        final repository = FirebaseAuthRepository(identity, profiles);

        await repository.createAccount(
          email: ' learner@example.com ',
          password: 'secret',
          displayName: '  Learner  ',
        );

        expect(identity.actions, ['create:learner@example.com:secret']);
        expect(profiles.createdUserId, 'firebase-uid');
        expect(profiles.createdName, 'Learner');
      },
    );

    test(
      'waits for Firestore profile retrieval before reporting ready',
      () async {
        final identity = _FakeIdentityClient()
          ..emit(
            const AuthIdentity(uid: 'firebase-uid', displayName: 'Old name'),
          );
        final profileGate = Completer<UserProfile?>();
        final profiles = _FakeProfileRepository()..readGate = profileGate;
        final repository = FirebaseAuthRepository(identity, profiles);

        var completed = false;
        final stateFuture = repository.watchAuthState().first.then((state) {
          completed = true;
          return state;
        });
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);

        profileGate.complete(
          UserProfile(id: 'firebase-uid', displayName: 'Saved name'),
        );
        final state = await stateFuture;

        expect(state.status, AuthStatus.ready);
        expect(state.userId, 'firebase-uid');
        expect(state.displayName, 'Saved name');
        expect(identity.actions, ['display-name:Saved name']);
      },
    );

    test(
      'an authenticated account without a Firestore profile is incomplete',
      () async {
        final identity = _FakeIdentityClient()
          ..emit(
            const AuthIdentity(uid: 'firebase-uid', displayName: 'Auth name'),
          );
        final repository = FirebaseAuthRepository(
          identity,
          _FakeProfileRepository(),
        );

        final state = await repository.watchAuthState().first;

        expect(state.status, AuthStatus.incompleteProfile);
        expect(state.userId, 'firebase-uid');
        expect(state.displayName, isNull);
      },
    );

    test(
      'login, logout and reset delegate to Firebase identity client',
      () async {
        final identity = _FakeIdentityClient();
        final repository = FirebaseAuthRepository(
          identity,
          _FakeProfileRepository(),
        );

        await repository.signIn(email: ' learner@example.com ', password: 'pw');
        await repository.sendPasswordReset(email: ' learner@example.com ');
        await repository.signOut();

        expect(identity.actions, [
          'sign-in:learner@example.com:pw',
          'reset:learner@example.com',
          'sign-out',
        ]);
      },
    );
  });
}

class _FakeIdentityClient implements AuthIdentityClient {
  final states = StreamController<AuthIdentity?>.broadcast();
  final actions = <String>[];
  AuthIdentity? current;

  void emit(AuthIdentity? identity) {
    current = identity;
    states.add(identity);
  }

  @override
  Stream<AuthIdentity?> watchAuthState() async* {
    yield current;
    yield* states.stream;
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    actions.add('create:$email:$password');
    emit(const AuthIdentity(uid: 'firebase-uid'));
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    actions.add('sign-in:$email:$password');
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    actions.add('reset:$email');
  }

  @override
  Future<void> signOut() async {
    actions.add('sign-out');
    emit(null);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    actions.add('display-name:$displayName');
    final identity = current;
    if (identity != null) {
      emit(AuthIdentity(uid: identity.uid, displayName: displayName));
    }
  }
}

class _FakeProfileRepository implements ProfileRepository {
  String? createdUserId;
  String? createdName;
  Completer<UserProfile?>? readGate;
  UserProfile? profile;

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
    createdUserId = 'firebase-uid';
    createdName = displayName;
    profile = UserProfile(id: createdUserId!, displayName: displayName);
    return profile!;
  }

  @override
  Future<UserProfile?> getCurrentProfile() =>
      readGate?.future ?? Future.value(profile);

  @override
  Stream<UserProfile?> watchCurrentProfile() => Stream.value(profile);

  @override
  Future<UserProfile> updateCurrentProfile({
    required String displayName,
    String avatarId = UserProfile.defaultAvatarId,
    List<String> interestIds = const [],
    String? institution,
    String? programme,
    String? yearOfStudy,
    String? bio,
  }) async => UserProfile(id: 'firebase-uid', displayName: displayName);
}
