// ============================================================================
// TransactionItem
// ----------------------------------------------------------------------------
// One row in a transaction list:
//   [category icon]  Title                      - ₱1,250.00
//                    Today • Category
//
// - Tapping a row opens a detail bottom sheet (category, amount, date, note).
// - The sheet's Delete button only appears when the screen passes `onDelete`
//   (a confirmation dialog is shown first).
// - The sheet's Edit button only appears when the screen passes `onEdit`.
// ============================================================================

import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

class TransactionItem extends StatelessWidget {
  final Transaction entry;
  final String Function(double) formatCurrency;

  /// Called after the user confirms deleting this transaction.
  final Future<void> Function()? onDelete;

  /// Called when the user taps Edit in the detail sheet.
  final VoidCallback? onEdit;

  const TransactionItem({
    super.key,
    required this.entry,
    required this.formatCurrency,
    this.onDelete,
    this.onEdit,
  });

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = entry.type == TransactionType.income;
    final color = isIncome ? LifeTrackColors.mint : LifeTrackColors.coral;
    final sign = isIncome ? '+' : '-';
    final hasNote = entry.note?.isNotEmpty == true;
    final title = hasNote ? entry.note! : entry.category;
    final dateLabel = _dateLabel(entry.date);
    final subtitle = hasNote ? '$dateLabel \u2022 ${entry.category}' : dateLabel;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showDetails(
        context,
        isIncome: isIncome,
        color: color,
        sign: sign,
        title: title,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                _categoryIcon(entry.category, isIncome),
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$sign ${formatCurrency(entry.amount.abs())}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // "Today", "Yesterday", "Nov 1" (adds the year if it is not this year).
  String _dateLabel(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    final base = '${_months[date.month - 1]} ${date.day}';
    return date.year == now.year ? base : '$base, ${date.year}';
  }

  IconData _categoryIcon(String category, bool isIncome) {
    final c = category.toLowerCase();
    bool has(List<String> words) => words.any(c.contains);

    if (has(['interest'])) return Icons.trending_up_rounded;
    if (has(['deposit', 'top up', 'topup', 'salary', 'income', 'allowance'])) {
      return Icons.south_west_rounded;
    }
    if (has(['food', 'dining', 'restaurant', 'coffee', 'meal', 'snack'])) {
      return Icons.restaurant_rounded;
    }
    if (has(['grocery', 'groceries', 'shop', 'market', 'store'])) {
      return Icons.shopping_bag_outlined;
    }
    if (has(['transport', 'fuel', 'gas', 'fare', 'commute', 'travel'])) {
      return Icons.directions_car_outlined;
    }
    if (has(['bill', 'utilit', 'electric', 'water', 'internet', 'rent'])) {
      return Icons.receipt_long_rounded;
    }
    if (has(['health', 'medical', 'medicine', 'pharmacy'])) {
      return Icons.medical_services_outlined;
    }
    if (has(['entertain', 'movie', 'game', 'subscription'])) {
      return Icons.movie_outlined;
    }
    if (has(['transfer', 'sent', 'send'])) return Icons.north_east_rounded;
    return isIncome ? Icons.south_west_rounded : Icons.north_east_rounded;
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
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _categoryIcon(entry.category, isIncome),
                        size: 24,
                        color: color,
                      ),
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
                  '$sign ${formatCurrency(entry.amount.abs())}',
                  valueColor: color,
                ),
                const SizedBox(height: 10),
                _detailRow(theme, 'Date', _dateLabel(entry.date)),
                if (entry.note?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  _detailRow(theme, 'Note', entry.note!),
                ],
                if (onEdit != null || onDelete != null) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (onEdit != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              onEdit!();
                            },
                            child: const Text('Edit'),
                          ),
                        ),
                      if (onEdit != null && onDelete != null)
                        const SizedBox(width: 12),
                      if (onDelete != null)
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: LifeTrackColors.coral,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _confirmDelete(context, sheetContext),
                            child: const Text('Delete'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Transactions whose delete countdown is running, so the same one cannot be
  // deleted twice while the Cancel window is open.
  static final Set<int> _pendingDeletes = <int>{};

  static const Duration _cancelWindow = Duration(seconds: 5);

  // Step 1: ask "Delete transaction?". Step 2: after the user confirms, show
  // a "Deleting..." bar with a Cancel button. The transaction is only really
  // deleted when that bar closes without Cancel being tapped.
  Future<void> _confirmDelete(
      BuildContext rowContext, BuildContext sheetContext) async {
    final id = entry.id;
    if (id != null && _pendingDeletes.contains(id)) return;

    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'This removes the transaction and adjusts the wallet balance. '
          'You will have a few seconds to cancel after you confirm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LifeTrackColors.coral,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!rowContext.mounted) return;

    // Grab the messenger before closing the sheet; it outlives this widget.
    final messenger = ScaffoldMessenger.of(rowContext);
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();

    if (id != null) _pendingDeletes.add(id);
    try {
      final reason = await messenger
          .showSnackBar(
            SnackBar(
              content: const Text('Deleting transaction...'),
              duration: _cancelWindow,
              persist: false,
              action: SnackBarAction(label: 'Cancel', onPressed: () {}),
            ),
          )
          .closed;

      if (reason == SnackBarClosedReason.action) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Deletion cancelled.')),
        );
        return;
      }

      await onDelete!();
    } finally {
      if (id != null) _pendingDeletes.remove(id);
    }
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
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.titleMedium?.copyWith(color: valueColor),
          ),
        ),
      ],
    );
  }
}
