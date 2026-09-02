// ============================================================================
// ScheduleCard
// ----------------------------------------------------------------------------
// A single timeline row on the Schedule screen (and Home's "Next Activity").
//
// WIRING NOTES:
// - Takes a `Schedule` from the local SQLite schedule table.
// - `onTap` is available for opening an edit view of an existing activity.
// ============================================================================

import 'package:flutter/material.dart';

import '../core/utilities/date_formatter.dart';
import '../core/utilities/icon_mapper.dart';
import '../models/schedule.dart';
import 'lifetrack_card.dart';

class ScheduleCard extends StatelessWidget {
  final Schedule activity;
  final VoidCallback? onTap;

  const ScheduleCard({
    super.key,
    required this.activity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return LifeTrackCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --------------------------------------------------------------
          // Category icon chip — gives every card a consistent anchor
          // and identical left-side visual weight.
          // --------------------------------------------------------------
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExcludeSemantics(
              child: Icon(
                iconForEmoji(activity.category),
                size: 22,
                color: primary,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // --------------------------------------------------------------
          // Title + time block. Uses `Expanded` so it fills whatever
          // height the parent gives, and `mainAxisAlignment.center`
          // so the text stays vertically centered.
          // --------------------------------------------------------------
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  activity.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  // Allow up to 2 lines so short and long titles both
                  // settle into a predictable visual height.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: primary.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${DateFormatter.toDisplayTime(activity.startTime)}'
                        ' – '
                        '${DateFormatter.toDisplayTime(activity.endTime)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
