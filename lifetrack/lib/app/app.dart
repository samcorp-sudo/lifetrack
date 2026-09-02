import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import 'routes.dart';
import '../core/constants/app_constants.dart';
import '../services/auth_service.dart';
import '../screens/auth/login_screen.dart';

/// Root widget. main.dart just calls runApp(const LifeTrackApp()) —
/// everything about how the app is configured lives here per Phase 2's
/// "avoid putting everything into main.dart" rule.
class LifeTrackApp extends StatefulWidget {
  const LifeTrackApp({super.key});

  @override
  State<LifeTrackApp> createState() => _LifeTrackAppState();
}

class _LifeTrackAppState extends State<LifeTrackApp> {
  // Phase 2 §8: user switches this in Settings once the Settings screen
  // (Phase 8) exists. Defaults to following the device setting for now.
  ThemeMode _themeMode = ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      initialRoute: AppRoutes.dashboard,
      routes: AppRoutes.routes,
      // Auth gate replaces the old placeholder home: signed out ->
      // LoginScreen, signed in -> the app (still a placeholder below
      // until DashboardScreen is finished — Phase 6).
      home: const _AuthGate(),
    );
  }
}

/// Watches Firebase's auth state and swaps between LoginScreen and the
/// app. This is the new entry point in place of going straight to
/// _FoundationCheckScreen.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const _FoundationCheckScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

/// Temporary home screen just to prove the foundation boots correctly
/// (Phase 2 §14 checklist: "App launches"). Replaced by the real
/// DashboardScreen in Phase 6. Now also the thing shown right after
/// login, with a sign-out button so the auth flow is testable end to end.
class _FoundationCheckScreen extends StatelessWidget {
  const _FoundationCheckScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${AppConstants.appName} — signed in',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => AuthService().signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}