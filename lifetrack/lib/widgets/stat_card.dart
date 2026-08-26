// ============================================================================
// StatCard
// ----------------------------------------------------------------------------
// The small paired stat tiles on Home ("Net Worth" / "Top Goal") and reused
// on Analytics/Assets where a single labeled number needs emphasis.
//
// WIRING NOTES:
// - `value` and `progress` are passed in by the caller from MockData today.
//   Replace at the call site once Phase 6/7 wire real aggregation queries
//   (e.g. Net Worth = SUM(assets) - SUM(liabilities)).
// ============================================================================

import 'package:flutter/material.dart';
import 'lifetrack_card.dart';
import 'progress_bar.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double? progress; // optional 0..1, shows a mini progress bar if set

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return LifeTrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ProgressBar(value: progress!),
          ],
        ],
      ),
    );
  }
}
