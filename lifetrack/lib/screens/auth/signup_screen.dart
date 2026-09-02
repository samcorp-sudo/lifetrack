// ============================================================================
// Signup Screen
// ----------------------------------------------------------------------------
// FIXED: _introController initialization order.
//   - `super.initState()` runs FIRST, then the controller is assigned.
//   - The field is nullable (`AnimationController?`) so an early dispose
//     cannot throw LateInitializationError.
//   - `build` reads a local `controller` and falls back to a plain
//     non-animated layout if the controller is missing.
// ============================================================================

import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
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
  bool _acceptedTerms = false;
  String? _errorMessage;

  // Nullable so dispose-before-init can't throw LateInitializationError.
  AnimationController? _introController;

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
    _introController?.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_acceptedTerms) {
      setState(() => _errorMessage =
          'Please agree to the Terms of Use and Privacy Policy.');
      return;
    }
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
      if (!mounted) return;

      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => const _AccountReadyDialog(),
        transitionBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              ),
              child: child,
            ),
          );
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _authService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  InputDecoration _fieldDecoration(
    BuildContext context,
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    final s = context.season;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
      borderSide: BorderSide(color: s.accent.withValues(alpha: 0.25)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    // Defensive: if the controller wasn't initialized (early dispose /
    // hot-restart weirdness), render a static version instead of crashing.
    final controller = _introController;
    final Widget form = Form(
      key: _formKey,
      child: _formColumn(context, theme, s),
    );
    final body = controller == null
        ? form
        : FadeTransition(opacity: controller, child: form);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back_rounded, color: s.accentText),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  Widget _formColumn(BuildContext context, ThemeData theme, SeasonColors s) {
    final controller = _introController;

    Widget stagger(double start, double end, Widget child) {
      if (controller == null) return child;
      return _StaggeredFade(
        controller: controller,
        start: start,
        end: end,
        child: child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_add_alt_1_rounded,
                size: 32, color: s.accentText),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Create your account',
          style: theme.textTheme.displayLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'A few details and you\u2019re ready to go.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

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

        stagger(
          0.10,
          0.45,
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
        ),
        const SizedBox(height: 12),
        stagger(
          0.18,
          0.52,
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
                  color: s.accentText,
                ),
                tooltip:
                    _obscurePassword ? 'Show password' : 'Hide password',
              ),
            ),
            validator: (value) => (value == null || value.length < 6)
                ? 'At least 6 characters'
                : null,
          ),
        ),
        const SizedBox(height: 12),
        stagger(
          0.26,
          0.60,
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
                  color: s.accentText,
                ),
                tooltip:
                    _obscureConfirm ? 'Show password' : 'Hide password',
              ),
            ),
            validator: (value) => (value != _passwordController.text)
                ? 'Passwords don\'t match'
                : null,
          ),
        ),
        const SizedBox(height: 16),

        stagger(
          0.36,
          0.72,
          _consentRow(context),
        ),
        const SizedBox(height: 16),

        stagger(
          0.45,
          0.85,
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
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'You can delete all data anytime in Profile.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

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
                  Text('I agree to the ',
                      style: theme.textTheme.bodySmall),
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
// "Account is ready" — shown after a successful sign up.
// ============================================================================
class _AccountReadyDialog extends StatefulWidget {
  const _AccountReadyDialog();

  @override
  State<_AccountReadyDialog> createState() => _AccountReadyDialogState();
}

class _AccountReadyDialogState extends State<_AccountReadyDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
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

    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _loop,
                  builder: (context, _) {
                    final t = _loop.value;
                    final ring = Curves.easeOutBack
                        .transform((t * 1.6).clamp(0.0, 1.0));
                    final check = Curves.easeOut
                        .transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
                    return SizedBox(
                      width: 96,
                      height: 96,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 96 * ring,
                            height: 96 * ring,
                            decoration: BoxDecoration(
                              color: s.accent.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 72 * ring,
                            height: 72 * ring,
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
                const SizedBox(height: 20),
                Text(
                  'You\u2019re all set',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Your account is ready. Taking you to your dashboard\u2026',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
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
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Legal sheet
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
        'Profile \u2192 Delete All Data. This clears your local database '
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
