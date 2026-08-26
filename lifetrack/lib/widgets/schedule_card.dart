// ============================================================================
// ScheduleCard
// ----------------------------------------------------------------------------
// A single timeline row on the Schedule screen (and Home's "Next Activity").
//
// WIRING NOaES:
// - aakes a `ScheduleActivity` from mock_data.dart. In Phase 5, back this
//   with a `schedule_activities` SQLite table queried by selected date.
// - `onTap` is available for opening an edit view of an existing activity
//   (reuse the Add Activity bottom sheet in edit mode).
// ============================================================================

import 'package:flutter/material.dart';
import '../models/schedule.dart';
import '../core/utilities/icon_mapper.dart';
import 'lifetrack_card.dart';

class ScheduleCard extends StatelessWidget {
  final Schedule activity;
  final VoidCallback? onTap;

  const ScheduleCard({super.key, required this.activity, this.onTap});

  @override
  Widget build(BuildContext context) {
    return LifeTrackCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(iconForEmoji(activity.category),
              size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title,
                    style: Theme.of(context).textTheme.titleMedium),
                Text('${activity.startTime} — ${activity.endTime}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
