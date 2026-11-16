import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/auth_state.dart';
import '../controllers/auth_providers.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, this.onSignIn, this.onAccountCreated});

  final VoidCallback? onSignIn;
  final VoidCallback? onAccountCreated;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _displayName = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _displayName.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(authStateProvider.notifier)
          .createAccount(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _displayName.text.trim(),
          );
      if (mounted) widget.onAccountCreated?.call();
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = _signUpErrorMessage(
            ref.read(authStateProvider).errorCode,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Create your account',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Join StudyMates and find a community to learn with.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    label: 'Display name',
                    controller: _displayName,
                    textInputAction: TextInputAction.next,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your display name.'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Password',
                    controller: _password,
                    isPassword: true,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Create a password.';
                      }
                      if (value.length < 6) {
                        return 'Use at least 6 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Confirm password',
                    controller: _confirmPassword,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirm your password.';
                      }
                      if (value != _password.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                  if (_errorMessage != null)
                    _AuthError(message: _errorMessage!),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Create account',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      TextButton(
                        onPressed: _isSubmitting ? null : widget.onSignIn,
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email address.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String _signUpErrorMessage(AuthErrorCode? code) => switch (code) {
  AuthErrorCode.emailAlreadyInUse =>
    'An account already uses this email. Try signing in.',
  AuthErrorCode.invalidEmail => 'Enter a valid email address.',
  AuthErrorCode.weakPassword =>
    'Choose a stronger password with at least 6 characters.',
  AuthErrorCode.tooManyRequests => 'Too many attempts. Try again later.',
  AuthErrorCode.networkRequestFailed =>
    'Check your internet connection and try again.',
  AuthErrorCode.operationNotAllowed || AuthErrorCode.unavailable =>
    'Account creation is temporarily unavailable. Try again later.',
  _ => 'We could not create your account. Check your details and try again.',
};

class _AuthError extends StatelessWidget {
  const _AuthError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}
