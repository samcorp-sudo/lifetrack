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
  late DateTime _weekStart;

  static DateTime _mondayOf(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - 1));
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
    if (_isCurrentWeek) return;
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
      _dailyFuture = _loadWeek(_weekStart);
    });
  }

  String _peso(double value) => CurrencyController.format(value);

  void _openSpendingDetail(
    BuildContext context,
    String category,
    double amount,
    double total,
    int rank,
    int totalCategories,
    Color color,
  ) {
    final s = context.season;
    final daysElapsed = DateTime.now().day.clamp(1, 31);
    final perDay = amount / daysElapsed;
    final share = total == 0 ? 0.0 : amount / total;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_iconForCategory(category),
                        color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category,
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          'Rank #$rank of $totalCategories',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _peso(amount),
                style: Theme.of(sheetContext)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'total spent this month',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SHARE OF TOTAL SPENDING',
                      style: Theme.of(sheetContext).textTheme.labelSmall),
                  Text('${(share * 100).toStringAsFixed(0)}%',
                      style: Theme.of(sheetContext)
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
                  backgroundColor: s.accent.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation<Color>(s.accent),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: s.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_view_day_rounded,
                        size: 16, color: s.accentText),
                    const SizedBox(width: 8),
                    Text('~${_peso(perDay)} / day so far this month',
                        style: Theme.of(sheetContext).textTheme.bodySmall),
                  ],
                ),
              ),
              if (rank == 1) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.trending_up_rounded,
                        size: 16, color: s.accentText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your biggest expense category this month',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: s.accentText),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
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
    if (key.contains('shop') || key.contains('grocery')) {
      return Icons.shopping_bag_rounded;
    }
    if (key.contains('health') ||
        key.contains('medic') ||
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
  Widget build(BuildContext context) {
    final s = context.season;
    final theme = Theme.of(context);

    // Own Scaffold so the background follows ThemeData.scaffoldBackgroundColor
    // (paper in light, ink in dark) instead of inheriting whatever is behind
    // this route. Without this, Analytics rendered on the previous screen's
    // background — which is why it looked black while dark mode was off.
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
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
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.cloud_off_rounded,
                        size: 27,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Unable to load analytics',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text('Check your connection and try again.',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final month = snapshot.data!['month'] as Map<String, double>;
            final spending =
                snapshot.data!['spending'] as Map<String, double>;
            final monthly =
                snapshot.data!['monthly'] as List<Map<String, dynamic>>? ??
                    const <Map<String, dynamic>>[];

            final income = month['income'] ?? 0;
            final expenses = month['expenses'] ?? 0;
            final saved = month['saved'] ?? 0;
            final spentTotal =
                spending.values.fold<double>(0, (a, b) => a + b);
            final sortedSpending = spending.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            final palette = <Color>[
              s.accent,
              LifeTrackColors.coral,
              LifeTrackColors.mint,
            ];

            return ListView(
              padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
              physics: const BouncingScrollPhysics(),
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: s.accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.arrow_back_rounded,
                            size: 20, color: s.accentText),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Analytics',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('See where your money went.',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: s.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 12, color: s.accentText),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM yyyy')
                                .format(DateTime.now())
                                .toUpperCase(),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: s.accentText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Hero savings card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [s.accent, s.accentDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: s.accent.withValues(alpha: 0.28),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net saved this month',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: s.onAccent.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: s.onAccent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.savings_rounded,
                                color: s.onAccent, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _peso(saved),
                                style: theme.textTheme.displayLarge?.copyWith(
                                  color: s.onAccent,
                                  fontSize: 32,
                                ),
                              ),
                            ),
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
                                        .withValues(alpha: 0.9)),
                              ),
                              Expanded(
                                flex: (expenses <= 0 ? 1 : expenses).round(),
                                child: Container(
                                    color: LifeTrackColors.coral
                                        .withValues(alpha: 0.9)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroStat(
                              icon: Icons.arrow_downward_rounded,
                              label: 'Income',
                              value: _peso(income),
                              color: LifeTrackColors.mint,
                              textColor: s.onAccent,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: s.onAccent.withValues(alpha: 0.18),
                          ),
                          Expanded(
                            child: _HeroStat(
                              icon: Icons.arrow_upward_rounded,
                              label: 'Expenses',
                              value: _peso(expenses),
                              color: LifeTrackColors.coral,
                              textColor: s.onAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Weekly trend
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _dailyFuture,
                  builder: (context, dailySnapshot) {
                    final daily = dailySnapshot.data ??
                        const <Map<String, dynamic>>[];
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

                // Monthly trend
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
                              style: theme.textTheme.labelSmall),
                          if (spending.isNotEmpty)
                            Text(_peso(spentTotal),
                                style: theme.textTheme.labelSmall
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
                                    color: theme.textTheme.bodyMedium?.color),
                                const SizedBox(height: 8),
                                Text(
                                  'No expenses recorded this month.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...List.generate(sortedSpending.length, (i) {
                          final entry = sortedSpending[i];
                          final color = palette[i % palette.length];
                          final ratio = spentTotal == 0
                              ? 0.0
                              : entry.value / spentTotal;
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
                                            style: theme
                                                .textTheme.titleMedium),
                                      ),
                                      Text(_peso(entry.value),
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.w600)),
                                      const SizedBox(width: 4),
                                      Icon(Icons.chevron_right_rounded,
                                          size: 18,
                                          color: theme.textTheme.bodyMedium
                                              ?.color
                                              ?.withValues(alpha: 0.5)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 5,
                                      backgroundColor:
                                          s.accent.withValues(alpha: 0.12),
                                      valueColor:
                                          AlwaysStoppedAnimation(color),
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
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.22),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: textColor.withValues(alpha: 0.75),
                      )),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      )),
            ],
          ),
        ),
      ],
    );
  }
}

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
    final theme = Theme.of(context);
    final s = context.season;

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
                    color: s.accent.withValues(alpha: 0.10),
                  ),
                  child: Icon(Icons.chevron_left_rounded,
                      size: 18, color: s.accentText),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _weekLabel(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: s.accentText),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isCurrentWeek ? null : onNextWeek,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrentWeek
                        ? theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.06)
                        : s.accent.withValues(alpha: 0.10),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isCurrentWeek
                        ? theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.3)
                        : s.accentText,
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
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(
                          foregroundColor: s.accentText),
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
    final theme = Theme.of(context);
    final s = context.season;
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final incomeHeight =
        maxValue == 0 ? 0.0 : (income / maxValue) * maxHeight;
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
          style: theme.textTheme.labelSmall?.copyWith(
            color: isToday ? s.accentText : theme.textTheme.bodyMedium?.color,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _MonthlyTrendCard extends StatelessWidget {
  const _MonthlyTrendCard({
    required this.monthly,
    required this.peso,
    required this.onRetry,
  });
  final List<Map<String, dynamic>> monthly;
  final String Function(double) peso;
  final VoidCallback onRetry;

  static const double _chartHeight = 110;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

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
          Text('MONTHLY TREND', style: theme.textTheme.labelSmall),
          const SizedBox(height: 16),
          if (monthly.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Text('Not enough data yet.',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(
                          foregroundColor: s.accentText),
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
    final theme = Theme.of(context);
    final s = context.season;
    final isCurrent =
        month.year == DateTime.now().year && month.month == DateTime.now().month;
    final barHeight = (saved.abs() / maxValue) * maxHeight;
    final color = isCurrent
        ? s.accent
        : (saved >= 0 ? LifeTrackColors.mint : LifeTrackColors.coral);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          saved.abs() >= 1000
              ? '${(saved.abs() / 1000).toStringAsFixed(1)}k'
              : saved.abs().toStringAsFixed(0),
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 9,
            color: theme.textTheme.bodyMedium?.color,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
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
          style: theme.textTheme.labelSmall?.copyWith(
            color: isCurrent ? s.accentText : theme.textTheme.bodyMedium?.color,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.textTheme.bodyMedium?.color)),
      ],
    );
  }
}
