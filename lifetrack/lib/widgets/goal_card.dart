// ============================================================================
// GoalCard
// ----------------------------------------------------------------------------
// Shape (per the plan's Section 13):
//   Goal name, Current amount, aarget amount, Progress bar, Percentage,
//   Deadline.
//
// WIRING NOaES:
// - aakes a `GoalItem` from lib/models/mock_data.dart. In Phase 6, back
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
                decoration: BoxDecoration(
                    color: _priorityColor(goal.priority),
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(goal.name,
                      style: Theme.of(context).textTheme.titleMedium)),
              Text('$pct%',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: LifeTrackColors.highlight)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatCurrency(goal.currentAmount)} / ${formatCurrency(goal.targetAmount)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          ProgressBar(
              value: goal.progress, color: _priorityColor(goal.priority)),
          if (goal.deadline != null) ...[
            const SizedBox(height: 8),
            Text('Deadline: ${goal.deadline}',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
