// ============================================================================
// MainShell - Modern bottom navigation shell
// ----------------------------------------------------------------------------
// Navigation:
//   SCHEDULE - MONEY - HOME - GOALS - FREE - MORE
//
// MORE contains:
//   I'M FREE - ANALYTICS - SKILLS - SETTINGS
//
// UI:
// - Solid floating rounded navigation bar with soft shadow
// - Icon on top, label always visible underneath
// - Selected tab: season-colored icon pill + bold label
// - Animated color / pill transitions
// - Material ripple feedback
// - Dark-mode aware (card color, shadow, accent shade)
// - Large touch targets
// ============================================================================

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../screens/home/home_dashboard_screen.dart';
import '../screens/schedule/schedule_screen.dart';
import '../screens/money/money_screen.dart';
import '../screens/goals/goals_screen.dart';
import '../screens/im_free/im_free_screen.dart';
import '../screens/more/more_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _dashboardIndex = 2;

  static const Duration _animationDuration = Duration(milliseconds: 280);

  int _currentIndex = _dashboardIndex;
  int _homeRefreshKey = 0;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _buildScreens();
  }

  void _buildScreens() {
    _screens = [
      const ScheduleScreen(),
      const MoneyScreen(),
      HomeDashboardScreen(
        key: ValueKey(_homeRefreshKey),
      ),
      const GoalsScreen(),
      const ImFreeScreen(),
      const MoreScreen(),
    ];
  }

  static const _items = [
    (
      icon: Icons.calendar_month_rounded,
      label: 'Schedule',
    ),
    (
      icon: Icons.account_balance_wallet_rounded,
      label: 'Money',
    ),
    (
      icon: Icons.home_rounded,
      label: 'Home',
    ),
    (
      icon: Icons.flag_rounded,
      label: 'Goals',
    ),
    (
      icon: Icons.bolt_rounded,
      label: 'Free',
    ),
    (
      icon: Icons.more_horiz_rounded,
      label: 'More',
    ),
  ];

  void _select(int index) {
    if (index == _currentIndex) {
      // Refresh dashboard even when tapping Home again.
      if (index == _dashboardIndex) {
        setState(() {
          _homeRefreshKey++;
          _buildScreens();
        });
      }
      return;
    }

    setState(() {
      _currentIndex = index;
      _buildScreens();

      if (index == _dashboardIndex) {
        _homeRefreshKey++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNavigationBar(
        currentIndex: _currentIndex,
        items: _items,
        dashboardIndex: _dashboardIndex,
        animationDuration: _animationDuration,
        isDark: isDark,
        onSelected: _select,
      ),
    );
  }
}

// ============================================================================
// Bottom Navigation Container
// ============================================================================

class _BottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final List<
      ({
        IconData icon,
        String label,
      })> items;

  final int dashboardIndex;
  final Duration animationDuration;
  final bool isDark;
  final ValueChanged<int> onSelected;

  const _BottomNavigationBar({
    required this.currentIndex,
    required this.items,
    required this.dashboardIndex,
    required this.animationDuration,
    required this.isDark,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewPadding.bottom + 12,
      ),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: theme.cardColor, // solid white (light) / panel (dark)
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            return Expanded(
              child: _NavigationItem(
                icon: item.icon,
                label: item.label,
                selected: index == currentIndex,
                duration: animationDuration,
                onTap: () => onSelected(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ============================================================================
// Navigation Item  (icon on top, label always visible)
// ============================================================================

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    // accentText is deeper in light mode and brighter in dark mode,
    // so the selected tab stays readable on both.
    final activeColor = s.accentText;
    final inactiveColor =
        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6);
    final color = selected ? activeColor : inactiveColor;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: activeColor.withValues(alpha: 0.10),
          highlightColor: activeColor.withValues(alpha: 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                width: 48,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? s.accent.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: duration,
                  style: (theme.textTheme.labelSmall ?? const TextStyle())
                      .copyWith(
                    color: color,
                    fontSize: 11,
                    letterSpacing: 0,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(label, maxLines: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
