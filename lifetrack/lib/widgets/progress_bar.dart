// ============================================================================
// ProgressBar ("ledger tick" style)
// ----------------------------------------------------------------------------
// Used by GoalCard, SkillItem rows and the Home dashboard's Top Goal stat.
//
// WIRING NOTES:
// - `value` (0..1) must come from real data once wired:
//     Goals   -> GoalItem.progress (current / target)
//     Skills  -> SkillItem.proficiency
// - `label` is optional and only used for the default tap feedback (e.g.
//   "Savings Goal — 62%"); pass the goal/skill name so the popup reads well.
// - `onTap` is optional. This widget has no idea what it represents (goal
//   vs skill vs stat), so it can't navigate anywhere on its own — each
//   caller should pass its own `onTap` to go to a real detail screen:
//     TODO(phase6): GoalCard      -> push GoalDetailScreen(goal) once it exists.
//     TODO(phase6): SkillItem     -> push SkillDetailScreen(skill) once it exists.
//     TODO(phase6): Home Top Goal -> push GoalsScreen (or the specific
//                   GoalDetailScreen for that top goal) once wired.
//   If `onTap` is left null, tapping just shows the percentage — fine for
//   now, but every real usage should eventually pass its own handler.
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double height;
  final String? label;
  final VoidCallback? onTap;

  const ProgressBar({
    super.key,
    required this.value,
    this.color = LifeTrackColors.highlight,
    this.height = 8,
    this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track =
        isDark ? LifeTrackColors.strokeDark : LifeTrackColors.strokeLight;
    final clamped = value.clamp(0.0, 1.0);
    final percentLabel = '${(clamped * 100).round()}%';

    return Semantics(
      // Lets screen readers announce this as a progress indicator with
      // an actual value, instead of a silent empty tap target.
      label: label,
      value: percentLabel,
      child: GestureDetector(
        onTap: onTap ?? () => _showPercentage(context, percentLabel),
        child: ClipRRect(
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
                    width: constraints.maxWidth * clamped,
                    color: color,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showPercentage(BuildContext context, String percentLabel) {
    final text = label?.isNotEmpty == true ? '$label — $percentLabel' : percentLabel;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}