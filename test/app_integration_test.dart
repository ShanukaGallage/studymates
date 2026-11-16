import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/app/account_access.dart';
import 'package:studymates/app/app.dart';
import 'package:studymates/app/app_mode.dart';
import 'package:studymates/app/firebase_startup.dart';
import 'package:studymates/app/router.dart';
import 'package:studymates/core/models/community_models.dart';
import 'package:studymates/features/auth/domain/auth_state.dart';
import 'package:studymates/features/auth/presentation/controllers/auth_providers.dart';
import 'package:studymates/features/profile/presentation/controllers/profile_providers.dart';
import 'package:studymates/preview/preview_scope.dart';

class TestIdentity extends AuthStateController {
  @override
  AuthState build() => const AuthState.signedOut();
  void emit(AuthState value) => state = value;
  @override
  Future<void> signOut() async => state = const AuthState.signedOut();
}

void main() {
  test(
    'redirects preserve safe destinations and reject external return URLs',
    () {
      expect(
        accountRedirect(AccountAccess.signedOut, Uri.parse('/profile/edit')),
        '/login?from=%2Fprofile%2Fedit',
      );
      expect(
        accountRedirect(
          AccountAccess.ready,
          Uri.parse('/login?from=https://example.com'),
        ),
        '/home',
      );
      expect(
        accountRedirect(
          AccountAccess.ready,
          Uri.parse('/login?from=%2Fprofile'),
        ),
        '/profile',
      );
      expect(
        accountRedirect(
          AccountAccess.setupRequired,
          Uri.parse('/profile/setup'),
        ),
        isNull,
      );
      expect(
        accountRedirect(AccountAccess.unavailable, Uri.parse('/profile')),
        startsWith('/account-status'),
      );
    },
  );

  testWidgets(
    'auth routes, persisted profile readiness, profile edit and sign-out are connected',
    (tester) async {
      final profiles = StreamController<UserProfile?>.broadcast();
      final container = ProviderContainer(
        overrides: [
          appModeProvider.overrideWithValue(AppMode.connected),
          authStateProvider.overrideWith(TestIdentity.new),
          currentProfileProvider.overrideWith((ref) => profiles.stream),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await profiles.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const StudyMatesApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      await tester.ensureVisible(find.text('Create an account'));
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/reset-password',
      );

      final identity =
          container.read(authStateProvider.notifier) as TestIdentity;
      identity.emit(const AuthState.incompleteProfile(userId: 'u1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      profiles.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Set up your profile'), findsOneWidget);
      // Profile save emits a Firestore profile without changing Auth.displayName.
      profiles.add(UserProfile(id: 'u1', displayName: 'Learner'));
      await tester.pumpAndSettle();
      expect(find.text('Small steps.\nShared focus.'), findsOneWidget);
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(find.text('Learner'), findsOneWidget);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/profile/edit',
      );
      container.read(appRouterProvider).go('/profile');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      container.read(appRouterProvider).go('/profile/edit');
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Learner'), findsNothing);
    },
  );

  testWidgets(
    'profile errors and another user cached profile cannot unlock the app',
    (tester) async {
      final profiles = StreamController<UserProfile?>.broadcast();
      final container = ProviderContainer(
        overrides: [
          appModeProvider.overrideWithValue(AppMode.connected),
          authStateProvider.overrideWith(TestIdentity.new),
          currentProfileProvider.overrideWith((ref) => profiles.stream),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await profiles.close();
      });
      (container.read(authStateProvider.notifier) as TestIdentity).emit(
        const AuthState.ready(
          userId: 'u2',
          displayName: 'Auth name alone is insufficient',
        ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const StudyMatesApp(),
        ),
      );
      await tester.pump();
      profiles.add(UserProfile(id: 'u1', displayName: 'Private other profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(accountAccessProvider), AccountAccess.loading);
      expect(find.text('Private other profile'), findsNothing);
      profiles.addError(StateError('unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.text('We could not verify your account and profile.'),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      // Fake identity resets to signed out; real repository resubscribes to Auth.
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );

  testWidgets(
    'Firebase startup failure can retry without a fake account fallback',
    (tester) async {
      var attempts = 0;
      final container = ProviderContainer(
        overrides: [
          firebaseBootstrapProvider.overrideWith((ref) async {
            attempts++;
            if (attempts == 1) throw StateError('startup failed');
          }),
          authStateProvider.overrideWith(TestIdentity.new),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FirebaseStartup(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('StudyMates could not connect to its account services.'),
        findsOneWidget,
      );
      expect(find.text('Welcome back'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );

  testWidgets('preview Progress and scanner landing work without Firebase', (
    tester,
  ) async {
    await tester.pumpWidget(const PreviewScope(child: StudyMatesApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('progress-total-time')),
        matching: find.text('1h 5m'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Scanner preview'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Camera/manual capture test only. No invitation is verified and no room is joined.',
      ),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar).hitTestable(), findsNothing);
    await tester.tap(find.byTooltip('Back to preview'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('progress-total-time')),
        matching: find.text('1h 5m'),
      ),
      findsOneWidget,
    );
  });
}
