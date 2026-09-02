// ============================================================================
// TaskCard
// ----------------------------------------------------------------------------
// WIRING NOTES:
// - `onToggle` currently just flips local UI state via the parent screen's
//   setState (see tasks_screen.dart). Wire it to
//   TaskRepository.setDone(task.id, value) once the `tasks` table exists
//   (Phase 4+ / general task persistence).
// ============================================================================

import 'package:flutter/material.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import 'lifetrack_card.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final ValueChanged<bool?>? onToggle;

  const TaskCard({super.key, required this.task, this.onToggle});


  @override
  Widget build(BuildContext context) {
    return LifeTrackCard(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 36,
            decoration: BoxDecoration(color: task.priority == TaskPriority.high ? LifeTrackColors.coral : task.priority == TaskPriority.low ? LifeTrackColors.mint : LifeTrackColors.highlight, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: task.status == TaskStatus.done ? TextDecoration.lineThrough : null,
                        color: task.status == TaskStatus.done
                            ? Theme.of(context).textTheme.bodyMedium?.color
                            : Theme.of(context).textTheme.titleMedium?.color,
                      ),
                ),
                if (task.dueDate != null)
                  Text(task.dueDate!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Checkbox(
            value: task.status == TaskStatus.done,
            onChanged: onToggle,
            activeColor: LifeTrackColors.highlight,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ],
      ),
    );
  }
}
