import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'core/security/local_mode.dart';
import 'core/security/security_service.dart';
import 'core/security/notification_services.dart';
import 'navigation/main_shell.dart';
import 'screens/auth/login_screen.dart';
import 'theme/app_theme.dart';
import 'app/currency_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await CurrencyController.load();
  await SeasonController.load();
  await LocalMode.load();
  await NotificationService.initialize();
  runApp(const LifeTrackApp());
}

class LifeTrackApp extends StatelessWidget {
  const LifeTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: CurrencyController.code,
      builder: (context, currencyCode, child) =>
          ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeModeController.mode,
        builder: (context, themeMode, child) =>
            ValueListenableBuilder<SeasonMode>(
          valueListenable: SeasonController.mode,
          builder: (context, seasonMode, child) => MaterialApp(
            title: 'LifeTrack',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            home: const AuthGate(),
          ),
        ),
      ),
    );
  }
}

/// Start gate.
///  - Signed in                       -> AppLockGate (PIN / Dashboard).
///  - Signed out after "Sign out"     -> AppLockGate too: the data is still on
///    the phone, so the user stays in the app (see LocalMode).
///  - Signed out and never signed in  -> LoginScreen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          if (LocalMode.enabled.value) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => LocalMode.set(false));
          }
          return const AppLockGate();
        }
        return ValueListenableBuilder<bool>(
          valueListenable: LocalMode.enabled,
          builder: (context, stayLocal, _) =>
              stayLocal ? const AppLockGate() : const LoginScreen(),
        );
      },
    );
  }
}

// ============================================================================
// Shared UI helpers — used by both PIN setup and unlock screens.
// ============================================================================

