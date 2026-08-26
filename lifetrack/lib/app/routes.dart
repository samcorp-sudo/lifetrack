import 'package:flutter/material.dart';

/// Named routes for the 5 bottom-nav destinations + "More" sub-screens
/// (Phase 2 §6 navigation tree). Screens themselves are built in later
/// phases (3-8) — this file just reserves their route names now so
/// `app.dart` and any early navigation code has a stable place to point to.
class AppRoutes {
  static const String dashboard = '/';
  static const String schedule = '/schedule';
  static const String money = '/money';
  static const String goals = '/goals';

  // Inside "More"
  static const String imFree = '/im-free';
  static const String analytics = '/analytics';
  static const String skills = '/skills';
  static const String settings = '/settings';

  /// Populated as each screen is built in later phases.
  static Map<String, WidgetBuilder> get routes => {
        // dashboard: (context) => const DashboardScreen(),
        // schedule: (context) => const ScheduleScreen(),
        // money: (context) => const MoneyScreen(),
        // goals: (context) => const GoalsScreen(),
        // imFree: (context) => const ImFreeScreen(),
        // analytics: (context) => const AnalyticsScreen(),
        // skills: (context) => const SkillsScreen(),
        // settings: (context) => const SettingsScreen(),
      };
}
