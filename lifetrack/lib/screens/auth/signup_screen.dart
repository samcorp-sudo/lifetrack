// ============================================================================
// Signup Screen
// ----------------------------------------------------------------------------
// IMPROVEMENTS OVER PREVIOUS VERSION (layout/UX only — AuthService calls,
// validation rules, and the auth-gate comment are unchanged):
// - Fields now match the redesigned Login screen: OutlineInputBorder using
//   LifeTrackMetrics.chipRadius / LifeTrackColors.strokeDark, tinted prefix
//   icons, and the theme's error color instead of hardcoded Colors.red.
// - Password AND confirm-password fields now each have their own show/hide
//   toggle (previously always obscured with no way to check your typing).
// - Keyboard flow: email -> password -> confirm -> submit via "next"/"done".
// - AppBar is flattened (no elevation, transparent) and a short subtitle
//   was added under the title, mirroring the Login screen's intro line,
//   instead of a bare AppBar title with no context.
// ============================================================================

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Auth gate in app.dart handles navigation once signed in.
    } catch (e) {
      setState(() => _errorMessage = _authService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
      BuildContext context, String label, IconData icon,
      {Widget? suffixIcon}) {
    final primary = Theme.of(context).colorScheme.primary;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
      borderSide: const BorderSide(color: LifeTrackColors.strokeDark),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primary, size: 20),
      suffixIcon: suffixIcon,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Create an account to get started',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    _errorBanner(context, _errorMessage!),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                    decoration: _fieldDecoration(
                        context, 'Email', Icons.mail_outline_rounded),
                    validator: (value) =>
                        (value == null || !value.contains('@'))
                            ? 'Enter a valid email'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _confirmFocusNode.requestFocus(),
                    decoration: _fieldDecoration(
                      context,
                      'Password',
                      Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                      ),
                    ),
                    validator: (value) => (value == null || value.length < 6)
                        ? 'At least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmController,
                    focusNode: _confirmFocusNode,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: _fieldDecoration(
                      context,
                      'Confirm password',
                      Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        tooltip:
                            _obscureConfirm ? 'Show password' : 'Hide password',
                      ),
                    ),
                    validator: (value) => (value != _passwordController.text)
                        ? 'Passwords don\'t match'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Text('Sign Up'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(BuildContext context, String message) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: error),
            ),
          ),
        ],
      ),
    );
  }
}
