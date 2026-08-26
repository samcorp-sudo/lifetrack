// ============================================================================
// LifeTrackCard
// ----------------------------------------------------------------------------
// The base "ledger page" surface every other card (MoneyCard, GoalCard,
// TaskCard, ScheduleCard, StatCard) is built on top of, so the rounded
// corner, border and padding stay identical across the whole app.
//
// WIRING NOTES:
// - Presentational only, no data or callbacks to wire beyond the optional
//   `onTap` passthrough used when a card should navigate (e.g. tapping a
//   GoalCard to open goal detail — that detail screen is out of Phase 3
//   scope and should be added when Goals are wired to SQLite in Phase 6).
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LifeTrackCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const LifeTrackCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stroke = isDark ? LifeTrackColors.strokeDark : LifeTrackColors.strokeLight;

    return Material(
      color: backgroundColor ?? Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
            border: Border.all(color: stroke),
          ),
          child: child,
        ),
      ),
    );
  }
}
