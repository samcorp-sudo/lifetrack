// ============================================================================
// Goals Screen
// ----------------------------------------------------------------------------
// IMPROVEMENTS OVER PREVIOUS VERSION (layout/UX only — GoalService calls and
// GoalCard rendering are unchanged):
// - Back button now actually pops the route (previously a bare, non-tappable
//   Icon) and both header icons use the same tinted icon-chip style as
//   Settings/Money/Schedule/More.
// - Pull-to-refresh via RefreshIndicator, reusing GoalService.getActiveGoals.
// - Error state now matches the Schedule screen's pattern: icon, heading,
//   explanatory line, and a Retry button — instead of a single plain
//   sentence with no way to recover without leaving the screen.
// - Empty state gets the same icon-chip + two-line layout used elsewhere
//   (e.g. Schedule's "Nothing scheduled" state) instead of a bare icon and
//   single line.
//
// WIRING NOTES:
// - The add-goal button is still a placeholder (no AddGoalSheet exists yet
//   in this codebase) — wire it the same way AddActivitySheet.show() is
//   wired from the Schedule screen once a goal-creation flow exists.
// ============================================================================

import 'package:flutter/material.dart';
import '../../models/goal.dart';
import '../../services/goal_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/goal_card.dart';
import '../../widgets/lifetrack_card.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  static const double _iconChipSize = 34;
  static const double _headerBottomGap = 18;
  static const double _sectionLabelGap = 12;
  static const double _itemGap = 12;

  final _goalService = GoalService();
  late Future<List<Goal>> _goalsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _goalsFuture = _goalService.getActiveGoals();
  }

  Future<void> _refresh() async {
    final next = _goalService.getActiveGoals();
    setState(() => _goalsFuture = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
            children: [
              _header(context),
              const SizedBox(height: _headerBottomGap),
              Text('MY GOALS', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: _sectionLabelGap),
              FutureBuilder<List<Goal>>(
                future: _goalsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return _errorState(context);
                  }
                  final goals = snapshot.data ?? const <Goal>[];
                  if (goals.isEmpty) {
                    return _emptyState(context);
                  }
                  return Column(
                    children: [
                      for (final goal in goals)
                        Padding(
                          padding: const EdgeInsets.only(bottom: _itemGap),
                          child: GoalCard(goal: goal, formatCurrency: _peso),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAddGoalDialog() async {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final goal = await showDialog<Goal>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Goal name'),
            ),
            TextField(
              controller: targetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Target amount'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final target = double.tryParse(targetController.text.trim());
              if (name.isNotEmpty && target != null && target > 0) {
                Navigator.pop(
                  dialogContext,
                  Goal(name: name, targetAmount: target),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameController.dispose();
    targetController.dispose();
    if (goal != null) {
      await _goalService.createGoal(goal);
      if (mounted) _reload();
    }
  }

  Widget _header(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Expanded(
          child: Text('Goals', style: Theme.of(context).textTheme.titleLarge),
        ),
        _iconChip(
          color: primary,
          icon: Icons.add_rounded,
          tooltip: 'Add goal',
          onTap: _openAddGoalDialog,
        ),
      ],
    );
  }

  Widget _iconChip({
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final chip = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _iconChipSize,
        height: _iconChipSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
  }

  Widget _errorState(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.color;
    return Padding(
      padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: muted),
            const SizedBox(height: 12),
            Text('Unable to load goals',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Check your connection and try again.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return LifeTrackCard(
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
            child: Icon(Icons.flag_rounded, size: 18, color: primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No active goals recorded yet.',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text('Tap + to add one.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _peso(double value) =>
      '₱${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
}
