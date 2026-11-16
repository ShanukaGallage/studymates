import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:studymates/core/theme/app_theme.dart';
import 'package:studymates/features/auth/data/auth_repository.dart';
import 'package:studymates/features/auth/domain/auth_state.dart';
import 'package:studymates/features/auth/presentation/controllers/auth_providers.dart';
import 'package:studymates/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:studymates/features/auth/presentation/screens/login_screen.dart';
import 'package:studymates/features/auth/presentation/screens/sign_up_screen.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('validates email and password before submitting', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      await _pump(tester, LoginScreen(), repository);

      await tester.tap(find.text('Sign in').first);
      await tester.pump();

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(repository.actions, isEmpty);
    });

    testWidgets('rejects an invalid email format', (tester) async {
      final repository = _FakeAuthRepository();
      await _pump(tester, LoginScreen(), repository);
      await _enterCredentials(
        tester,
        email: 'not-an-email',
        password: 'secret',
      );

      await tester.tap(find.text('Sign in').first);
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(repository.actions, isEmpty);
    });

    testWidgets('invokes sign-up and forgot-password callbacks', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      var signUpTapped = false;
      var forgotPasswordTapped = false;
      await _pump(
        tester,
        LoginScreen(
          onSignUp: () => signUpTapped = true,
          onForgotPassword: () => forgotPasswordTapped = true,
        ),
        repository,
      );

      await tester.tap(find.text('Create an account'));
      await tester.tap(find.text('Forgot password?'));

      expect(signUpTapped, isTrue);
      expect(forgotPasswordTapped, isTrue);
      expect(repository.actions, isEmpty);
    });

    testWidgets('shows loading and prevents duplicate sign-in', (tester) async {
      final repository = _FakeAuthRepository()..pending = Completer<void>();
      await _pump(tester, LoginScreen(), repository);
      await _enterCredentials(
        tester,
        email: 'learner@example.com',
        password: 'secret',
      );

      await tester.tap(find.text('Sign in').first);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(
        repository.actions.where((action) => action == 'sign-in').length,
        1,
      );

      repository.pending!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('calls the success callback after sign-in', (tester) async {
      final repository = _FakeAuthRepository();
      var authenticated = false;
      await _pump(
        tester,
        LoginScreen(onAuthenticated: () => authenticated = true),
        repository,
      );
      await _enterCredentials(
        tester,
        email: 'learner@example.com',
        password: 'secret',
      );

      await tester.tap(find.text('Sign in').first);
      await tester.pumpAndSettle();

      expect(repository.actions, contains('sign-in'));
      expect(repository.lastEmail, 'learner@example.com');
      expect(repository.lastPassword, 'secret');
      expect(authenticated, isTrue);
    });

    testWidgets('trims the email and preserves the entered password', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      await _pump(tester, LoginScreen(), repository);
      await _enterCredentials(
        tester,
        email: ' learner@example.com ',
        password: ' secret ',
      );

      await tester.tap(find.text('Sign in').first);
      await tester.pumpAndSettle();

      expect(repository.lastEmail, 'learner@example.com');
      expect(repository.lastPassword, ' secret ');
    });

    testWidgets('shows a helpful sign-in error', (tester) async {
      final repository = _FakeAuthRepository()
        ..failure = const AuthRepositoryException(AuthErrorCode.wrongPassword);
      await _pump(tester, LoginScreen(), repository);
      await _enterCredentials(
        tester,
        email: 'learner@example.com',
        password: 'secret',
      );

      await tester.tap(find.text('Sign in').first);
      await tester.pumpAndSettle();

      expect(find.text('The email or password is incorrect.'), findsOneWidget);
      expect(find.textContaining('Firebase'), findsNothing);
    });
  });

  group('SignUpScreen', () {
    testWidgets('validates email, password length and confirmation', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      await _pump(tester, SignUpScreen(), repository);

      await tester.tap(find.text('Create account').first);
      await tester.pump();

      expect(find.text('Enter your display name.'), findsOneWidget);
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Create a password.'), findsOneWidget);
      expect(find.text('Confirm your password.'), findsOneWidget);
      expect(repository.actions, isEmpty);
    });

    testWidgets('rejects invalid email format', (tester) async {
      final repository = _FakeAuthRepository();
      await _pump(tester, SignUpScreen(), repository);
      await _enterSignUp(
        tester,
        email: 'invalid-email',
        password: 'secret1',
        confirmation: 'secret1',
      );

      await tester.tap(find.text('Create account').first);
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(repository.actions, isEmpty);
    });

    testWidgets('rejects a password shorter than six characters', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      await _pump(tester, SignUpScreen(), repository);
      await _enterSignUp(tester, password: 'short', confirmation: 'short');

      await tester.tap(find.text('Create account').first);
      await tester.pump();

      expect(find.text('Use at least 6 characters.'), findsOneWidget);
      expect(repository.actions, isEmpty);
    });

    testWidgets('rejects mismatched password confirmation', (tester) async {
      final repository = _FakeAuthRepository();
      await _pump(tester, SignUpScreen(), repository);
      await _enterSignUp(tester, password: 'secret1', confirmation: 'secret2');

      await tester.tap(find.text('Create account').first);
      await tester.pump();

      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(repository.actions, isEmpty);
    });

    testWidgets('invokes the sign-in navigation callback', (tester) async {
      final repository = _FakeAuthRepository();
      var signInTapped = false;
      await _pump(
        tester,
        SignUpScreen(onSignIn: () => signInTapped = true),
        repository,
      );

      await tester.tap(find.text('Sign in'));

      expect(signInTapped, isTrue);
      expect(repository.actions, isEmpty);
    });

    testWidgets('shows loading and prevents repeated account creation', (
      tester,
    ) async {
      final repository = _FakeAuthRepository()..pending = Completer<void>();
      await _pump(tester, SignUpScreen(), repository);
      await _enterSignUp(tester, password: 'secret1', confirmation: 'secret1');

      await tester.tap(find.text('Create account').first);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(
        repository.actions.where((action) => action == 'create-account').length,
        1,
      );

      repository.pending!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('creates account and calls the completion callback', (
      tester,
    ) async {
      final repository = _FakeAuthRepository();
      var created = false;
      await _pump(
        tester,
        SignUpScreen(onAccountCreated: () => created = true),
        repository,
      );
      await _enterSignUp(tester, password: 'secret1', confirmation: 'secret1');

      await tester.tap(find.text('Create account').first);
      await tester.pumpAndSettle();

      expect(repository.actions, contains('create-account'));
      expect(repository.lastDisplayName, 'Learner');
      expect(repository.lastEmail, 'learner@example.com');
      expect(repository.lastPassword, 'secret1');
      expect(created, isTrue);
    });

    testWidgets('shows a useful account creation error', (tester) async {
      final repository = _FakeAuthRepository()
        ..failure = const AuthRepositoryException(
          AuthErrorCode.emailAlreadyInUse,
        );
      await _pump(tester, SignUpScreen(), repository);
      await _enterSignUp(tester, password: 'secret1', confirmation: 'secret1');

      await tester.tap(find.text('Create account').first);
      await tester.pumpAndSettle();

      expect(
        find.text('An account already uses this email. Try signing in.'),
        findsOneWidget,
      );
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('validates email before requesting a reset', (tester) async {
      final repository = _FakeAuthRepository();
      await _pump(tester, ForgotPasswordScreen(), repository);

      await tester.tap(find.text('Send reset instructions'));
      await tester.pump();

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(repository.actions, isEmpty);
    });

    testWidgets('rejects invalid email format', (tester) async {
      final repository = _FakeAuthRepository();
      await _pump(tester, ForgotPasswordScreen(), repository);
      await tester.enterText(find.byType(TextFormField), 'not-an-email');

      await tester.tap(find.text('Send reset instructions'));
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(repository.actions, isEmpty);
    });

    testWidgets('invokes the back-to-login callback', (tester) async {
      final repository = _FakeAuthRepository();
      var backTapped = false;
      await _pump(
        tester,
        ForgotPasswordScreen(onBackToLogin: () => backTapped = true),
        repository,
      );

      await tester.tap(find.text('Back to sign in'));

      expect(backTapped, isTrue);
      expect(repository.actions, isEmpty);
    });

    testWidgets('shows loading and neutral success confirmation', (
      tester,
    ) async {
      final repository = _FakeAuthRepository()..pending = Completer<void>();
      await _pump(tester, ForgotPasswordScreen(), repository);
      await tester.enterText(find.byType(TextFormField), 'learner@example.com');

      await tester.tap(find.text('Send reset instructions'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.pending!.complete();
      await tester.pumpAndSettle();

      expect(repository.actions, contains('password-reset'));
      expect(repository.lastEmail, 'learner@example.com');
      expect(
        find.text(
          'If an account exists for this email, password reset instructions will be sent.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows an understandable reset error', (tester) async {
      final repository = _FakeAuthRepository()
        ..failure = const AuthRepositoryException(
          AuthErrorCode.networkRequestFailed,
        );
      await _pump(tester, ForgotPasswordScreen(), repository);
      await tester.enterText(find.byType(TextFormField), 'learner@example.com');

      await tester.tap(find.text('Send reset instructions'));
      await tester.pumpAndSettle();

      expect(
        find.text('Check your internet connection and try again.'),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  _FakeAuthRepository repository,
) => tester.pumpWidget(
  ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(theme: AppTheme.light, home: screen),
  ),
);

Future<void> _enterCredentials(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
}

Future<void> _enterSignUp(
  WidgetTester tester, {
  String email = 'learner@example.com',
  required String password,
  required String confirmation,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Learner');
  await tester.enterText(find.byType(TextFormField).at(1), email);
  await tester.enterText(find.byType(TextFormField).at(2), password);
  await tester.enterText(find.byType(TextFormField).at(3), confirmation);
}

class _FakeAuthRepository implements AuthRepository {
  Completer<void>? pending;
  AuthRepositoryException? failure;
  final actions = <String>[];
  String? lastEmail;
  String? lastPassword;
  String? lastDisplayName;

  @override
  Stream<AuthState> watchAuthState() =>
      Stream.value(const AuthState.signedOut());

  Future<void> _record(
    String action, {
    required String email,
    String? password,
  }) async {
    actions.add(action);
    lastEmail = email;
    lastPassword = password;
    if (pending case final completer?) await completer.future;
    if (failure case final exception?) throw exception;
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    lastDisplayName = displayName;
    await _record('create-account', email: email, password: password);
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _record('sign-in', email: email, password: password);

  @override
  Future<void> sendPasswordReset({required String email}) =>
      _record('password-reset', email: email);

  @override
  Future<void> signOut() => _record('sign-out', email: '');
}
