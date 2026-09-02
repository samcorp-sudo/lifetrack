// ============================================================================
// Login Screen
// ----------------------------------------------------------------------------
// Season-aware redesign with entrance animations, Terms/Privacy consent,
// and a "signing you in" progress dialog that celebrates on success.
//
// WHAT CHANGED VS. THE PREVIOUS VERSION:
//   - Tapping Log In opens _SignInProgressDialog: rotating key + bouncing
//     dots while signIn runs (min 1.2s so it doesn't flash).
//   - On success, the dialog swaps to an animated check circle +
//     "Welcome back, [name]" + progress bar, then closes and the auth
//     gate swaps to the app.
//   - On failure, the dialog closes with `false` and a friendly error
//     banner appears in the form.
//
// UNCHANGED:
//   - AuthService calls (signIn, sendPasswordResetEmail).
//   - friendlyError behavior.
//   - The auth gate navigation pattern.
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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  String? _errorMessage;

  late final AnimationController _introController;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_acceptedTerms) {
      setState(() =>
          _errorMessage = 'Please agree to the Terms of Use and Privacy Policy.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SignInProgressDialog(
        email: email,
        task: () => _authService.signIn(
          email: email,
          password: _passwordController.text,
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok != true) {
      setState(() =>
          _errorMessage = 'Sign in failed. Check your email and password.');
      return;
    }

    // Success — the auth gate in app.dart handles the actual screen swap.
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

  // ---------------------------------------------------------------------
  // Legal sheets
  // ---------------------------------------------------------------------

  Future<void> _showTerms() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _LegalSheet(
        icon: Icons.description_outlined,
        title: 'Terms of Use',
        subtitle: 'The rules for using LifeTrack.',
        sections: _termsSections,
      ),
    );
  }

  Future<void> _showPrivacy() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _LegalSheet(
        icon: Icons.privacy_tip_outlined,
        title: 'Privacy Policy',
        subtitle: 'How LifeTrack handles your data.',
        sections: _privacySections,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Field decoration
  // ---------------------------------------------------------------------

  InputDecoration _fieldDecoration(
    BuildContext context,
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    final s = context.season;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
      borderSide: BorderSide(
        color: s.accent.withValues(alpha: 0.25),
      ),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: s.accentText),
      prefixIcon: Icon(icon, color: s.accentText, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: s.accent.withValues(alpha: 0.06),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
        borderSide: BorderSide(color: s.accent, width: 1.5),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FadeTransition(
                opacity: _introController,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero icon
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: s.accent.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.lock_open_rounded,
                              size: 34, color: s.accentText),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome back',
                        style: theme.textTheme.displayLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to your LifeTrack account',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // Error banner
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: _errorMessage == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _errorBanner(context, _errorMessage!),
                              ),
                      ),

                      // Fields with a small stagger
                      _StaggeredFade(
                        controller: _introController,
                        start: 0.10,
                        end: 0.45,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              _passwordFocusNode.requestFocus(),
                          decoration: _fieldDecoration(
                              context, 'Email', Icons.mail_outline_rounded),
                          validator: (value) =>
                              (value == null || !value.contains('@'))
                                  ? 'Enter a valid email'
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _StaggeredFade(
                        controller: _introController,
                        start: 0.20,
                        end: 0.55,
                        child: TextFormField(
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
                                color: s.accentText,
                              ),
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                            ),
                          ),
                          validator: (value) =>
                              (value == null || value.length < 6)
                                  ? 'At least 6 characters'
                                  : null,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          style: TextButton.styleFrom(
                            foregroundColor: s.accentText,
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Log in button
                      _StaggeredFade(
                        controller: _introController,
                        start: 0.30,
                        end: 0.65,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                )
                              : const Text('Log In'),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Consent + sign-up
                      _StaggeredFade(
                        controller: _introController,
                        start: 0.45,
                        end: 0.85,
                        child: _consentRow(context),
                      ),
                      const SizedBox(height: 8),

                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => const SignupScreen()),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: s.accentText,
                        ),
                        child: const Text("Don't have an account? Sign up"),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Consent checkbox + terms/privacy links
  // ---------------------------------------------------------------------

  Widget _consentRow(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: s.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
            activeColor: s.accent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'I agree to the ',
                    style: theme.textTheme.bodySmall,
                  ),
                  _legalLink(context, 'Terms of Use', _showTerms),
                  Text(' and ', style: theme.textTheme.bodySmall),
                  _legalLink(context, 'Privacy Policy', _showPrivacy),
                  Text('.', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legalLink(
      BuildContext context, String text, VoidCallback onTap) {
    final s = context.season;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: s.accentText,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: s.accentText.withValues(alpha: 0.6),
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

// ============================================================================
// Staggered fade + slide helper
// ============================================================================
class _StaggeredFade extends StatelessWidget {
  const _StaggeredFade({
    required this.controller,
    required this.start,
    required this.end,
    required this.child,
  });

  final AnimationController controller;
  final double start;
  final double end;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        return Opacity(
          opacity: anim.value,
          child: Transform.translate(
            offset: Offset(0, (1 - anim.value) * 12),
            child: child,
          ),
        );
      },
    );
  }
}

