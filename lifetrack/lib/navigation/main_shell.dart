// ============================================================================
// MainShell — bottom navigation shell
// ----------------------------------------------------------------------------
// Matches the plan's Section 12 nav map:
//   SCHEDULE · MONEY · HOME (center) · GOALS · MORE
//   MORE -> I'M FREE · ANALYTICS · SKILLS · SETTINGS
// (Assets, Liabilities and Tasks are reached by drilling in from Money /
// Goals / Home rather than living on the bottom bar, keeping the bar to 5
// items as the plan specifies.)
//
// Dashboard is the center item, rendered as a raised circular button.
// Design pass: rounded top corners + soft elevation on the bar, an
// animated selection pill behind the side icons, and gentle scale/color
// transitions so switching tabs feels smooth rather than instant.
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
  static const int _dashboardIndex = 2;
  static const Duration _animDuration = Duration(milliseconds: 220);

  int _currentIndex = _dashboardIndex;
  int _homeRefreshKey = 0;

  List<Widget> get _screens => [
        const ScheduleScreen(),
        const MoneyScreen(),
        HomeDashboardScreen(key: ValueKey(_homeRefreshKey)),
        const GoalsScreen(),
        const MoreScreen(),
      ];

  static const _items = [
    (icon: Icons.calendar_today_rounded, label: 'Schedule'),
    (icon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
    (icon: Icons.home_rounded, label: 'Dashboard'),
    (icon: Icons.flag_rounded, label: 'Goals'),
    (icon: Icons.menu_rounded, label: 'More'),
  ];

  void _select(int i) {
    if (i == _currentIndex) return;
    setState(() {
      _currentIndex = i;
      if (i == _dashboardIndex) _homeRefreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor =
        Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : Colors.black)
                  .withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_items.length, (i) {
                final selected = i == _currentIndex;
                final item = _items[i];
                final isCenter = i == _dashboardIndex;

                if (isCenter) {
                  return _CenterButton(
                    icon: item.icon,
                    selected: selected,
                    duration: _animDuration,
                    onTap: () => _select(i),
                  );
                }

                return _SideNavItem(
                  icon: item.icon,
                  selected: selected,
                  mutedColor: mutedColor,
                  duration: _animDuration,
                  onTap: () => _select(i),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the four regular tabs (Schedule, Wallet, Goals, More). Selection
/// is shown with a soft rounded pill behind the icon, plus a color and
/// gentle scale transition — not just an abrupt color swap.
class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final Color? mutedColor;
  final Duration duration;
  final VoidCallback onTap;

  const _SideNavItem({
    required this.icon,
    required this.selected,
    required this.mutedColor,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = LifeTrackColors.highlight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1.0,
              duration: duration,
              curve: Curves.easeOut,
              child: Icon(
                icon,
                size: 22,
                color: selected ? activeColor : mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The center Dashboard button — a raised circle that sits above the bar,
/// with a soft glow shadow and a subtle press/selection scale so it feels
/// tactile rather than static.
class _CenterButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  const _CenterButton({
    required this.icon,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = LifeTrackColors.highlight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Transform.translate(
        offset: const Offset(0, -14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.0 : 0.94,
              duration: duration,
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOut,
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      activeColor,
                      activeColor.withValues(alpha: 0.82),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          activeColor.withValues(alpha: selected ? 0.45 : 0.3),
                      blurRadius: selected ? 12 : 8,
                      spreadRadius: selected ? 1 : 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Theme.of(context).cardColor,
                    width: 3,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
