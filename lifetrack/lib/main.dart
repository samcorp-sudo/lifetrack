import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'core/security/security_service.dart';
import 'core/security/notification_services.dart';
import 'navigation/main_shell.dart';
import 'screens/auth/login_screen.dart';
import 'theme/app_theme.dart';
import 'app/theme_mode_controller.dart';
import 'app/currency_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await CurrencyController.load();
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
        builder: (context, themeMode, child) => MaterialApp(
          title: 'LifeTrack',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.hasData ? const AppLockGate() : const LoginScreen();
      },
    );
  }
}

class _SecuritySetupScreen extends StatefulWidget {
  const _SecuritySetupScreen();

  @override
  State<_SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends State<_SecuritySetupScreen> {
  final _security = SecurityService();
  final _pin = TextEditingController();
  bool _biometricAvailable = false;
  bool _useBiometric = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  @override
  void dispose() {
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                children: [
                  const Icon(Icons.security_rounded,
                      size: 56, color: LifeTrackColors.highlight),
                  const SizedBox(height: 18),
                  Text('Secure your account',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('Create a 4-digit PIN for quick access next time.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
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
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  if (_biometricAvailable)
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
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const CircularProgressIndicator()
                              : const Text('Continue'))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    if (userId == null) return const LoginScreen();
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

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _securityService = SecurityService();
  final _pinController = TextEditingController();
  bool _isChecking = false;
  String? _errorMessage;
  bool _biometricAvailable = false;
  final int _pinLength = 4;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
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
      setState(() {
        _isChecking = false;
        _errorMessage = 'Incorrect PIN.';
      });
    }
  }

  void _appendPinDigit(String digit) {
    if (_isChecking || _pinController.text.length >= _pinLength) return;
    setState(() => _pinController.text += digit);
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
      setState(() {
        _isChecking = false;
        _errorMessage = 'Biometric authentication failed. Use your PIN.';
      });
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
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_rounded,
                      size: 56, color: LifeTrackColors.highlight),
                  const SizedBox(height: 18),
                  Text('LifeTrack',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('Enter your PIN',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  _PinIndicators(
                    count: _pinLength,
                    filled: _pinController.text.length,
                    hasError: _errorMessage != null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _PinKeypad(
                    onDigit: _appendPinDigit,
                    onBackspace: _removePinDigit,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isChecking ? null : _unlockWithPin,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.lock_open_rounded),
                      label: const Text('UNLOCK'),
                    ),
                  ),
                  if (_biometricAvailable) ...[
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: _isChecking ? null : _unlockWithBiometric,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Use fingerprint / biometric'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinIndicators extends StatelessWidget {
  const _PinIndicators(
      {required this.count, required this.filled, required this.hasError});

  final int count;
  final int filled;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final color = hasError
        ? Theme.of(context).colorScheme.error
        : LifeTrackColors.highlight;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: index < filled ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

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
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: keys,
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (label == null && icon == null) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
        child: Center(
          child: icon == null
              ? Text(label!, style: Theme.of(context).textTheme.titleLarge)
              : Icon(icon),
        ),
      ),
    );
  }
}
