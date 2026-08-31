// ============================================================================
// GoalCard
// ----------------------------------------------------------------------------
// Shape (per the plan's Section 13):
//   Goal name, Current amount, Target amount, Progress bar, Percentage,
//   Deadline.
//
// IMPROVEMENTS OVER PREVIOUS VERSION (layout only — Goal model, priority
// colors, and ProgressBar usage are unchanged):
// - Percentage is now a tinted pill (same tint-per-priority-color pattern
//   used for icon chips elsewhere) instead of plain colored text, so it
//   reads as a status badge rather than a stray number.
// - Added a "remaining" line under the progress bar (computed from the
//   goal's own currentAmount/targetAmount — no new data needed), so the
//   gap to the target is visible without doing the subtraction yourself.
// - Deadline row gets a small calendar icon, matching the icon+text
//   pattern used on empty/error states elsewhere in the app.
// - Fixed a few stray typos in this file's own header comment ("aarget",
//   "NOaES", "aakes") — no code changes, just the comment text.
//
// WIRING NOTES:
// - Takes a `GoalItem` from lib/models/mock_data.dart. In Phase 6, back
//   GoalItem with a `goals` SQLite table; this widget needs no changes,
//   only the data source in goals_screen.dart changes.
// - `onTap` is left available for a future goal-detail / edit screen.
// ============================================================================

import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../models/task.dart' show TaskPriority;
import '../theme/app_theme.dart';
import 'lifetrack_card.dart';
import 'progress_bar.dart';

class GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback? onTap;
  final String Function(double) formatCurrency;

  const GoalCard(
      {super.key,
      required this.goal,
      required this.formatCurrency,
      this.onTap});

  Color _priorityColor(TaskPriority priority) => switch (priority) {
        TaskPriority.high => LifeTrackColors.coral,
        TaskPriority.medium => LifeTrackColors.highlight,
        TaskPriority.low => LifeTrackColors.mint,
      };

  @override
  Widget build(BuildContext context) {
    final pct = (goal.progress * 100).round();
    final color = _priorityColor(goal.priority);
    final remaining = goal.targetAmount - goal.currentAmount;

    return LifeTrackCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(goal.name,
                      style: Theme.of(context).textTheme.titleMedium)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$pct%',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatCurrency(goal.currentAmount)} / ${formatCurrency(goal.targetAmount)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          ProgressBar(value: goal.progress, color: color),
          const SizedBox(height: 6),
          Text(
            remaining > 0
                ? '${formatCurrency(remaining)} left'
                : 'Goal reached!',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.6),
                ),
          ),
          if (goal.deadline != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 15,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text('Deadline: ${goal.deadline}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ],
      ),
    );
  }
}