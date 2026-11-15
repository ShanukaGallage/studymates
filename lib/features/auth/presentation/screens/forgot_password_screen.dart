import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/auth_state.dart';
import '../controllers/auth_providers.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.onBackToLogin});

  final VoidCallback? onBackToLogin;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _requestSent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _requestSent = false;
    });
    try {
      await ref
          .read(authStateProvider.notifier)
          .sendPasswordReset(email: _email.text.trim());
      if (mounted) setState(() => _requestSent = true);
    } catch (_) {
      if (mounted) {
        final code = ref.read(authStateProvider).errorCode;
        setState(() {
          // Keep the response neutral for an unknown email address.
          if (code == AuthErrorCode.userNotFound) {
            _requestSent = true;
          } else {
            _errorMessage = _resetErrorMessage(code);
          }
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
                    'Reset your password',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Enter your email and we will send password reset instructions.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: _validateEmail,
                  ),
                  if (_requestSent)
                    Padding(
                      padding: EdgeInsets.only(top: AppSpacing.lg),
                      child: Semantics(
                        liveRegion: true,
                        child: const Text(
                          'If an account exists for this email, password reset instructions will be sent.',
                        ),
                      ),
                    ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Send reset instructions',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Back to sign in',
                    variant: AppButtonVariant.secondary,
                    onPressed: _isSubmitting ? null : widget.onBackToLogin,
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

String _resetErrorMessage(AuthErrorCode? code) => switch (code) {
  AuthErrorCode.invalidEmail => 'Enter a valid email address.',
  AuthErrorCode.tooManyRequests => 'Too many attempts. Try again later.',
  AuthErrorCode.networkRequestFailed =>
    'Check your internet connection and try again.',
  AuthErrorCode.operationNotAllowed || AuthErrorCode.unavailable =>
    'Password reset is temporarily unavailable. Try again later.',
  _ => 'We could not send the reset request. Please try again.',
};
