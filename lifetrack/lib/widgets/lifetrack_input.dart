// ============================================================================
// LifeTrackInput
// ----------------------------------------------------------------------------
// Shared text field style used by the Add Activity sheet, Add Transaction,
// Add Goal, etc.
//
// WIRING NOTES:
// - Pass a real `controller` and `validator` from the parent form. This
//   widget does not persist anything itself — the parent's save handler
//   (e.g. "Save Activity" in Phase 5) is what writes to SQLite.
// - `onChanged` is exposed for parents that need live validation before
//   the form's Save button is wired up.
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LifeTrackInput extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final TextInputType keyboardType;

  const LifeTrackInput({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.trailing,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stroke = isDark ? LifeTrackColors.strokeDark : LifeTrackColors.strokeLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          onTap: onTap,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isDark ? LifeTrackColors.textOnDark : LifeTrackColors.textOnLight,
              ),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: trailing,
            filled: true,
            fillColor: Theme.of(context).cardColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
              borderSide: BorderSide(color: stroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
              borderSide: BorderSide(color: stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
              borderSide: const BorderSide(color: LifeTrackColors.highlight, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
