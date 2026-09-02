// ============================================================================
// LifeTrackButton
// ----------------------------------------------------------------------------
// WIRING NOTES:
// - Purely presentational. Pass a real `onPressed` callback from the caller;
//   this widget never contains business logic itself.
// - `isLoading` is wired up (shows a spinner) so async save/submit handlers
//   in later phases (e.g. saving a transaction) have something to flip on.
//
// IMPROVEMENTS OVER PREVIOUS VERSION (visual only — the public API, style
// enum, and every call site are unchanged):
// - Disabled state (onPressed == null, not loading) is now visually dimmed.
//   Previously a disabled button looked identical to an enabled one — same
//   full-opacity background and text — so there was no way to tell a
//   button couldn't be tapped without trying it.
// - Ripple/splash color is now derived from each style's own foreground
//   color instead of the theme's default splash, so tap feedback looks
//   intentional on every style (especially `ghost` and `secondary`, where
//   the default splash could look too dark or too bright against a custom
//   background).
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum LifeTrackButtonStyle { primary, secondary, danger, ghost }

class LifeTrackButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final LifeTrackButtonStyle style;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const LifeTrackButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = LifeTrackButtonStyle.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onPressed == null && !isLoading;

    Color bg;
    Color fg;
    BoxBorder? border;

    switch (style) {
      case LifeTrackButtonStyle.primary:
        bg = LifeTrackColors.highlight;
        fg = isDark ? LifeTrackColors.ink : LifeTrackColors.textOnLight;
        break;
      case LifeTrackButtonStyle.secondary:
        bg = isDark ? LifeTrackColors.panelDark : LifeTrackColors.panelLight;
        fg = isDark ? LifeTrackColors.textOnDark : LifeTrackColors.textOnLight;
        border = Border.all(color: isDark ? LifeTrackColors.strokeDark : LifeTrackColors.strokeLight);
        break;
      case LifeTrackButtonStyle.danger:
        bg = LifeTrackColors.coral;
        fg = Colors.white;
        break;
      case LifeTrackButtonStyle.ghost:
        bg = Colors.transparent;
        fg = isDark ? LifeTrackColors.textOnDark : LifeTrackColors.textOnLight;
        break;
    }

    if (disabled) {
      bg = style == LifeTrackButtonStyle.ghost
          ? bg
          : bg.withValues(alpha: 0.35);
      fg = fg.withValues(alpha: 0.4);
      if (border != null) {
        border = Border.all(
          color: (isDark ? LifeTrackColors.strokeDark : LifeTrackColors.strokeLight)
              .withValues(alpha: 0.4),
        );
      }
    }

    final child = isLoading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
              Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg)),
            ],
          );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
          onTap: isLoading ? null : onPressed,
          splashColor: fg.withValues(alpha: 0.12),
          highlightColor: fg.withValues(alpha: 0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
              border: border,
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}