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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stroke =
        isDark ? LifeTrackColors.strokeDark : LifeTrackColors.strokeLight;
    final radius = BorderRadius.circular(LifeTrackMetrics.cardRadius);

    final card = Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias, // keeps child content within the rounded shape
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: stroke),
          ),
          child: child,
        ),
      ),
    );

    // Announce the whole card as a single tappable element when it
    // navigates, instead of the child's individual text/icons.
    return onTap == null ? card : Semantics(button: true, child: card);
  }
}