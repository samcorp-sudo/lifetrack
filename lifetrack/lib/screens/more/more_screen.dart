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
//   is currently placeholder data passed via constructor params (see
//   WIRING NOTES below) rather than a real profile screen, since none
//   exists in this codebase yet.
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
// - Account name/email are placeholder constructor params. Wire these to
//   a real UserService/ProfileService once one exists, and wire the
//   account card's onTap to an actual account/profile screen (currently
//   a no-op placeholder).
// ============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifetrack_card.dart';
import '../im_free/im_free_screen.dart';
import '../analytics/analytics_screen.dart';
import '../skills/skills_screen.dart';
import '../settings/settings_screen.dart';
import '../assets/assets_screen.dart';
import '../liabilities/liabilities_screen.dart';
import '../tasks/tasks_screen.dart';

typedef _MoreItem = ({IconData icon, String label, Widget screen});

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    this.accountName = 'Alex Rivera',
    this.accountEmail = 'alex.rivera@email.com',
  });

  // TODO: wire to a real UserService/ProfileService instead of defaults.
  final String accountName;
  final String accountEmail;

  static const double _iconChipSize = 34;
  static const double _sectionGap = 20;
  static const double _sectionLabelGap = 10;

  @override
  Widget build(BuildContext context) {
    final sections = <(String, List<_MoreItem>)>[
      (
        'PRODUCTIVITY',
        [
          (
            icon: Icons.bolt_rounded,
            label: "I'm Free",
            screen: const ImFreeScreen()
          ),
          (
            icon: Icons.insights_rounded,
            label: 'Analytics',
            screen: const AnalyticsScreen()
          ),
          (
            icon: Icons.psychology_rounded,
            label: 'Skills',
            screen: const SkillsScreen()
          ),
          (
            icon: Icons.task_alt_rounded,
            label: 'Tasks',
            screen: const TasksScreen()
          ),
        ]
      ),
      (
        'FINANCES',
        [
          (
            icon: Icons.account_balance_rounded,
            label: 'Assets',
            screen: const AssetsScreen()
          ),
          (
            icon: Icons.credit_card_rounded,
            label: 'Liabilities',
            screen: const LiabilitiesScreen()
          ),
        ]
      ),
      (
        'SYSTEM',
        [
          (
            icon: Icons.settings_rounded,
            label: 'Settings',
            screen: const SettingsScreen()
          ),
        ]
      ),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
        children: [
          Text('More', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          _accountCard(context),
          const SizedBox(height: _sectionGap),
          for (final section in sections) ...[
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
    final primary = Theme.of(context).colorScheme.primary;
    final initials = accountName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return LifeTrackCard(
      onTap: () {
        // TODO: push a real account/profile screen once one exists.
      },
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
              initials,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: primary,
                  ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(accountName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  accountEmail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
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
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 0.6,
              ),
        ),
      );

  Widget _sectionCard(BuildContext context, List<_MoreItem> items) {
    return LifeTrackCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: _iconChipSize + 14),
            _itemRow(context, items[i]),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(BuildContext context, _MoreItem item) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => item.screen)),
      behavior: HitTestBehavior.opaque,
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
              child:
                  Text(item.label, style: Theme.of(context).textTheme.titleMedium),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}