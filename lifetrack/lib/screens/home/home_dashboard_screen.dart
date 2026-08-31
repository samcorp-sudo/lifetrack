import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/dashboard_service.dart';
import '../../theme/app_theme.dart';
import '../../app/currency_controller.dart';
import '../../widgets/lifetrack_card.dart';
import '../../widgets/cards/money_card.dart';
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

class _HomeDashboardScreenState extends State<HomeDashboardScreen>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------
  // Layout spacing scale.
  // ---------------------------------------------------------------------
  static const double _dateGap = 4;
  static const double _sectionGap = 18;
  static const double _headerContentGap = 10;
  static const double _statCardGap = 10;
  static const double _taskItemGap = 8;
  static const double _quickActionIconGap = 12;

  final _dashboardService = DashboardService();
  late Future<DashboardSnapshot> _snapshotFuture;

  AnimationController? _revealController;
  Animation<double>? _fade;
  Animation<Offset>? _slide;
  bool _hasPlayedReveal = false;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _dashboardService.getDashboardSnapshot();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _revealController = controller;
    _fade = CurvedAnimation(parent: controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _revealController?.dispose();
    super.dispose();
  }

  void _reloadDashboard() {
    setState(() {
      _hasPlayedReveal = false;
      _revealController?.reset();
      _snapshotFuture = _dashboardService.getDashboardSnapshot();
    });
  }

  IconData get _timeOfDayIcon {
    final hour = DateTime.now().hour;
    if (hour < 5 || hour >= 20) return Icons.nights_stay_rounded;
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 17) return Icons.wb_cloudy_rounded;
    return Icons.wb_twilight_rounded;
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
            developer.log(
              'Dashboard load failed',
              name: 'LifeTrack.dashboard',
              error: snapshot.error,
              stackTrace: snapshot.stackTrace,
            );
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
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load dashboard',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check your connection and try again.',
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

          final controller = _revealController;
          final fade = _fade;
          final slide = _slide;

          if (!_hasPlayedReveal && controller != null) {
            _hasPlayedReveal = true;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => controller.forward());
          }

          // If the animation isn't ready (e.g. mid hot-reload), just show
          // the content plainly rather than crashing the build.
          if (fade == null || slide == null) {
            return RefreshIndicator(
              onRefresh: () async => _reloadDashboard(),
              child: _dashboardList(context, data),
            );
          }

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: RefreshIndicator(
                onRefresh: () async => _reloadDashboard(),
                child: _dashboardList(context, data),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dashboardList(BuildContext context, DashboardSnapshot data) {
    return ListView(
      padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
      children: [
        _greetingHeader(context, data),
        const SizedBox(height: _sectionGap),
        MoneyCard(
            balanceLabel: _peso(data.financial.balance),
            deltaLabel:
                '${data.financial.savings >= 0 ? '+' : ''}${_peso(data.financial.savings)} this month'),
        const SizedBox(height: _statCardGap),
        Row(children: [
          Expanded(
              child: StatCard(
                  icon: Icons.insights_rounded,
                  label: 'Net Worth',
                  value: _peso(data.netWorth.netWorth))),
          const SizedBox(width: _statCardGap),
          Expanded(
              child: StatCard(
                  icon: Icons.flag_rounded,
                  label: 'Top Goal',
                  value: data.topGoal == null
                      ? 'None'
                      : '${(data.topGoal!.progress * 100).round()}%',
                  progress: data.topGoal?.progress)),
        ]),
        const SizedBox(height: _sectionGap),
        const SectionHeader(title: 'Next Activity'),
        const SizedBox(height: _headerContentGap),
        if (data.nextActivity == null)
          _emptyState(
            context,
            icon: Icons.event_available_rounded,
            message: 'Nothing scheduled yet.',
            hint: 'Plan your day from the Schedule tab.',
          )
        else
          ScheduleCard(activity: data.nextActivity!),
        const SizedBox(height: _sectionGap),
        const SectionHeader(title: "Today's Tasks"),
        const SizedBox(height: _headerContentGap),
        if (data.todayTasks.isEmpty)
          _emptyState(
            context,
            icon: Icons.task_alt_rounded,
            message: 'All clear for today.',
            hint: 'Add a task to stay on track.',
          )
        else
          for (var i = 0; i < data.todayTasks.take(3).length; i++)
            Padding(
              padding: EdgeInsets.only(
                  bottom: i == data.todayTasks.take(3).length - 1
                      ? 0
                      : _taskItemGap),
              child: TaskCard(task: data.todayTasks.elementAt(i)),
            ),
        const SizedBox(height: _sectionGap),
        _quickActionCard(context),
      ],
    );
  }

  Widget _greetingHeader(BuildContext context, DashboardSnapshot data) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_timeOfDayIcon, size: 20, color: primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.greeting,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
              ),
              const SizedBox(height: _dateGap),
              Text(DateFormat('EEEE, MMM d').format(DateTime.now()),
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: IconButton(
            onPressed: () => _openNotifications(context),
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
          ),
        ),
      ],
    );
  }

  void _openNotifications(BuildContext context) {
    // TODO: replace with Navigator.of(context).push(...) to your real
    // NotificationsScreen once it exists.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No new notifications.')),
    );
  }

  Widget _emptyState(
    BuildContext context, {
    required IconData icon,
    required String message,
    required String hint,
  }) {
    final primary = Theme.of(context).textTheme.bodyMedium?.color;
    return LifeTrackCard(
      child: Row(
        children: [
          Icon(icon, size: 22, color: primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(hint, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return LifeTrackCard(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ImFreeScreen())),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.bolt_rounded, size: 20, color: primary),
          ),
          const SizedBox(width: _quickActionIconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("I'm Free",
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('Get something to do with your open time',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }

  String _peso(double value) => CurrencyController.format(value);
}
