// ============================================================================
// ProgressBar ("ledger tick" style)
// ----------------------------------------------------------------------------
// Used by GoalCard, SkillItem rows and the Home dashboard's Top Goal stat.
//
// WIRING NOTES:
// - `value` (0..1) must come from real data once wired:
//     Goals   -> GoalItem.progress (current / target)
//     Skills  -> SkillItem.proficiency
//   Nothing else to connect; this widget is purely visual.
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double height;

  const ProgressBar({
    super.key,
    required this.value,
    this.color = LifeTrackColors.highlight,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = isDark ? LifeTrackColors.strokeDark : LifeTrackColors.strokeLight;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Container(height: height, color: track),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                height: height,
                width: constraints.maxWidth * value.clamp(0, 1),
                color: color,
              ),
            ],
          );
        },
      ),
    );
  }
}
