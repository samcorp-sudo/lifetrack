// ============================================================================
// More Screen — hub for everything off the 5-item bottom bar
// ----------------------------------------------------------------------------
// Per plan Section 12's nav map, MORE fans out to I'M FREE, ANALYTICS,
// SKILLS, SETTINGS. Assets, Liabilities and Tasks aren't in that map but
// need an entry point somewhere, so they're grouped here too rather than
// crowding the bottom bar past 5 items.
//
// WIRING NOTES:
// - Purely navigation — each tile pushes the corresponding screen. No data
//   wiring lives in this file itself.
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

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: Icons.bolt_rounded, label: "I'm Free", screen: const ImFreeScreen()),
      (icon: Icons.insights_rounded, label: 'Analytics', screen: const AnalyticsScreen()),
      (icon: Icons.psychology_rounded, label: 'Skills', screen: const SkillsScreen()),
      (icon: Icons.task_alt_rounded, label: 'Tasks', screen: const TasksScreen()),
      (icon: Icons.account_balance_rounded, label: 'Assets', screen: const AssetsScreen()),
      (icon: Icons.credit_card_rounded, label: 'Liabilities', screen: const LiabilitiesScreen()),
      (icon: Icons.settings_rounded, label: 'Settings', screen: const SettingsScreen()),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
        children: [
          Text('More', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LifeTrackCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => item.screen)),
                child: Row(
                  children: [
                    Icon(item.icon, size: 22, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 14),
                    Expanded(child: Text(item.label, style: Theme.of(context).textTheme.titleMedium)),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
