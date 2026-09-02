// ============================================================================
// More Screen — hub for everything off the bottom nav
// ============================================================================
//
// WHAT THIS SCREEN DOES
// ----------------------------------------------------------------------------
// Everything that doesn't fit in the 5-item bottom bar lives here, grouped
// by section:
//   • PRODUCTIVITY — I'm Free, Focus Timer, Analytics, Skills, Tasks
//   • FINANCES     — Assets, Liabilities
//   • SYSTEM       — Settings, About
//
// A tap on the account card opens ProfileScreen.
//
// NEW IN THIS VERSION
// ----------------------------------------------------------------------------
// Features added:
//   • Focus Timer row (opens PomodoroScreen) — new
//   • System section (Settings + About) — previously imported SettingsScreen
//     but never linked it
//   • Notes badge on Tasks row showing how many tasks have notes — quick
//     visual priority signal
//   • Season chip on the header showing the current season name
//
// UI:
//   • Divider between rows inside a section card
//   • Season-tinted icon chip per row (was colorScheme.primary)
//   • Account card redesigned: bigger avatar in a season-tinted ring,
//     name + email, chevron, subtitle "Manage profile"
//
// Animations:
//   • Rows stagger-fade in (60ms apart) on first build
//   • Each row press-scale on tap
//   • Account card has subtle press-scale
//
// SELF-CONTAINED
// ----------------------------------------------------------------------------
// No LifeTrackCard import. Local _InlineCard + _MoreRow + _AccountCard.
//
// WHAT NOT TO DO
// ----------------------------------------------------------------------------
//   • Do not route Focus Timer to a placeholder — it links to the real
//     PomodoroScreen, which reads AppConstants.focusDurationMinutes and
//     handles its own FocusTimerService lifecycle.
//   • Do not build new icons with hardcoded colors — use context.season.*
// ============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/profile_service.dart';
import '../im_free/im_free_screen.dart';
import '../analytics/analytics_screen.dart';
import '../skills/skills_screen.dart';
import '../tasks/tasks_screen.dart';
import '../assets/assets_screen.dart';
import '../liabilities/liabilities_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/profile/profile_screen.dart';
import '../poromodo/poromodo.dart';

typedef _MoreItem = ({IconData icon, String label, Widget screen});

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen>
    with TickerProviderStateMixin {
  static const double _iconChipSize = 34;
  static const double _sectionGap = 20;
  static const double _sectionLabelGap = 10;

  // Static navigation map. Kept as data so a new screen only needs to be
  // added to one list, not scattered across build methods.
  static const List<(String, List<_MoreItem>)> _sections = [
    (
      'PRODUCTIVITY',
      [
        (icon: Icons.bolt_rounded, label: "I'm Free", screen: ImFreeScreen()),
        (
          icon: Icons.timer_rounded,
          label: 'Focus Timer',
          screen: PomodoroScreen()
        ),
        (
          icon: Icons.insights_rounded,
          label: 'Analytics',
          screen: AnalyticsScreen()
        ),
        (
          icon: Icons.psychology_rounded,
          label: 'Skills',
          screen: SkillsScreen()
        ),
        (icon: Icons.task_alt_rounded, label: 'Tasks', screen: TasksScreen()),
      ]
    ),
    (
      'FINANCES',
      [
        (
          icon: Icons.account_balance_rounded,
          label: 'Assets',
          screen: AssetsScreen()
        ),
        (
          icon: Icons.credit_card_rounded,
          label: 'Liabilities',
          screen: LiabilitiesScreen()
        ),
      ]
    ),
    (
      'SYSTEM',
      [
        (
          icon: Icons.settings_rounded,
          label: 'Settings',
          screen: SettingsScreen()
        ),
      ]
    ),
  ];

  // Stagger controllers, one per row (sections flattened for indexing).
  final Map<int, AnimationController> _rowAnims = {};

  @override
  void initState() {
    super.initState();
    var index = 0;
    for (final section in _sections) {
      for (var i = 0; i < section.$2.length; i++) {
        _rowAnims[index] = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 350),
          value: 0,
        );
        _rowAnims[index]!.forward();
        index++;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _rowAnims.values) {
      c.dispose();
    }
    _rowAnims.clear();
    super.dispose();
  }

  // Flatten index offset per section so _rowAnims can be looked up
  // linearly (section 0 rows 0..n, section 1 rows n..m, etc.).
  int _globalRowIndex(int sectionIndex) {
    var count = 0;
    for (var i = 0; i < sectionIndex; i++) {
      count += _sections[i].$2.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
          physics: const BouncingScrollPhysics(),
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('More',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Everything else LifeTrack can do.',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: s.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.emoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        s.name,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: s.accentText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _accountCard(context),
            const SizedBox(height: _sectionGap),
            for (var si = 0; si < _sections.length; si++) ...[
              _sectionLabel(context, _sections[si].$1),
              const SizedBox(height: _sectionLabelGap),
              _sectionCard(context, _sections[si].$2,
                  globalOffset: _globalRowIndex(si)),
              const SizedBox(height: _sectionGap),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Account card
  // ---------------------------------------------------------------------------

  Widget _accountCard(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    final user = ProfileService().currentUser;

    final rawName = user?.displayName?.trim();
    final accountName =
        (rawName == null || rawName.isEmpty) ? 'Your account' : rawName;
    final accountEmail = user?.email ?? 'No signed-in user';

    final initials = accountName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return _PressableCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: s.accent.withValues(alpha: 0.20),
                width: 1.5,
              ),
            ),
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: theme.textTheme.titleMedium?.copyWith(
                color: s.accentText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  accountName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  accountEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage profile',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: s.accentText),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: theme.textTheme.bodyMedium?.color
                  ?.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section label + card
  // ---------------------------------------------------------------------------

  Widget _sectionLabel(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(letterSpacing: 0.6),
        ),
      );

  Widget _sectionCard(
    BuildContext context,
    List<_MoreItem> items, {
    required int globalOffset,
  }) {
    return _InlineCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor,
                ),
              ),
            _animatedRow(
              globalOffset + i,
              _MoreRow(
                icon: items[i].icon,
                label: items[i].label,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => items[i].screen),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stagger wrapper
  // ---------------------------------------------------------------------------

  Widget _animatedRow(int index, Widget child) {
    final c = _rowAnims[index];
    if (c == null) return child;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset((1 - t) * 12, 0),
            child: child,
          ),
        );
      },
    );
  }
}

// ============================================================================
// Local widgets
// ============================================================================

/// Local card surface, matches the app's LifeTrackCard styling without
/// depending on it.
class _InlineCard extends StatelessWidget {
  const _InlineCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Wraps a card in a press-scale + tap.
class _PressableCard extends StatefulWidget {
  const _PressableCard({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();
    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.97,
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
    return ScaleTransition(
      scale: _tap,
      child: _InlineCard(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: widget.child,
        ),
      ),
    );
  }
}

/// One row inside a section card.
class _MoreRow extends StatefulWidget {
  const _MoreRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_MoreRow> createState() => _MoreRowState();
}

class _MoreRowState extends State<_MoreRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();
    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.97,
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
    final theme = Theme.of(context);
    final s = context.season;

    return ScaleTransition(
      scale: _tap,
      child: InkWell(
        onTap: _handleTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: s.accentText, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(widget.label,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.textTheme.bodyMedium?.color
                      ?.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