/// Big tinted icon chip used as the header of both PIN screens.
class _PinHeader extends StatelessWidget {
  const _PinHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.accent.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 34, color: s.accentText),
        ),
        const SizedBox(height: 18),
        Text(title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// Animated PIN dots.
/// - Each filled dot springs in when a digit is typed.
/// - The wrong-PIN shake moves the whole row horizontally, then drops and
///   fades the dots.
class _PinIndicators extends StatefulWidget {
  const _PinIndicators({
    required this.count,
    required this.filled,
    required this.hasError,
    this.failureCount = 0,
  });

  final int count;
  final int filled;
  final bool hasError;
  final int failureCount;

  @override
  State<_PinIndicators> createState() => _PinIndicatorsState();
}

class _PinIndicatorsState extends State<_PinIndicators>
    with SingleTickerProviderStateMixin {
  late final AnimationController _failure;
  bool _failing = false;

  @override
  void initState() {
    super.initState();
    _failure = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _failing = false);
        }
      });
  }

  @override
  void didUpdateWidget(covariant _PinIndicators oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.failureCount != oldWidget.failureCount) {
      _failing = true;
      _failure.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _failure.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final error = Theme.of(context).colorScheme.error;

    final shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -9), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -9, end: 9), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 9, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _failure,
        curve: const Interval(0, 0.55, curve: Curves.easeInOut),
      ),
    );
    final fall = CurvedAnimation(
      parent: _failure,
      curve: const Interval(0.55, 1, curve: Curves.easeIn),
    );

    return AnimatedBuilder(
      animation: _failure,
      builder: (context, _) {
        final isFailing = _failing;
        return Transform.translate(
          offset: Offset(
            isFailing ? shake.value : 0,
            isFailing ? 26 * fall.value : 0,
          ),
          child: Opacity(
            opacity: isFailing ? 1 - fall.value : 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < widget.count; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _PinDot(
                      filled: isFailing || index < widget.filled,
                      hasError: widget.hasError,
                      accent: s.accent,
                      accentText: s.accentText,
                      errorColor: error,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PinDot extends StatelessWidget {
  const _PinDot({
    required this.filled,
    required this.hasError,
    required this.accent,
    required this.accentText,
    required this.errorColor,
  });

  final bool filled;
  final bool hasError;
  final Color accent;
  final Color accentText;
  final Color errorColor;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError ? errorColor : accent;
    final fillColor = hasError ? errorColor : accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: filled ? fillColor : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.6),
      ),
      child: filled
          ? Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                builder: (context, v, _) => Transform.scale(
                  scale: v,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: hasError ? Colors.white : accentText,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

/// Keypad with press-scale and season ripple.
class _PinKeypad extends StatelessWidget {
  const _PinKeypad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final keys = <Widget>[
      for (final digit in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
        _PinKey(label: digit, onTap: () => onDigit(digit)),
      const SizedBox.shrink(),
      _PinKey(label: '0', onTap: () => onDigit('0')),
      _PinKey(icon: Icons.backspace_outlined, onTap: onBackspace),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: keys,
    );
  }
}

class _PinKey extends StatefulWidget {
  const _PinKey({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  State<_PinKey> createState() => _PinKeyState();
}

class _PinKeyState extends State<_PinKey>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();
    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _tap.reverse();
    await _tap.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.label == null && widget.icon == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final s = context.season;

    return ScaleTransition(
      scale: _tap,
      child: Material(
        color: s.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: s.accent.withValues(alpha: 0.12),
          highlightColor: s.accent.withValues(alpha: 0.06),
          onTap: _handleTap,
          child: Center(
            child: widget.icon == null
                ? Text(
                    widget.label!,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : Icon(widget.icon,
                    color: s.accentText, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Bottom action button with built-in loading state, shared by both screens.
class _PinAction extends StatelessWidget {
  const _PinAction({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18),
        label: Text(isLoading ? 'Please wait…' : label),
      ),
    );
  }
}

// ============================================================================
// Security Setup Screen — the "create your PIN" step after first login.
// ============================================================================

class _SecuritySetupScreen extends StatefulWidget {
  const _SecuritySetupScreen();

  @override
  State<_SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends State<_SecuritySetupScreen>
    with SingleTickerProviderStateMixin {
  final _security = SecurityService();
  final _pin = TextEditingController();
  bool _biometricAvailable = false;
  bool _useBiometric = false;
  bool _saving = false;
  String? _error;

  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
    _checkBiometric();
  }

  @override
  void dispose() {
    _intro.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    final available = await _security.isBiometricAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  void _appendSetupDigit(String digit) {
    if (_saving || _pin.text.length >= 4) return;
    setState(() {
      _pin.text += digit;
      _error = null;
    });
  }

  void _removeSetupDigit() {
    if (_saving || _pin.text.isEmpty) return;
    setState(() {
      _pin.text = _pin.text.substring(0, _pin.text.length - 1);
      _error = null;
    });
  }

  Future<void> _save() async {
    if (!RegExp(r'^\d{4}$').hasMatch(_pin.text)) {
      setState(() => _error = 'Enter exactly 4 digits.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _security.setPin(_pin.text);
      final userId = AuthService().currentUser?.uid;
      if (userId == null) throw StateError('No signed-in user.');
      await _security.setConfiguredUser(userId);
      if (_useBiometric) {
        final confirmed = await _security.authenticateBiometric();
        if (!confirmed) {
          await _security.setBiometricEnabled(false);
          if (mounted) {
            setState(() => _error = 'Biometric setup was not completed.');
          }
          return;
        }
        await _security.setBiometricEnabled(true);
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const MainShell()));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Security setup failed. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: FadeTransition(
                opacity: _intro,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _PinHeader(
                      icon: Icons.shield_outlined,
                      title: 'Secure your account',
                      subtitle:
                          'Create a 4-digit PIN for quick access next time.',
                    ),
                    const SizedBox(height: 24),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: _error == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _errorBanner(context, _error!),
                            ),
                    ),
                    _PinIndicators(
                      count: 4,
                      filled: _pin.text.length,
                      hasError: _error != null,
                    ),
                    const SizedBox(height: 18),
                    _PinKeypad(
                      onDigit: _appendSetupDigit,
                      onBackspace: _removeSetupDigit,
                    ),
                    if (_biometricAvailable) ...[
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: _useBiometric,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                setState(() => _useBiometric = value ?? false),
                        title: const Text('Enable biometric unlock'),
                        subtitle: const Text(
                            'Use the biometric already registered on this phone.'),
                        contentPadding: EdgeInsets.zero,
                        activeColor: context.season.accent,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _PinAction(
                      label: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      isLoading: _saving,
                      onPressed: _save,
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
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(color: error),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// AppLockGate — decides which screen to show.
// ============================================================================

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  final _securityService = SecurityService();
  final _authService = AuthService();
  bool? _lockEnabled;

  @override
  void initState() {
    super.initState();
    _loadLockState();
  }

  Future<void> _loadLockState() async {
    final enabled = await _securityService.isAppLockEnabled();
    if (mounted) setState(() => _lockEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    if (_lockEnabled == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      return _lockEnabled! ? const LockScreen() : const MainShell();
    }
    return FutureBuilder<bool>(
      future: _securityService.hasPinForUser(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.data!) return const _SecuritySetupScreen();
        return _lockEnabled! ? const LockScreen() : const MainShell();
      },
    );
  }
}

// ============================================================================
// LockScreen — the unlock step.
// ============================================================================

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  final _securityService = SecurityService();
  final _pinController = TextEditingController();
  bool _isChecking = false;
  String? _errorMessage;
  bool _biometricAvailable = false;
  int _failureCount = 0;
  final int _pinLength = 4;

  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _intro.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await _securityService.isBiometricAvailable() &&
        await _securityService.isBiometricEnabled();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  Future<void> _unlockWithPin() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });
    final valid = await _securityService.verifyPin(_pinController.text);
    if (!mounted) return;
    if (valid) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const MainShell()));
    } else {
      await _showUnlockFailure('Incorrect PIN.');
    }
  }

  Future<void> _showUnlockFailure(String message) async {
    await HapticFeedback.vibrate();
    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _errorMessage = message;
      _pinController.clear();
      _failureCount++;
    });
  }

  void _appendPinDigit(String digit) {
    if (_isChecking || _pinController.text.length >= _pinLength) return;
    setState(() {
      _pinController.text += digit;
      _errorMessage = null;
    });
  }

  void _removePinDigit() {
    if (_isChecking || _pinController.text.isEmpty) return;
    setState(() {
      _pinController.text = _pinController.text.substring(
        0,
        _pinController.text.length - 1,
      );
    });
  }

  Future<void> _unlockWithBiometric() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });
    final authenticated = await _securityService.authenticateBiometric();
    if (!mounted) return;
    if (authenticated) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const MainShell()));
    } else {
      await _showUnlockFailure(
        'Biometric authentication failed. Use your PIN.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: FadeTransition(
                opacity: _intro,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _PinHeader(
                      icon: Icons.lock_outline_rounded,
                      title: 'LifeTrack',
                      subtitle: 'Enter your PIN to unlock.',
                    ),
                    const SizedBox(height: 24),
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
                    _PinIndicators(
                      count: _pinLength,
                      filled: _pinController.text.length,
                      hasError: _errorMessage != null,
                      failureCount: _failureCount,
                    ),
                    const SizedBox(height: 18),
                    _PinKeypad(
                      onDigit: _appendPinDigit,
                      onBackspace: _removePinDigit,
                    ),
                    const SizedBox(height: 16),
                    _PinAction(
                      label: 'Unlock',
                      icon: Icons.lock_open_rounded,
                      isLoading: _isChecking,
                      onPressed: _unlockWithPin,
                    ),
                    if (_biometricAvailable) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed:
                              _isChecking ? null : _unlockWithBiometric,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: const Text('Use fingerprint / biometric'),
                        ),
                      ),
                    ],
                  ],
                ),
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
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(color: error),
            ),
          ),
        ],
      ),
    );
  }
}
