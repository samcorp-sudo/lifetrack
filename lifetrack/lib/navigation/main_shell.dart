// ============================================================================
// MainShell — bottom navigation shell
// ----------------------------------------------------------------------------
// Matches the plan's Section 12 nav map:
//   HOME · SCHEDULE · MONEY · GOALS · MORE
//   MORE -> I'M FREE · ANALYTICS · SKILLS · SETTINGS
// (Assets, Liabilities and Tasks are reached by drilling in from Money /
// Goals / Home rather than living on the bottom bar, keeping the bar to 5
// items as the plan specifies.)
//
// WIRING NOTES:
// - Purely navigation/UI state (which tab is selected). No data wiring.
// - If deep-linking or a named-route setup is added later (e.g. opening
//   Money from a push notification about a due bill), route through this
//   shell's `_currentIndex` rather than pushing screens on top of it.
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/home/home_dashboard_screen.dart';
import '../screens/schedule/schedule_screen.dart';
import '../screens/money/money_screen.dart';
import '../screens/goals/goals_screen.dart';
import '../screens/more/more_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _screens = [
    HomeDashboardScreen(),
    ScheduleScreen(),
    MoneyScreen(),
    GoalsScreen(),
    MoreScreen(),
  ];

  static const _items = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.calendar_today_rounded, label: 'Schedule'),
    (icon: Icons.account_balance_wallet_rounded, label: 'Money'),
    (icon: Icons.flag_rounded, label: 'Goals'),
    (icon: Icons.menu_rounded, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: isDark ? LifeTrackColors.strokeDark : LifeTrackColors.strokeLight)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final selected = i == _currentIndex;
              final item = _items[i];
              return GestureDetector(
                onTap: () => setState(() => _currentIndex = i),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, color: selected ? LifeTrackColors.highlight : Theme.of(context).textTheme.bodyMedium?.color),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: selected ? LifeTrackColors.highlight : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
