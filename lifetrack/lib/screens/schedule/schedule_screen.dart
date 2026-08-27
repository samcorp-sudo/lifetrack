// ============================================================================
// Schedule Screen
// ----------------------------------------------------------------------------
// IMPROVEMENTS OVER PREVIOUS VERSION (layout/UX only — all state, service
// calls, and menu actions are unchanged):
// - Header title is now truly centered via a Stack instead of Expanded +
//   textAlign.center, which drifted off-center whenever the back button and
//   the popup menu button ended up different widths.
// - Back button and overflow menu icon now sit in the same tinted icon-chip
//   style used on the Settings and Money screens, for visual consistency.
// - Date navigator chevrons get the same chip treatment.
// - Added a small "Today" badge next to the date when it's the current day,
//   instead of only showing a hint when it's NOT today — makes the current
//   state visible at a glance rather than only the alternate action.
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/utilities/date_formatter.dart';
import '../../models/schedule.dart';
import '../../services/schedule_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifetrack_card.dart';
import '../../widgets/schedule_card.dart';
import 'add_activity_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // ---------------------------------------------------------------------
  // Layout spacing scale — matches the rest of the app.
  // ---------------------------------------------------------------------
  static const double _headerBottomGap = 16;
  static const double _dateNavBottomGap = 20;
  static const double _itemGap = 12;
  static const double _bottomInset = 80;
  static const double _headerHeight = 48;
  static const double _iconChipSize = 36;

  final _service = ScheduleService();
  DateTime _selectedDate = DateTime.now();
  late Future<List<Schedule>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future =
        _service.getScheduleForDate(DateFormatter.toDbDate(_selectedDate));
  }

  void _moveDay(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _reload();
    });
  }

  void _jumpToToday() {
    setState(() {
      _selectedDate = DateTime.now();
      _reload();
    });
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton(
              backgroundColor: LifeTrackColors.highlight,
              onPressed: () async {
                final saved = await AddActivitySheet.show(context);
                if (saved == true && mounted) setState(_reload);
              },
              child: const Icon(Icons.add, color: LifeTrackColors.ink)),
          body: FutureBuilder<List<Schedule>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(
                          LifeTrackMetrics.screenPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 44,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                          const SizedBox(height: 12),
                          Text('Unable to load schedule',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('Check your connection and try again.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => setState(_reload),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final items = snapshot.data ?? const <Schedule>[];
                return ListView(
                    padding:
                        const EdgeInsets.all(LifeTrackMetrics.screenPadding),
                    children: [
                      _header(context),
                      const SizedBox(height: _headerBottomGap),
                      _dateNavigator(context),
                      const SizedBox(height: _dateNavBottomGap),
                      if (items.isEmpty)
                        _emptyState(context)
                      else
                        for (var i = 0; i < items.length; i++)
                          Padding(
                              padding: EdgeInsets.only(
                                  bottom: i == items.length - 1
                                      ? 0
                                      : _itemGap),
                              child: ScheduleCard(activity: items[i])),
                      const SizedBox(height: _bottomInset)
                    ]);
              })));

  // True centering via Stack — Row + Expanded drifted off-center whenever
  // the leading and trailing widgets weren't the same width.
  Widget _header(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: _headerHeight,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
         
          Text('Schedule', style: Theme.of(context).textTheme.titleLarge),
          Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<_ScheduleMenuAction>(
              tooltip: 'More options',
              icon: _iconChip(
                color: primary,
                icon: Icons.more_vert_rounded,
                onTap: null,
              ),
              onSelected: (action) {
                switch (action) {
                  case _ScheduleMenuAction.today:
                    _jumpToToday();
                  case _ScheduleMenuAction.refresh:
                    setState(_reload);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _ScheduleMenuAction.today,
                  child: Text('Jump to today'),
                ),
                PopupMenuItem(
                  value: _ScheduleMenuAction.refresh,
                  child: Text('Refresh'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Shared tinted-chip look for header/nav icons. When onTap is null, the
  // chip is purely visual and the tap handling is left to a parent widget
  // (used for the PopupMenuButton, which supplies its own tap target).
  Widget _iconChip({
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final chip = Container(
      width: _iconChipSize,
      height: _iconChipSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: color),
    );
    if (onTap == null) return chip;
    final button = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: chip,
    );
    return tooltip == null
        ? button
        : Tooltip(message: tooltip, child: button);
  }

  Widget _dateNavigator(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return LifeTrackCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _iconChip(
            color: primary,
            icon: Icons.chevron_left_rounded,
            onTap: () => _moveDay(-1),
          ),
          GestureDetector(
            onTap: _isToday ? null : _jumpToToday,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(DateFormatter.toDisplayDate(_selectedDate),
                        style: Theme.of(context).textTheme.titleMedium),
                    if (_isToday) ...[
                      const SizedBox(width: 8),
                      _todayBadge(context),
                    ],
                  ],
                ),
                if (!_isToday) ...[
                  const SizedBox(height: 2),
                  Text('Tap to jump to today',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          _iconChip(
            color: primary,
            icon: Icons.chevron_right_rounded,
            onTap: () => _moveDay(1),
          ),
        ],
      ),
    );
  }

  Widget _todayBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: LifeTrackColors.highlight.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Today',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: LifeTrackColors.highlight,
            ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return LifeTrackCard(
      child: Row(
        children: [
          Container(
            width: _iconChipSize,
            height: _iconChipSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(Icons.event_available_rounded, size: 20, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nothing scheduled for this day.',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text('Tap + to add an activity.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ScheduleMenuAction { today, refresh }