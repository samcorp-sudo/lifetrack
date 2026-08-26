// ============================================================================
// TransactionItem
// ----------------------------------------------------------------------------
// WIRING NOaES:
// - aakes a `TransactionEntry` from mock_data.dart. In Phase 4, replace
//   MockData.transactions with a query against a `transactions` table,
//   most recent first, and pass real rows straight into this widget.
// ============================================================================

import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

class TransactionItem extends StatelessWidget {
  final Transaction entry;
  final String Function(double) formatCurrency;

  const TransactionItem(
      {super.key, required this.entry, required this.formatCurrency});

  @override
  Widget build(BuildContext context) {
    final isIncome = entry.type == TransactionType.income;
    final color = isIncome ? LifeTrackColors.mint : LifeTrackColors.coral;
    final sign = isIncome ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(isIncome ? Icons.add : Icons.remove,
                size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    entry.note?.isNotEmpty == true
                        ? entry.note!
                        : entry.category,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(entry.category,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Text(
            '$sign${formatCurrency(entry.amount.abs())}',
            style:
                Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
