import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/auth_state.dart';
import '../controllers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.onSignUp,
    this.onForgotPassword,
    this.onAuthenticated,
  });

  final VoidCallback? onSignUp;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onAuthenticated;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
          .signIn(email: _email.text.trim(), password: _password.text);
      if (mounted) widget.onAuthenticated?.call();
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = _loginErrorMessage(
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
                    'Welcome back',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Sign in to continue studying with your community.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
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
                    textInputAction: TextInputAction.done,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your password.'
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isSubmitting ? null : widget.onForgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  if (_errorMessage != null)
                    _AuthError(message: _errorMessage!),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Sign in',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('New to StudyMates?'),
                      TextButton(
                        onPressed: _isSubmitting ? null : widget.onSignUp,
                        child: const Text('Create an account'),
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

String _loginErrorMessage(AuthErrorCode? code) => switch (code) {
  AuthErrorCode.invalidEmail => 'Enter a valid email address.',
  AuthErrorCode.userDisabled => 'This account is disabled. Contact support.',
  AuthErrorCode.tooManyRequests => 'Too many attempts. Try again later.',
  AuthErrorCode.networkRequestFailed =>
    'Check your internet connection and try again.',
  AuthErrorCode.operationNotAllowed || AuthErrorCode.unavailable =>
    'Sign-in is temporarily unavailable. Try again later.',
  AuthErrorCode.userNotFound ||
  AuthErrorCode.wrongPassword ||
  AuthErrorCode.invalidCredential => 'The email or password is incorrect.',
  _ => 'We could not sign you in. Check your details and try again.',
};

class _AuthError extends StatelessWidget {
  const _AuthError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}
