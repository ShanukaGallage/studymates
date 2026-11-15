import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/core/models/community_models.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/core/widgets/avatar_badge.dart';
import 'package:studymates/features/auth/domain/auth_state.dart';
import 'package:studymates/features/auth/presentation/controllers/auth_providers.dart';
import 'package:studymates/features/profile/data/firestore_profile_repository.dart';
import 'package:studymates/features/profile/data/profile_repository.dart';
import 'package:studymates/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:studymates/features/profile/presentation/screens/profile_setup_screen.dart';
import 'package:studymates/features/profile/presentation/screens/profile_view_screen.dart';

void main() {
  group('ProfileSetupScreen', () {
    testWidgets('requires a non-empty display name', (tester) async {
      final repository = _FakeProfileRepository();
      await _pump(tester, const ProfileSetupScreen(), repository);

      await tester.tap(find.text('Save profile'));
      await tester.pump();

      expect(find.text('Enter your display name.'), findsOneWidget);
      expect(repository.createCount, 0);
    });

    testWidgets('shows loading and prevents repeated profile creation', (
      tester,
    ) async {
      final repository = _FakeProfileRepository()
        ..createGate = Completer<void>();
      await _pump(tester, const ProfileSetupScreen(), repository);
      await tester.enterText(find.byType(TextFormField), 'Poojani');

      await tester.tap(find.text('Save profile'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(repository.createCount, 1);

      repository.createGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Your profile is ready.'), findsOneWidget);
    });

    testWidgets('creates profile and calls completion callback', (
      tester,
    ) async {
      final repository = _FakeProfileRepository();
      UserProfile? completedProfile;
      await _pump(
        tester,
        ProfileSetupScreen(onComplete: (profile) => completedProfile = profile),
        repository,
      );
      await tester.enterText(find.byType(TextFormField), '  Poojani  ');

      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();

      expect(repository.createdDisplayName, 'Poojani');
      expect(completedProfile?.id, 'current-user-uid');
      expect(completedProfile?.displayName, 'Poojani');
      expect(completedProfile?.avatarId, 'default');
      expect(completedProfile?.interestIds, isEmpty);
    });

    testWidgets('shows a friendly error when profile creation fails', (
      tester,
    ) async {
      final repository = _FakeProfileRepository()
        ..createFailure = const ProfileRepositoryException(
          ProfileRepositoryError.unavailable,
        );
      await _pump(tester, const ProfileSetupScreen(), repository);
      await tester.enterText(find.byType(TextFormField), 'Poojani');

      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'We could not reach your profile. Check your connection and try again.',
        ),
        findsOneWidget,
      );
    });
  });

  group('ProfileViewScreen', () {
    testWidgets('shows loading then displays the observed profile', (
      tester,
    ) async {
      final repository = _FakeProfileRepository();
      final profileStream = StreamController<UserProfile?>();
      repository.watchStream = profileStream.stream;
      await _pump(tester, const ProfileViewScreen(), repository);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      profileStream.add(_sampleProfile());
      await tester.pump();
      await tester.pump();
      expect(find.text('Poojani'), findsOneWidget);
      expect(find.byType(AvatarBadge), findsOneWidget);

      await profileStream.close();
      await tester.pumpAndSettle();
    });

    testWidgets('offers setup when the profile document is missing', (
      tester,
    ) async {
      final repository = _FakeProfileRepository();
      var setupTapped = false;
      await _pump(
        tester,
        ProfileViewScreen(onSetUpProfile: () => setupTapped = true),
        repository,
      );

      await tester.pumpAndSettle();
      expect(find.text('Profile not set up'), findsOneWidget);
      await tester.tap(find.text('Set up profile'));
      expect(setupTapped, isTrue);
    });

    testWidgets('resubscribes on account change and hides prior profile', (
      tester,
    ) async {
      final repository = _FakeProfileRepository();
      final firstStream = StreamController<UserProfile?>.broadcast();
      final secondStream = StreamController<UserProfile?>.broadcast();
      repository.watchResponses = [firstStream.stream, secondStream.stream];
      final identityController = _TestAuthStateController(
        const AuthState.ready(userId: 'user-a', displayName: 'User A'),
      );
      await _pump(
        tester,
        const ProfileViewScreen(),
        repository,
        authController: identityController,
      );

      firstStream.add(_sampleProfile(id: 'user-a', displayName: 'User A'));
      await tester.pump();
      await tester.pump();
      expect(find.text('User A'), findsOneWidget);

      identityController.emit(
        const AuthState.ready(userId: 'user-b', displayName: 'User B'),
      );
      await tester.pump();
      await tester.pump();

      expect(repository.watchCount, 2);
      expect(find.text('User A'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      secondStream.add(_sampleProfile(id: 'user-b', displayName: 'User B'));
      await tester.pump();
      await tester.pump();
      expect(find.text('User B'), findsOneWidget);

      await firstStream.close();
      await secondStream.close();
    });

    testWidgets('shows a recoverable error for profile read failures', (
      tester,
    ) async {
      final repository = _FakeProfileRepository()
        ..watchFailure = const ProfileRepositoryException(
          ProfileRepositoryError.permissionDenied,
        );
      await _pump(tester, const ProfileViewScreen(), repository);
      await tester.pumpAndSettle();

      expect(
        find.text('You do not have permission to access this profile.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows a read-specific message for malformed data', (
      tester,
    ) async {
      final repository = _FakeProfileRepository()
        ..watchFailure = const ProfileRepositoryException(
          ProfileRepositoryError.malformedProfile,
        );
      await _pump(tester, const ProfileViewScreen(), repository);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'We could not read your saved profile. Please try again later.',
        ),
        findsOneWidget,
      );
      expect(find.text('Enter a valid display name.'), findsNothing);
    });

    testWidgets('retry restarts profile observation', (tester) async {
      final repository = _FakeProfileRepository()
        ..watchFailure = const ProfileRepositoryException(
          ProfileRepositoryError.unavailable,
        );
      await _pump(
        tester,
        const ProfileViewScreen(),
        repository,
        disableAutomaticRetries: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      final subscriptionsBeforeRetry = repository.watchCount;

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(repository.watchCount, subscriptionsBeforeRetry + 1);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('ProfileEditScreen', () {
    testWidgets('prefills the name and preserves avatar and interests', (
      tester,
    ) async {
      final repository = _FakeProfileRepository()..profile = _sampleProfile();
      UserProfile? savedProfile;
      await _pump(
        tester,
        ProfileEditScreen(
          profile: _sampleProfile(),
          onSaved: (profile) => savedProfile = profile,
        ),
        repository,
      );

      expect(find.text('Poojani'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Poojani Silva');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(repository.updatedDisplayName, 'Poojani Silva');
      expect(repository.updatedAvatarId, 'amber');
      expect(repository.updatedInterestIds, ['iot', 'design']);
      expect(savedProfile?.displayName, 'Poojani Silva');
      expect(savedProfile?.avatarId, 'amber');
      expect(savedProfile?.interestIds, ['iot', 'design']);
    });

    testWidgets('requires a non-empty display name', (tester) async {
      final repository = _FakeProfileRepository();
      await _pump(
        tester,
        ProfileEditScreen(profile: _sampleProfile()),
        repository,
      );
      await tester.enterText(find.byType(TextFormField), '   ');

      await tester.tap(find.text('Save changes'));
      await tester.pump();

      expect(find.text('Enter your display name.'), findsOneWidget);
      expect(repository.updateCount, 0);
    });

    testWidgets('shows loading and a friendly update failure', (tester) async {
      final repository = _FakeProfileRepository()
        ..updateGate = Completer<void>()
        ..updateFailure = const ProfileRepositoryException(
          ProfileRepositoryError.permissionDenied,
        );
      await _pump(
        tester,
        ProfileEditScreen(profile: _sampleProfile()),
        repository,
      );
      await tester.enterText(find.byType(TextFormField), 'Updated name');

      await tester.tap(find.text('Save changes'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repository.updateGate!.complete();
      await tester.pumpAndSettle();

      expect(
        find.text('You do not have permission to access this profile.'),
        findsOneWidget,
      );
    });

    testWidgets('prevents duplicate updates while saving', (tester) async {
      final repository = _FakeProfileRepository()
        ..updateGate = Completer<void>();
      await _pump(
        tester,
        ProfileEditScreen(profile: _sampleProfile()),
        repository,
      );
      await tester.enterText(find.byType(TextFormField), 'Updated name');

      await tester.tap(find.text('Save changes'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(repository.updateCount, 1);

      repository.updateGate!.complete();
      await tester.pumpAndSettle();
    });
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  _FakeProfileRepository repository, {
  _TestAuthStateController? authController,
  bool disableAutomaticRetries = false,
}) => tester.pumpWidget(
  ProviderScope(
    retry: disableAutomaticRetries ? (_, _) => null : null,
    overrides: [
      profileRepositoryProvider.overrideWithValue(repository),
      authStateProvider.overrideWith(
        () =>
            authController ??
            _TestAuthStateController(
              const AuthState.ready(
                userId: 'current-user-uid',
                displayName: 'Poojani',
              ),
            ),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: screen),
  ),
);

UserProfile _sampleProfile({
  String id = 'current-user-uid',
  String displayName = 'Poojani',
}) => UserProfile(
  id: id,
  displayName: displayName,
  avatarId: 'amber',
  interestIds: const ['iot', 'design'],
);

class _FakeProfileRepository implements ProfileRepository {
  UserProfile? profile;
  Stream<UserProfile?>? watchStream;
  List<Stream<UserProfile?>>? watchResponses;
  Object? watchFailure;
  Completer<void>? createGate;
  Completer<void>? updateGate;
  Object? createFailure;
  Object? updateFailure;
  int createCount = 0;
  int updateCount = 0;
  int watchCount = 0;
  String? createdDisplayName;
  String? updatedDisplayName;
  String? updatedAvatarId;
  List<String>? updatedInterestIds;

  @override
  Future<UserProfile> createCurrentProfile({
    required String displayName,
    String avatarId = UserProfile.defaultAvatarId,
    List<String> interestIds = const [],
  }) async {
    createCount++;
    createdDisplayName = displayName;
    await createGate?.future;
    if (createFailure case final failure?) throw failure;
    return UserProfile(
      id: 'current-user-uid',
      displayName: displayName,
      avatarId: avatarId,
      interestIds: interestIds,
    );
  }

  @override
  Future<UserProfile?> getCurrentProfile() async => profile;

  @override
  Stream<UserProfile?> watchCurrentProfile() {
    watchCount++;
    final responses = watchResponses;
    if (responses != null && watchCount <= responses.length) {
      return responses[watchCount - 1];
    }
    if (watchFailure case final failure?) return Stream.error(failure);
    return watchStream ?? Stream.value(profile);
  }

  @override
  Future<UserProfile> updateCurrentProfile({
    required String displayName,
    String avatarId = UserProfile.defaultAvatarId,
    List<String> interestIds = const [],
  }) async {
    updateCount++;
    updatedDisplayName = displayName;
    updatedAvatarId = avatarId;
    updatedInterestIds = List.of(interestIds);
    await updateGate?.future;
    if (updateFailure case final failure?) throw failure;
    return UserProfile(
      id: profile?.id ?? 'current-user-uid',
      displayName: displayName,
      avatarId: avatarId,
      interestIds: interestIds,
    );
  }
}

class _TestAuthStateController extends AuthStateController {
  _TestAuthStateController(this._initialState);

  final AuthState _initialState;

  @override
  AuthState build() => _initialState;

  void emit(AuthState identity) => state = identity;
}
