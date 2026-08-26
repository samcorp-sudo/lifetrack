import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifetrack_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _service = AnalyticsService();
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final now = DateTime.now();
    final month = await _service.getMoneyReportForMonth(now.year, now.month);
    final spending = await _service.getSpendingBreakdown(now.year, now.month);
    return {'month': month, 'spending': spending};
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
              return const Center(
                  child: Text('Unable to load analytics records.'));
            }
            final month = snapshot.data!['month'] as Map<String, double>;
            final spending = snapshot.data!['spending'] as Map<String, double>;
            return ListView(
                padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
                children: [
                  Row(children: [
                    GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Icon(Icons.arrow_back_rounded)),
                    const SizedBox(width: 12),
                    Text('Analytics',
                        style: Theme.of(context).textTheme.titleLarge)
                  ]),
                  const SizedBox(height: 18),
                  Text(
                      DateFormat('MMMM yyyy')
                          .format(DateTime.now())
                          .toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 12),
                  LifeTrackCard(
                      child: Column(children: [
                    _StatRow(
                        label: 'Income',
                        value: _peso(month['income'] ?? 0),
                        color: LifeTrackColors.mint),
                    _StatRow(
                        label: 'Expenses',
                        value: _peso(month['expenses'] ?? 0),
                        color: LifeTrackColors.coral),
                    _StatRow(
                        label: 'Savings',
                        value: _peso(month['saved'] ?? 0),
                        color: LifeTrackColors.highlight)
                  ])),
                  const SizedBox(height: 16),
                  LifeTrackCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('SPENDING',
                            style: Theme.of(context).textTheme.labelSmall),
                        const SizedBox(height: 10),
                        if (spending.isEmpty)
                          const Text('No expenses recorded this month.')
                        else
                          ...spending.entries.map((entry) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(children: [
                                Expanded(child: Text(entry.key)),
                                Text(_peso(entry.value))
                              ])))
                      ]))
                ]);
          }));
  String _peso(double value) => '₱${value.toStringAsFixed(0)}';
}

class _StatRow extends StatelessWidget {
  const _StatRow(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(label)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600))
      ]));
}
