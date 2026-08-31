// NOTE: This screen expects these additional methods on AnalyticsService
// that weren't in the original file, used to power the trend cards below:
//
//   Future<List<Map<String, dynamic>>> getDailyTotalsForRange(DateTime start, DateTime end)
//     -> one entry per day in [start, end] inclusive, most recent last, each shaped as:
//        { 'date': DateTime, 'income': double, 'expenses': double }
//
//   Future<List<Map<String, dynamic>>> getMonthlyTotals(int monthsBack)
//     -> one entry per month, most recent last, each shaped as:
//        { 'month': DateTime, 'income': double, 'expenses': double, 'saved': double }
//
// If your service methods return different shapes, adjust `_load()`/`_loadWeek()`
// and the two trend widgets (`_WeeklyTrendCard`, `_MonthlyTrendCard`) accordingly.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../app/currency_controller.dart';
import '../../widgets/lifetrack_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _service = AnalyticsService();
  late Future<Map<String, dynamic>> _future;
  late Future<List<Map<String, dynamic>>> _dailyFuture;
  late DateTime _weekStart; // Monday of the currently viewed week

  static DateTime _mondayOf(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date
        .subtract(Duration(days: date.weekday - 1)); // weekday: Mon=1..Sun=7
  }

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    _future = _load();
    _dailyFuture = _loadWeek(_weekStart);
  }

  Future<Map<String, dynamic>> _load() async {
    final now = DateTime.now();
    final month = await _service.getMoneyReportForMonth(now.year, now.month);
    final spending = await _service.getSpendingBreakdown(now.year, now.month);
    final monthly = await _service.getMonthlyTotals(6);
    return {
      'month': month,
      'spending': spending,
      'monthly': monthly,
    };
  }

  Future<List<Map<String, dynamic>>> _loadWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return _service.getDailyTotalsForRange(weekStart, weekEnd);
  }

  void _retry() => setState(() {
        _future = _load();
        _dailyFuture = _loadWeek(_weekStart);
      });

  bool get _isCurrentWeek => _weekStart == _mondayOf(DateTime.now());

  void _goToPreviousWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
      _dailyFuture = _loadWeek(_weekStart);
    });
  }

  void _goToNextWeek() {
    if (_isCurrentWeek) return; // don't navigate into the future
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
      _dailyFuture = _loadWeek(_weekStart);
    });
  }

  String _peso(double value) => CurrencyController.format(value);

  void _openSpendingDetail(BuildContext context, String category, double amount,
      double total, int rank, int totalCategories, Color color) {
    final daysElapsed = DateTime.now().day.clamp(1, 31);
    final perDay = amount / daysElapsed;
    final share = total == 0 ? 0.0 : amount / total;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                  ),
                  child:
                      Icon(_iconForCategory(category), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('Rank #$rank of $totalCategories categories',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(_peso(amount),
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('total spent this month',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SHARE OF TOTAL SPENDING',
                    style: Theme.of(context).textTheme.labelSmall),
                Text('${(share * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 6,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_view_day_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('~${_peso(perDay)} / day so far this month',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (rank == 1) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.trending_up_rounded, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Your biggest expense category this month',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: color)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForCategory(String category) {
    final key = category.toLowerCase();
    if (key.contains('food') || key.contains('grocer')) {
      return Icons.restaurant_rounded;
    }
    if (key.contains('transport') ||
        key.contains('gas') ||
        key.contains('fuel')) {
      return Icons.directions_car_rounded;
    }
    if (key.contains('bill') || key.contains('utility')) {
      return Icons.receipt_long_rounded;
    }
    if (key.contains('shop') ||
    key.contains('grocery')) {
      return Icons.shopping_bag_rounded;
    }
    if (key.contains('health') || key.contains('medic') ||
    key.contains('hospital')) {
      return Icons.local_hospital_rounded;
    }
    if (key.contains('entertain') || key.contains('fun')) {
      return Icons.movie_rounded;
    }
    if (key.contains('education') || key.contains('school')) {
      return Icons.school_rounded;
    }
    if (key.contains('rent') || key.contains('housing')) {
      return Icons.home_rounded;
    }
    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.5),
                        size: 32),
                    const SizedBox(height: 8),
                    const Text('Unable to load analytics records.'),
                  ],
                ),
              );
            }

            final month = snapshot.data!['month'] as Map<String, double>;
            final spending = snapshot.data!['spending'] as Map<String, double>;
            final monthly =
                snapshot.data!['monthly'] as List<Map<String, dynamic>>? ??
                    const <Map<String, dynamic>>[];

            final income = month['income'] ?? 0;
            final expenses = month['expenses'] ?? 0;
            final saved = month['saved'] ?? 0;
            final spentTotal = spending.values.fold<double>(0, (a, b) => a + b);
            final sortedSpending = spending.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            final palette = [
              LifeTrackColors.highlight,
              LifeTrackColors.mint,
              LifeTrackColors.coral,
            ];

            return ListView(
              padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
              physics: const BouncingScrollPhysics(),
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.08),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Analytics',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 12),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMMM yyyy')
                                .format(DateTime.now())
                                .toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Hero savings card
                LifeTrackCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NET SAVED THIS MONTH',
                          style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Icon(Icons.savings_rounded,
                              color: LifeTrackColors.highlight, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _peso(saved),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 8,
                          child: Row(
                            children: [
                              Expanded(
                                flex: (income <= 0 ? 1 : income).round(),
                                child: Container(
                                    color: LifeTrackColors.mint
                                        .withValues(alpha: 0.85)),
                              ),
                              Expanded(
                                flex: (expenses <= 0 ? 1 : expenses).round(),
                                child: Container(
                                    color: LifeTrackColors.coral
                                        .withValues(alpha: 0.85)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StatBlock(
                              icon: Icons.arrow_downward_rounded,
                              label: 'Income',
                              value: _peso(income),
                              color: LifeTrackColors.mint,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.15),
                          ),
                          Expanded(
                            child: _StatBlock(
                              icon: Icons.arrow_upward_rounded,
                              label: 'Expenses',
                              value: _peso(expenses),
                              color: LifeTrackColors.coral,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Weekly trend — own FutureBuilder, navigated week by week
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _dailyFuture,
                  builder: (context, dailySnapshot) {
                    final daily =
                        dailySnapshot.data ?? const <Map<String, dynamic>>[];
                    return _WeeklyTrendCard(
                      daily: daily,
                      peso: _peso,
                      onRetry: _retry,
                      weekStart: _weekStart,
                      isCurrentWeek: _isCurrentWeek,
                      onPreviousWeek: _goToPreviousWeek,
                      onNextWeek: _goToNextWeek,
                      isLoading: dailySnapshot.connectionState ==
                          ConnectionState.waiting,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Monthly trend (last 6 months)
                _MonthlyTrendCard(
                    monthly: monthly, peso: _peso, onRetry: _retry),
                const SizedBox(height: 16),

                // Spending breakdown
                LifeTrackCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('SPENDING',
                              style: Theme.of(context).textTheme.labelSmall),
                          if (spending.isNotEmpty)
                            Text(_peso(spentTotal),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (spending.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_rounded,
                                    size: 32,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.5)),
                                const SizedBox(height: 8),
                                Text(
                                  'No expenses recorded this month.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...List.generate(sortedSpending.length, (i) {
                          final entry = sortedSpending[i];
                          final color = palette[i % palette.length];
                          final ratio =
                              spentTotal == 0 ? 0.0 : entry.value / spentTotal;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _openSpendingDetail(
                                context,
                                entry.key,
                                entry.value,
                                spentTotal,
                                i + 1,
                                sortedSpending.length,
                                color,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(entry.key,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                      ),
                                      Text(_peso(entry.value),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 4),
                                      Icon(Icons.chevron_right_rounded,
                                          size: 18,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.6)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 5,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.1),
                                      valueColor: AlwaysStoppedAnimation(color),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      );
}

/// Bar chart for a single Mon–Sun week, income (mint) vs expenses (coral)
/// side by side. Navigate between weeks with the prev/next arrows in the
/// header — mirrors how the spending card lets you browse other months.
class _WeeklyTrendCard extends StatelessWidget {
  const _WeeklyTrendCard({
    required this.daily,
    required this.peso,
    required this.onRetry,
    required this.weekStart,
    required this.isCurrentWeek,
    required this.onPreviousWeek,
    required this.onNextWeek,
    this.isLoading = false,
  });
  final List<Map<String, dynamic>> daily;
  final String Function(double) peso;
  final VoidCallback onRetry;
  final DateTime weekStart;
  final bool isCurrentWeek;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final bool isLoading;

  static const double _chartHeight = 90;

  String _weekLabel() {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final startStr = DateFormat('MMM d').format(weekStart);
    final endStr = DateFormat('MMM d').format(weekEnd);
    return isCurrentWeek
        ? 'THIS WEEK · $startStr–$endStr'
        : '$startStr – $endStr';
  }

  @override
  Widget build(BuildContext context) {
    final maxValue = daily.fold<double>(1, (max, d) {
      final income = (d['income'] as num?)?.toDouble() ?? 0;
      final expenses = (d['expenses'] as num?)?.toDouble() ?? 0;
      final localMax = income > expenses ? income : expenses;
      return localMax > max ? localMax : max;
    });

    return LifeTrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onPreviousWeek,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.08),
                  ),
                  child: const Icon(Icons.chevron_left_rounded, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _weekLabel(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isCurrentWeek ? null : onNextWeek,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: isCurrentWeek ? 0.04 : 0.08),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isCurrentWeek
                        ? Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.3)
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: LifeTrackColors.mint, label: 'Income'),
              SizedBox(width: 12),
              _LegendDot(color: LifeTrackColors.coral, label: 'Spent'),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const SizedBox(
              height: _chartHeight,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (daily.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Text('No data for this week.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(
                        foregroundColor: LifeTrackColors.highlight,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: _chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in daily)
                    Expanded(
                      child: _DayColumn(
                        date: d['date'] as DateTime,
                        income: (d['income'] as num?)?.toDouble() ?? 0,
                        expenses: (d['expenses'] as num?)?.toDouble() ?? 0,
                        maxValue: maxValue,
                        maxHeight: _chartHeight - 20,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.income,
    required this.expenses,
    required this.maxValue,
    required this.maxHeight,
  });
  final DateTime date;
  final double income;
  final double expenses;
  final double maxValue;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final incomeHeight = maxValue == 0 ? 0.0 : (income / maxValue) * maxHeight;
    final expenseHeight =
        maxValue == 0 ? 0.0 : (expenses / maxValue) * maxHeight;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 5,
              height: incomeHeight.clamp(2, maxHeight),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: LifeTrackColors.mint.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Container(
              width: 5,
              height: expenseHeight.clamp(2, maxHeight),
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: LifeTrackColors.coral.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('E').format(date).substring(0, 1),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isToday
                  ? LifeTrackColors.highlight
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal),
        ),
      ],
    );
  }
}

/// Bar chart of net savings across the last 6 months.
class _MonthlyTrendCard extends StatelessWidget {
  const _MonthlyTrendCard(
      {required this.monthly, required this.peso, required this.onRetry});
  final List<Map<String, dynamic>> monthly;
  final String Function(double) peso;
  final VoidCallback onRetry;

  static const double _chartHeight = 110;

  @override
  Widget build(BuildContext context) {
    final values = monthly
        .map((m) => ((m['saved'] as num?)?.toDouble() ?? 0).abs())
        .toList();
    final maxValue = values.isEmpty
        ? 1.0
        : values
            .reduce((a, b) => a > b ? a : b)
            .clamp(1, double.infinity)
            .toDouble();

    return LifeTrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MONTHLY TREND', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 16),
          if (monthly.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Text('Not enough data yet.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(
                        foregroundColor: LifeTrackColors.highlight,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: _chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final m in monthly)
                    Expanded(
                      child: _MonthColumn(
                        month: m['month'] as DateTime,
                        saved: (m['saved'] as num?)?.toDouble() ?? 0,
                        maxValue: maxValue,
                        maxHeight: _chartHeight - 40,
                        peso: peso,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthColumn extends StatelessWidget {
  const _MonthColumn({
    required this.month,
    required this.saved,
    required this.maxValue,
    required this.maxHeight,
    required this.peso,
  });
  final DateTime month;
  final double saved;
  final double maxValue;
  final double maxHeight;
  final String Function(double) peso;

  @override
  Widget build(BuildContext context) {
    final isCurrent = month.year == DateTime.now().year &&
        month.month == DateTime.now().month;
    final barHeight = (saved.abs() / maxValue) * maxHeight;
    final color = saved >= 0 ? LifeTrackColors.mint : LifeTrackColors.coral;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          saved.abs() >= 1000
              ? '${(saved.abs() / 1000).toStringAsFixed(1)}k'
              : saved.abs().toStringAsFixed(0),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
        ),
        const SizedBox(height: 4),
        Container(
          width: 16,
          height: barHeight.clamp(2, maxHeight),
          decoration: BoxDecoration(
            color: isCurrent ? color : color.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('MMM').format(month),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isCurrent
                  ? LifeTrackColors.highlight
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}
