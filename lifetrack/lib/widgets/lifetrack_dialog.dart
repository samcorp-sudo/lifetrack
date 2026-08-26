// ============================================================================
// LifeTrackDialog
// ----------------------------------------------------------------------------
// Shared confirm/alert dialog shell (used e.g. by Settings > Delete All
// Data, and any destructive or confirming action added in later phases).
//
// WIRING NOTES:
// - `onConfirm` should call the real destructive/confirm action (e.g. a
//   DatabaseService.wipeAll() in Phase 9 Security + Backup). Currently
//   nothing calls this outside of the Settings screen's placeholder.
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'lifetrack_button.dart';

class LifeTrackDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final bool isDestructive;

  const LifeTrackDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog(
      context: context,
      builder: (_) => LifeTrackDialog(
        title: title,
        message: message,
        onConfirm: onConfirm,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: LifeTrackButton(
                    label: cancelLabel,
                    style: LifeTrackButtonStyle.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LifeTrackButton(
                    label: confirmLabel,
                    style: isDestructive ? LifeTrackButtonStyle.danger : LifeTrackButtonStyle.primary,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
