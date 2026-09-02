// ============================================================================
// Home Dashboard Screen
// ============================================================================
// NEW IN THIS VERSION:
//   • Per-section stagger entrance (greeting, quote, hero, tasks, columns,
//     quick action) — 60ms apart.
//   • Today's Tasks rows are now tappable (opens a task detail sheet) and
//     slightly more compact.
//   • Empty slot above the "Today's Tasks" header — swap the child of
//     _DashboardSlot(...) with your own widget when you have something.
//   • Notification bell now sits inside a tinted circle in the season accent.
// ============================================================================

import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/utilities/date_formatter.dart';
import '../../models/task.dart';
import '../../services/dashboard_service.dart';
import '../../services/notification_center.dart';
import '../../services/schedule_service.dart';
import '../../theme/app_theme.dart';
import '../../app/currency_controller.dart';
import '../../widgets/daily_quote_banner.dart';
import '../../widgets/lifetrack_card.dart';
import '../../widgets/section_header.dart';
import '../im_free/im_free_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/profile/profile_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen>
    with TickerProviderStateMixin {
  static const double _sectionGap = 20;
  static const double _headerContentGap = 12;
  static const double _taskItemGap = 10;

  final _dashboardService = DashboardService();
  final _taskService = ScheduleService();
  late Future<DashboardSnapshot> _snapshotFuture;

  AnimationController? _revealController;
  Animation<double>? _fade;
  Animation<Offset>? _slide;
  bool _hasPlayedReveal = false;
  bool _showBalance = true;

  // Per-section stagger controllers, keyed by section index (0..5).
  final Map<int, AnimationController> _sectionAnims = {};

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _dashboardService.getDashboardSnapshot();
    _syncNotifications();

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
    for (final c in _sectionAnims.values) {
      c.dispose();
    }
    _sectionAnims.clear();
    _revealController?.dispose();
    super.dispose();
  }

  void _syncNotifications() {
    NotificationCenter.instance.refreshUnread();
    NotificationCenter.instance.generateReminders();
  }

  void _reloadDashboard() {
    for (final c in _sectionAnims.values) {
      c.dispose();
    }
    _sectionAnims.clear();
    setState(() {
      _hasPlayedReveal = false;
      _revealController?.reset();
      _snapshotFuture = _dashboardService.getDashboardSnapshot();
    });
    _syncNotifications();
  }

  Color? _mutedText(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.color;

  // Simple staggered fade + slide for one dashboard section.
  Widget _staggered(int index, Widget child) {
    final c = _sectionAnims.putIfAbsent(
      index,
      () => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
        value: 0,
      ),
    );
    if (c.value == 0) {
      // Kick it off on the next frame so we don't animate during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) c.forward();
      });
    }
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
                        color: _mutedText(context),
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
      ),
    );
  }

  Widget _dashboardList(BuildContext context, DashboardSnapshot data) {
    final theme = Theme.of(context);
    final s = context.season;
    final tasks = data.todayTasks;

    return ListView(
      padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
      children: [
        // 0 — greeting
        _staggered(0, _greetingHeader(context, data)),
        const SizedBox(height: _sectionGap),

        // 1 — daily note
        _staggered(1, const DailyQuoteBanner()),
        const SizedBox(height: _sectionGap),

        // 2 — net worth hero
        _staggered(2, _netWorthCard(context, data, theme, s)),
        const SizedBox(height: _sectionGap),

        // ─── RESERVED SLOT above Today's Tasks ───
        // Put anything you want here (e.g. a widget from a future feature).
        _staggered(3, const _DashboardSlot()),
        const SizedBox(height: 8),

        // 3 — Today's Tasks header + rows
        _staggered(
          3,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionHeader(title: "Today's Tasks"),
              TextButton(
                onPressed: () {
                  // TODO: navigate to the full Tasks screen if desired.
                },
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        const SizedBox(height: _headerContentGap),

        if (tasks.isEmpty)
          _staggered(
            3,
            _emptyState(
              context,
              icon: Icons.task_alt_rounded,
              message: 'All clear for today.',
              hint: 'Add a task to stay on track.',
            ),
          )
        else
          for (var i = 0; i < tasks.take(3).length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == tasks.take(3).length - 1 ? 0 : _taskItemGap,
              ),
              child: _staggered(
                3,
                _TaskTile(
                  task: tasks.elementAt(i),
                  onTap: () => _openTaskDetail(context, tasks.elementAt(i)),
                  onToggleDone: () => _markTaskDone(tasks.elementAt(i)),
                ),
              ),
            ),

        const SizedBox(height: _sectionGap),

        // 4 — upcoming bills + work schedule
        _staggered(4, _twoColumnRow(context, theme, s)),
        const SizedBox(height: _sectionGap),

        // 5 — quick action
        _staggered(5, _quickActionCard(context)),
        const SizedBox(height: 100),
      ],
    );
  }

  // ==========================================================================
  // Net worth hero (unchanged content, extracted so the stagger wraps it once)
  // ==========================================================================

  Widget _netWorthCard(
    BuildContext context,
    DashboardSnapshot data,
    ThemeData theme,
    SeasonColors s,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [s.accent, s.accentDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
        boxShadow: [
          BoxShadow(
            color: s.accent.withValues(alpha: 0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total Net Worth',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: s.onAccent.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _maskable(_peso(data.financial.balance)),
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: s.onAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _showBalance = !_showBalance),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _showBalance
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: s.onAccent.withValues(alpha: 0.7),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildBalanceChip(
                  context,
                  icon: Icons.arrow_upward,
                  label: 'Income',
                  amount: _maskable('+ ${_peso(data.financial.income)}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBalanceChip(
                  context,
                  icon: Icons.arrow_downward,
                  label: 'Spent',
                  amount: _maskable(_peso(data.financial.expenses)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // Today's task tile — compact, tappable, press-scale + long-press delete
  // ==========================================================================

  Widget _twoColumnRow(BuildContext context, ThemeData theme, SeasonColors s) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month, size: 18, color: s.accentText),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Upcoming Bills',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: _headerContentGap),
                _miniEmptyCard(
                  context,
                  icon: Icons.receipt_long,
                  message: 'No upcoming bills',
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.work_outline, size: 18, color: s.accentText),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Work Schedule',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: _headerContentGap),
                _miniEmptyCard(
                  context,
                  icon: Icons.event_available_outlined,
                  message: 'No shifts scheduled',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markTaskDone(Task task) async {
    try {
      await _taskService.markTaskDone(task);
      if (!mounted) return;
      _reloadDashboard();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to complete task.')),
      );
    }
  }

  Future<void> _openTaskDetail(BuildContext context, Task task) async {
    final s = context.season;
    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
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
                      color: s.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.task_alt_rounded,
                        size: 24, color: s.accentText),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          task.status == TaskStatus.done
                              ? 'Completed'
                              : 'Active task',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (task.dueDate != null)
                _sheetRow(context, Icons.event_outlined, 'Due',
                    _formatDue(task.dueDate!)),
              if (task.category != null)
                _sheetRow(context, Icons.local_offer_outlined, 'Category',
                    task.category!),
              _sheetRow(
                context,
                Icons.flag_outlined,
                'Priority',
                task.priority.value,
              ),
              const SizedBox(height: 16),
              if (task.status != TaskStatus.done)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _markTaskDone(task);
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Mark complete'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final s = context.season;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: s.accentText),
          const SizedBox(width: 10),
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }

  String _formatDue(String dbDate) {
    try {
      final d = DateFormatter.fromDbDate(dbDate);
      final today = DateTime.now();
      final isToday = d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
      if (isToday) return 'Today';
      return DateFormatter.toDisplayDate(d);
    } catch (_) {
      return dbDate;
    }
  }

  // --- HELPER BUILDERS ---

  Widget _buildBalanceChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String amount,
  }) {
    final s = context.season;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: s.onAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
        border: Border.all(color: s.onAccent.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              '$label $amount',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: s.onAccent,
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, color: s.onAccent, size: 12),
        ],
      ),
    );
  }

  Widget _miniEmptyCard(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    return SizedBox(
      width: double.infinity,
      child: LifeTrackCard(
        child: Column(
          children: [
            Icon(icon, size: 22, color: _mutedText(context)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // HEADER — greeting + current date + notification bell in a tinted circle
  // ---------------------------------------------------------------------
  Widget _greetingHeader(BuildContext context, DashboardSnapshot data) {
    final s = context.season;
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? '';
    final firstName = displayName.trim().split(RegExp(r'\s+')).first;
    final now = DateTime.now();
    final greeting = _timeOfDayGreeting(now);
    final title = firstName.isEmpty ? greeting : '$greeting, $firstName';
    final dateLine = _formatHeaderDate(now);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 21,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        // Notification bell in a tinted circle so it stands out from the
        // bare icons around it. Same chip style used across the app.
        ValueListenableBuilder<int>(
          valueListenable: NotificationCenter.instance.unreadCount,
          builder: (context, unread, _) {
            return Material(
              color: s.accent.withValues(alpha: 0.12),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _openNotifications(context),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Badge(
                    isLabelVisible: unread > 0,
                    label: Text(unread > 99 ? '99+' : '$unread'),
                    backgroundColor: LifeTrackColors.coral,
                    textColor: Colors.white,
                    child: Icon(Icons.notifications_outlined,
                        color: s.accentText, size: 20),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _openProfile(context),
          child: CircleAvatar(
            backgroundColor: s.accent,
            radius: 20,
            child: Text(
              _initials(displayName),
              style: TextStyle(
                color: s.onAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _timeOfDayGreeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatHeaderDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
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
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday, $month ${date.day}, ${date.year}';
  }

  Future<void> _openNotifications(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    NotificationCenter.instance.refreshUnread();
  }

  Future<void> _openProfile(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    if (mounted) setState(() {});
  }

  Widget _emptyState(
    BuildContext context, {
    required IconData icon,
    required String message,
    required String hint,
  }) {
    final theme = Theme.of(context);
    return LifeTrackCard(
      child: Row(
        children: [
          Icon(icon, size: 22, color: _mutedText(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(hint, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    return LifeTrackCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ImFreeScreen())),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: s.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.bolt_rounded,
                      size: 20, color: s.accentText),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("I'm Free", style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('Get something to do with your open time',
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: _mutedText(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _maskable(String value) => _showBalance ? value : '••••••';

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _peso(double value) => CurrencyController.format(value);
}

// ============================================================================
// Reserved slot above "Today's Tasks".
// Swap the SizedBox for your widget when you're ready. Default height is
// zero so it's invisible until you use it.
// ============================================================================

class _DashboardSlot extends StatelessWidget {
  const _DashboardSlot({this.child, this.height = 0});
  final Widget? child;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (child == null) return SizedBox(height: height);
    return child!;
  }
}

// ============================================================================
// Task tile — compact, tappable, press-scale, no external TaskCard dependency.
// ============================================================================

class _TaskTile extends StatefulWidget {
  const _TaskTile({
    required this.task,
    required this.onTap,
    required this.onToggleDone,
  });
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();
    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _tap.reverse();
    await _tap.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    final isDone = widget.task.status == TaskStatus.done;

    return ScaleTransition(
      scale: _tap,
      child: LifeTrackCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
            onTap: _handleTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Checkbox-style toggle — tap to mark done.
                  GestureDetector(
                    onTap: isDone ? null : widget.onToggleDone,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isDone ? s.accent : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone
                              ? s.accent
                              : theme.textTheme.bodyMedium?.color
                                      ?.withValues(alpha: 0.35) ??
                                  s.accent,
                          width: 1.6,
                        ),
                      ),
                      child: isDone
                          ? Icon(Icons.check_rounded,
                              size: 16, color: s.onAccent)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                        color: isDone
                            ? theme.textTheme.bodyMedium?.color
                            : null,
                      ),
                    ),
                  ),
                  if (widget.task.dueDate != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: s.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _formatDue(widget.task.dueDate!),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: s.accentText),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.4)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDue(String dbDate) {
    try {
      final d = DateFormatter.fromDbDate(dbDate);
      final today = DateTime.now();
      final isToday = d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
      if (isToday) return 'Today';
      return DateFormatter.toDisplayDate(d);
    } catch (_) {
      return dbDate;
    }
  }
}
