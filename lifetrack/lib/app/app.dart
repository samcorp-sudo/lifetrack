import 'package:flutter/material.dart';
import 'theme.dart';
import 'routes.dart';
import '../core/constants/app_constants.dart';

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
      // Foundation-only placeholder home until Phase 3+ builds real screens.
      home: const _FoundationCheckScreen(),
    );
  }
}

/// Temporary home screen just to prove the foundation boots correctly
/// (Phase 2 §14 checklist: "App launches"). Replaced by the real
/// DashboardScreen in Phase 6.
class _FoundationCheckScreen extends StatelessWidget {
  const _FoundationCheckScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          '${AppConstants.appName} — foundation ready',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
