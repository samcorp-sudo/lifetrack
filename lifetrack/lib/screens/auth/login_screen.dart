// ============================================================================
// Login Screen
// ----------------------------------------------------------------------------
// IMPROVEMENTS OVER PREVIOUS VERSION (layout/UX only — AuthService calls,
// validation rules, and the auth-gate navigation comment are unchanged):
// - Email/password fields now use an OutlineInputBorder with the app's own
//   chip radius (LifeTrackMetrics.chipRadius) and stroke color, matching the
//   dropdown fields on the Add Activity sheet, instead of default
//   Material underline fields with no visual relationship to the rest of
//   the app.
// - Each field gets a tinted prefix icon (mail / lock), same tint style used
//   for icon chips elsewhere.
// - Password field now has a show/hide toggle.
// - Error message is a tinted banner with an icon instead of a bare line of
//   red text — reads as a distinct state rather than stray text, and no
//   longer hardcodes Colors.red (uses the theme's error color instead).
// - Loading spinner uses the theme's onPrimary color instead of a hardcoded
//   Colors.white, so it still contrasts correctly in a differently-themed
//   button.
// - Keyboard flow: email field advances to password on "next", password
//   field submits the form on "done".
// ============================================================================

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // No navigation needed here — the auth gate in app.dart reacts
      // to authStateChanges and swaps to the app automatically.
    } catch (e) {
      setState(() => _errorMessage = _authService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email above first.');
      return;
    }
    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } catch (e) {
      setState(() => _errorMessage = _authService.friendlyError(e));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('LifeTrack',
                      style: Theme.of(context).textTheme.headlineLarge,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Log in to continue',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 32),
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
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: _forgotPassword,
                        child: const Text('Forgot password?')),
                  ),
                  const SizedBox(height: 12),
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
                        : const Text('Log In'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const SignupScreen()),
                    ),
                    child: const Text("Don't have an account? Sign up"),
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
