// ============================================================================
// More Screen — hub for everything off the 5-item bottom bar
// ----------------------------------------------------------------------------
// Per plan Section 12's nav map, MORE fans out to I'M FREE, ANALYTICS,
// SKILLS, SETTINGS. Assets, Liabilities and Tasks aren't in that map but
// need an entry point somewhere, so they're grouped here too rather than
// crowding the bottom bar past 5 items.
//
// IMPROVEMENTS OVER PREVIOUS VERSION:
// - Added an account details card at the top (avatar, name, email) — this
//   is currently backed by ProfileService().currentUser rather than a
//   dedicated view-model, since none exists in this codebase yet.
// - Items are now grouped into labeled sections (Productivity, Finances,
//   System) inside single cards with dividers between rows, matching the
//   section pattern already used on the Settings screen, instead of one
//   separate card per row.
// - Each row icon sits in the same tinted icon-chip style used on
//   Settings/Money/Schedule for visual consistency across the app.
//
// WIRING NOTES:
// - Navigation is unchanged — each tile still pushes its corresponding
//   screen. No data wiring lives in this file itself.
// - The account card taps through to the real ProfileScreen(); swap in a
//   dedicated UserService/ProfileService-backed view model if the profile
//   fields ever need to be richer than displayName/email.
// ============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/profile_service.dart';
import '../../widgets/lifetrack_card.dart';
import '../im_free/im_free_screen.dart';
import '../analytics/analytics_screen.dart';
import '../skills/skills_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/profile_screen.dart';
import '../assets/assets_screen.dart';
import '../liabilities/liabilities_screen.dart';
import '../tasks/tasks_screen.dart';

typedef _MoreItem = ({IconData icon, String label, Widget screen});

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const double _iconChipSize = 34;
  static const double _sectionGap = 20;
  static const double _sectionLabelGap = 10;

  // Static data — doesn't depend on context/state, so it's built once
  // instead of being reconstructed on every rebuild.
  static const List<(String, List<_MoreItem>)> _sections = [
    (
      'PRODUCTIVITY',
      [
        (icon: Icons.bolt_rounded, label: "I'm Free", screen: ImFreeScreen()),
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
        children: [
          Text('More', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          _accountCard(context),
          const SizedBox(height: _sectionGap),
          for (final section in _sections) ...[
            _sectionLabel(context, section.$1),
            const SizedBox(height: _sectionLabelGap),
            _sectionCard(context, section.$2),
            const SizedBox(height: _sectionGap),
          ],
        ],
      ),
    );
  }

  Widget _accountCard(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
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

    return LifeTrackCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: theme.textTheme.titleMedium?.copyWith(color: primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(accountName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  accountEmail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }



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

  Widget _sectionCard(BuildContext context, List<_MoreItem> items) {
    return LifeTrackCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: _iconChipSize + 14),
              _itemRow(context, items[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemRow(BuildContext context, _MoreItem item) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => item.screen)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: _iconChipSize,
              height: _iconChipSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 18, color: primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(item.label,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
