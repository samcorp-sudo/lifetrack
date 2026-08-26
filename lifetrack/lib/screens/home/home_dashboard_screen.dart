import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/dashboard_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifetrack_card.dart';
import '../../widgets/money_card.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/schedule_card.dart';
import '../../widgets/task_card.dart';
import '../../widgets/section_header.dart';
import '../im_free/im_free_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final _dashboardService = DashboardService();
  late Future<DashboardSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _dashboardService.getDashboardSnapshot();
  }

  void _reloadDashboard() {
    setState(() {
      _snapshotFuture = _dashboardService.getDashboardSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<DashboardSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 44,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Unable to load dashboard',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please check your data and try again.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _reloadDashboard,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(data.greeting,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const Icon(Icons.notifications_none_rounded),
                ],
              ),
              Text(DateFormat('EEEE, MMM d').format(DateTime.now()),
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              MoneyCard(
                  balanceLabel: _peso(data.financial.balance),
                  deltaLabel:
                      '${data.financial.savings >= 0 ? '+' : ''}${_peso(data.financial.savings)} this month'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: StatCard(
                        icon: Icons.insights_rounded,
                        label: 'Net Worth',
                        value: _peso(data.netWorth.netWorth))),
                const SizedBox(width: 12),
                Expanded(
                    child: StatCard(
                        icon: Icons.flag_rounded,
                        label: 'Top Goal',
                        value: data.topGoal == null
                            ? 'None'
                            : '${(data.topGoal!.progress * 100).round()}%',
                        progress: data.topGoal?.progress)),
              ]),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Next Activity'),
              if (data.nextActivity == null)
                const Text('No activity scheduled yet.')
              else
                ScheduleCard(activity: data.nextActivity!),
              const SizedBox(height: 20),
              const SectionHeader(title: "Today's Tasks"),
              if (data.todayTasks.isEmpty)
                const Text('No tasks due today.')
              else
                ...data.todayTasks.take(3).map((task) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TaskCard(task: task))),
              const SizedBox(height: 8),
              LifeTrackCard(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ImFreeScreen())),
                  child: Row(children: [
                    const Icon(Icons.bolt_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text("I'm Free",
                        style: Theme.of(context).textTheme.titleMedium)
                  ])),
            ],
          );
        },
      ),
    );
  }

  String _peso(double value) =>
      '₱${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
}
