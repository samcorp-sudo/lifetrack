// ============================================================================
// TransactionItem
// ----------------------------------------------------------------------------
// WIRING NOTES:
// - Takes a `TransactionEntry` from mock_data.dart. In Phase 4, replace
//   MockData.transactions with a query against a `transactions` table,
//   most recent first, and pass real rows straight into this widget.
// - Tapping a row opens a detail bottom sheet (see _showDetails below).
//   TODO(phase4): wire the "Edit" button in the sheet to push the Add/Edit
//   Transaction form pre-filled with this entry, once that form exists.
// TODO(phase4): wire the "Delete" button in the sheet to a real delete
//   (repository call + list refresh) once transactions are backed by
//   SQLite. Currently it's a no-op placeholder that just closes the sheet.
// TODO(phase4): once `Transaction` has a `date`/`createdAt` field, surface
//   it in the detail sheet under the amount.
// TODO(phase4): once `Transaction` has an `id`, use it as the ListView key
//   for the transaction list this item lives in (better than index-based
//   keys once rows can be deleted/reordered).
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
    final theme = Theme.of(context);
    final isIncome = entry.type == TransactionType.income;
    final color = isIncome ? LifeTrackColors.mint : LifeTrackColors.coral;
    final sign = isIncome ? '+' : '-';
    final title =
        entry.note?.isNotEmpty == true ? entry.note! : entry.category;

    return InkWell(
      onTap: () => _showDetails(context, isIncome: isIncome, color: color, sign: sign, title: title),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(isIncome ? Icons.add : Icons.remove,
                  size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  Text(entry.category, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            Text(
              '$sign${formatCurrency(entry.amount.abs())}',
              style: theme.textTheme.titleMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(
    BuildContext context, {
    required bool isIncome,
    required Color color,
    required String sign,
    required String title,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(isIncome ? Icons.add : Icons.remove,
                          size: 22, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleLarge),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _detailRow(theme, 'Category', entry.category),
                const SizedBox(height: 10),
                _detailRow(
                  theme,
                  'Amount',
                  '$sign${formatCurrency(entry.amount.abs())}',
                  valueColor: color,
                ),
                // TODO(phase4): _detailRow(theme, 'Date', formattedDate)
                //   once `Transaction.date` (or equivalent) exists.
                if (entry.note?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  _detailRow(theme, 'Note', entry.note!),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        // TODO(phase4): push Add/Edit Transaction form in
                        // edit mode, pre-filled with `entry`.
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: LifeTrackColors.coral,
                        ),
                        // TODO(phase4): call repository delete for this
                        // transaction, then pop and refresh the list.
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(ThemeData theme, String label, String value,
      {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            )),
        Text(value,
            style: theme.textTheme.titleMedium?.copyWith(color: valueColor)),
      ],
    );
  }
}