// ============================================================================
// Sign-in progress dialog
// Plays while signIn runs, then swaps to a success state on success.
// Pops `true` on success, `false` on failure.
// ============================================================================
class _SignInProgressDialog extends StatefulWidget {
  const _SignInProgressDialog({required this.task, required this.email});

  final Future<void> Function() task;
  final String email;

  @override
  State<_SignInProgressDialog> createState() => _SignInProgressDialogState();
}

class _SignInProgressDialogState extends State<_SignInProgressDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _run();
  }

  Future<void> _run() async {
    final started = DateTime.now();
    var ok = true;
    try {
      await widget.task();
    } catch (_) {
      ok = false;
    }

    // Minimum visible time so a fast auth doesn't flash.
    const minimum = Duration(milliseconds: 1200);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minimum) await Future<void>.delayed(minimum - elapsed);
    if (!mounted) return;

    if (!ok) {
      Navigator.pop(context, false);
      return;
    }

    _loop.stop();
    setState(() => _done = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    final name = _displayNameFromEmail(widget.email);

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _done
                ? Column(
                    key: const ValueKey('done'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          final ring =
                              Curves.easeOutBack.transform(value * 1.4);
                          final check = Curves.easeOut.transform(
                              ((value - 0.3) / 0.7).clamp(0.0, 1.0));
                          return SizedBox(
                            width: 96,
                            height: 96,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 96 * ring.clamp(0.0, 1.0),
                                  height: 96 * ring.clamp(0.0, 1.0),
                                  decoration: BoxDecoration(
                                    color: s.accent.withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 72 * ring.clamp(0.0, 1.0),
                                  height: 72 * ring.clamp(0.0, 1.0),
                                  decoration: BoxDecoration(
                                    color: s.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Opacity(
                                  opacity: check,
                                  child: Transform.scale(
                                    scale: 0.6 + check * 0.4,
                                    child: Icon(Icons.check_rounded,
                                        size: 42, color: s.onAccent),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        name == null ? 'Welcome back' : 'Welcome back, $name',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Taking you to your dashboard\u2026',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 32,
                        height: 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            backgroundColor: s.accent.withValues(alpha: 0.18),
                            valueColor: AlwaysStoppedAnimation<Color>(s.accent),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('working'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                color: s.accent,
                                backgroundColor:
                                    s.accent.withValues(alpha: 0.15),
                              ),
                            ),
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: s.accent.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: AnimatedBuilder(
                                  animation: _loop,
                                  builder: (context, _) {
                                    final t = _loop.value;
                                    final angle = t * 2 * 3.1415926;
                                    final scale = 0.94 +
                                        0.06 * (1 - (t * 2 - 1).abs());
                                    return Transform.rotate(
                                      angle: angle,
                                      child: Transform.scale(
                                        scale: scale,
                                        child: Icon(Icons.key_rounded,
                                            size: 32, color: s.accentText),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Signing you in\u2026',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Please wait a moment.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          return AnimatedBuilder(
                            animation: _loop,
                            builder: (context, _) {
                              final t = (_loop.value + i * 0.2) % 1.0;
                              final wave =
                                  (1 - (t * 2 - 1).abs()).clamp(0.0, 1.0);
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Container(
                                  width: 8,
                                  height: 8 + 6 * wave,
                                  decoration: BoxDecoration(
                                    color: s.accent.withValues(
                                        alpha: 0.4 + 0.6 * wave),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  static String? _displayNameFromEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return null;
    final local = trimmed.split('@').first;
    if (local.isEmpty) return null;
    // Take the first word before . _ or +
    final first = local.split(RegExp(r'[._+]')).first;
    if (first.isEmpty) return null;
    return first[0].toUpperCase() + first.substring(1);
  }
}

// ============================================================================
// Legal sheet — shared by Terms of Use and Privacy Policy.
// ============================================================================
class _LegalSheet extends StatelessWidget {
  const _LegalSheet({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.sections,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: s.accentText, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(subtitle, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final section in sections) ...[
                      Text(section.heading,
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(section.body,
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection({required this.heading, required this.body});
  final String heading;
  final String body;
}

// ---------------------------------------------------------------------------
// Terms of Use
// ---------------------------------------------------------------------------
const List<_LegalSection> _termsSections = [
  _LegalSection(
    heading: '1. About LifeTrack',
    body: 'LifeTrack helps you track your time, money, goals, and skills. '
        'By using the app you agree to these Terms of Use. If you do not '
        'agree, please do not use the app.',
  ),
  _LegalSection(
    heading: '2. Your account',
    body: 'You are responsible for keeping your login details safe. You '
        'must not share your account with anyone else. You are responsible '
        'for everything that happens under your account.',
  ),
  _LegalSection(
    heading: '3. Your content',
    body: 'Everything you add to LifeTrack (schedules, transactions, goals, '
        'notes) belongs to you. We do not claim any ownership over your data. '
        'You are responsible for the accuracy of the information you enter.',
  ),
  _LegalSection(
    heading: '4. Acceptable use',
    body: 'Do not use LifeTrack to break the law, to harm others, or to '
        'attempt to access data or systems that are not yours. Do not '
        'reverse-engineer or redistribute the app.',
  ),
  _LegalSection(
    heading: '5. Plans and payments',
    body: 'LifeTrack offers a free tier and several paid plans. Paid plans '
        'are billed monthly and renew automatically until you cancel. '
        'Payments are processed by the platform store (Google Play or the '
        'App Store) or by our payment partners. Refunds follow the '
        'policies of the store or partner you paid through.',
  ),
  _LegalSection(
    heading: '6. Availability',
    body: 'LifeTrack is provided as-is. We try to keep the app available '
        'at all times, but we do not guarantee uninterrupted service. We '
        'may change, suspend, or discontinue features at any time.',
  ),
  _LegalSection(
    heading: '7. Limitation of liability',
    body: 'To the extent permitted by law, LifeTrack and its developers '
        'are not liable for any indirect, incidental, or consequential '
        'damages arising from your use of the app, including but not '
        'limited to lost data, lost profits, or missed appointments.',
  ),
  _LegalSection(
    heading: '8. Changes to these terms',
    body: 'We may update these Terms of Use from time to time. If we make '
        'a material change, we will notify you in the app. Continuing to '
        'use LifeTrack after the change means you accept the updated terms.',
  ),
];

// ---------------------------------------------------------------------------
// Privacy Policy
// ---------------------------------------------------------------------------
const List<_LegalSection> _privacySections = [
  _LegalSection(
    heading: '1. What we collect',
    body: 'When you sign in, we collect the email address you provide and a '
        'Firebase user ID. If you choose to add a display name, we store '
        'that too. Everything else you enter (schedules, transactions, '
        'goals, tasks, skills) is stored locally on your device unless you '
        'explicitly enable Cloud Sync.',
  ),
  _LegalSection(
    heading: '2. How we use your data',
    body: 'Your data is used only to provide the app to you: to show your '
        'dashboard, to remind you about tasks, and to keep your account '
        'working. We do not sell your data, and we do not use it for '
        'advertising.',
  ),
  _LegalSection(
    heading: '3. Where your data is stored',
    body: 'Your entries are stored in a local SQLite database on your '
        'phone. Your account email and display name are stored by Firebase '
        'Authentication. If you turn on Cloud Sync, your data is also '
        'uploaded to a Firebase project controlled by the app developers.',
  ),
  _LegalSection(
    heading: '4. Third-party services',
    body: 'LifeTrack uses Firebase (authentication, messaging) and the '
        'device\u2019s biometric system (for App Lock). Firebase handles '
        'authentication data under Google\u2019s privacy policy. Biometric '
        'data never leaves your device and is never sent to LifeTrack.',
  ),
  _LegalSection(
    heading: '5. Your rights',
    body: 'You can delete all of your data at any time from '
        'Settings \u2192 Delete All Data. This clears your local database '
        'and your stored settings. To delete your account itself, contact '
        'support@lifetrack.example.',
  ),
  _LegalSection(
    heading: '6. Security',
    body: 'We take reasonable steps to keep your data safe, including '
        'optional App Lock, biometric unlock, and encrypted device storage. '
        'No system is perfectly secure, so please keep your device and '
        'account credentials safe.',
  ),
  _LegalSection(
    heading: '7. Children',
    body: 'LifeTrack is not intended for children under 13. If you believe '
        'a child has created an account, contact us and we will delete it.',
  ),
  _LegalSection(
    heading: '8. Contact',
    body: 'Questions about this Privacy Policy? Contact '
        'support@lifetrack.example.',
  ),
];
