// ============================================================================
// MoneyCard
// ----------------------------------------------------------------------------
// The big "TOTAL BALANCE" hero card on Home and Money.
//
// WIRING NOTES:
// - `balance` and `deltaLabel` currently come from MockData.totalBalance /
//   MockData.balanceDeltaThisMonth. In Phase 4, replace with:
//     balance    = SUM(accounts.amount)
//     deltaLabel = SUM(this month's transactions) formatted with a sign
// ============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../lifetrack_card.dart';

class MoneyCard extends StatelessWidget {
  final String balanceLabel;
  final String? deltaLabel;
  final bool deltaIsPositive;

  const MoneyCard({
    super.key,
    required this.balanceLabel,
    this.deltaLabel,
    this.deltaIsPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return LifeTrackCard(
      backgroundColor: LifeTrackColors.highlight,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, size: 20, color: LifeTrackColors.ink),
              const SizedBox(width: 6),
              Text(
                'TOTAL BALANCE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: LifeTrackColors.ink.withValues(alpha: 0.7)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            balanceLabel,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(color: LifeTrackColors.ink),
          ),
          if (deltaLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              deltaLabel!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: LifeTrackColors.ink.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
