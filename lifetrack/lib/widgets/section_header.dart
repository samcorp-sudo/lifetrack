// ============================================================================
// SectionHeader
// ----------------------------------------------------------------------------
// WIRING NOTES:
// - `onActionTap` should route to the relevant "see all" / "add new" screen
//   once those flows exist (e.g. Money's "RECENT TRANSACTIONS" header could
//   link to a full transaction history screen — out of Phase 3 scope).
// ============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const SectionHeader({super.key, required this.title, this.actionLabel, this.onActionTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          if (actionLabel != null)
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                actionLabel!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: LifeTrackColors.highlight),
              ),
            ),
        ],
      ),
    );
  }
}
