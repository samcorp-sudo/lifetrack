// ============================================================================
// All Transactions Screen
// ----------------------------------------------------------------------------
// Reached via "View All" on the Money screen. Shows every transaction,
// grouped either by Week or by Month (toggle at the top), most recent
// group first.
// ============================================================================

import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../services/money_service.dart';
import '../../theme/app_theme.dart';
import '../../app/currency_controller.dart';
import '../../widgets/lifetrack_card.dart';
import '../../widgets/transaction_item.dart';

enum _GroupMode { week, month }

class AllTransactionsScreen extends StatefulWidget {
  final MoneyService moneyService;

  const AllTransactionsScreen({super.key, required this.moneyService});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  late Future<List<Transaction>> _future;
  _GroupMode _mode = _GroupMode.week;

  @override
  void initState() {
    super.initState();
    _future = widget.moneyService.getAllTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              const SizedBox(height: 16),
              SegmentedButton<_GroupMode>(
                segments: const [
                  ButtonSegment(value: _GroupMode.week, label: Text('By Week')),
                  ButtonSegment(
                      value: _GroupMode.month, label: Text('By Month')),
                ],
                selected: {_mode},
                onSelectionChanged: (selected) =>
                    setState(() => _mode = selected.first),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Transaction>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                          child: Text('Unable to load transactions.'));
                    }
                    final transactions = snapshot.data ?? const <Transaction>[];
                    if (transactions.isEmpty) {
                      return Center(
                        child: Text('No transactions yet.',
                            style: Theme.of(context).textTheme.bodyMedium),
                      );
                    }

                    final grouped = _mode == _GroupMode.week
                        ? _groupByWeek(transactions)
                        : _groupByMonth(transactions);

                    return ListView(
                      children: [
                        for (final entry in grouped.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 4),
                            child: Text(entry.key,
                                style: Theme.of(context).textTheme.titleSmall),
                          ),
                          LifeTrackCard(
                            child: Column(
                              children: entry.value
                                  .map((t) => TransactionItem(
                                      entry: t, formatCurrency: _peso))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Text('All Transactions', style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }

  /// Groups by ISO week, labeled "This Week" / "Last Week" / date-range.
  Map<String, List<Transaction>> _groupByWeek(List<Transaction> transactions) {
    final now = DateTime.now();
    final currentWeekStart = _startOfWeek(now);
    final lastWeekStart = currentWeekStart.subtract(const Duration(days: 7));

    final Map<String, List<Transaction>> grouped = {};
    final List<String> orderedKeys = [];

    for (final t in transactions) {
      final date = DateTime.tryParse(t.date) ?? now;
      final weekStart = _startOfWeek(date);
      final label = _isSameDay(weekStart, currentWeekStart)
          ? 'This Week'
          : _isSameDay(weekStart, lastWeekStart)
              ? 'Last Week'
              : _weekRangeLabel(weekStart);

      if (!grouped.containsKey(label)) {
        grouped[label] = [];
        orderedKeys.add(label);
      }
      grouped[label]!.add(t);
    }

    return {for (final key in orderedKeys) key: grouped[key]!};
  }

  /// Groups by calendar month, labeled "August 2026".
  Map<String, List<Transaction>> _groupByMonth(List<Transaction> transactions) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final Map<String, List<Transaction>> grouped = {};
    final List<String> orderedKeys = [];

    for (final t in transactions) {
      final date = DateTime.tryParse(t.date) ?? DateTime.now();
      final label = '${monthNames[date.month - 1]} ${date.year}';

      if (!grouped.containsKey(label)) {
        grouped[label] = [];
        orderedKeys.add(label);
      }
      grouped[label]!.add(t);
    }

    return {for (final key in orderedKeys) key: grouped[key]!};
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized
        .subtract(Duration(days: normalized.weekday % 7)); // Sun-start
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekRangeLabel(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    const months = [
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
    return '${months[weekStart.month - 1]} ${weekStart.day} – ${months[weekEnd.month - 1]} ${weekEnd.day}';
  }

  String _peso(double value) => CurrencyController.format(value);
}
