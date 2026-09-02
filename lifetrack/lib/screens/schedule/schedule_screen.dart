// ============================================================================
// Schedule Screen
// ============================================================================
//
// FIXES IN THIS VERSION (LateInitializationError on _monthFade):
//   1. `_monthFade` is declared nullable (`AnimationController?`) so a
//      dispose-before-init can't crash with LateInitializationError.
//   2. Every use of `_monthFade` goes through `?.` (safe call).
//   3. The two AnimatedBuilders fall back to kAlwaysCompleteAnimation and
//      opacity 1.0 when _monthFade is null.
//   4. `_reloadDay({fromInit})` avoids setState() inside initState, which
//      was the deeper cause: setState in initState can trigger a framework
//      error, which tears the state down mid-initState, which then leaves
//      `late final _monthFade` uninitialized and crashes on dispose.
//
// All of the design/color/animation notes from the previous version still
// apply (season chrome, calendar stays amber, entrance stagger, etc.).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utilities/date_formatter.dart';
import '../../models/schedule.dart';
import '../../services/schedule_service.dart';
import '../../theme/app_theme.dart';
import 'add_activity_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with TickerProviderStateMixin {
  // Layout
  static const double _headerBottomGap = 16;
  static const double _calendarBottomGap = 20;
  static const double _itemGap = 10;
  static const double _bottomInset = 100;
  static const double _headerHeight = 48;
  static const double _iconChipSize = 36;
  static const double _dayCellGap = 4;

  final _service = ScheduleService();

  DateTime _visibleMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();

  List<Schedule>? _dayItems;
  bool _dayError = false;

  final Map<String, bool> _monthIndicators = {};
  bool _loadingIndicators = false;

  final Map<int, AnimationController> _rowAnims = {};

  // Nullable so a dispose-before-init can't throw LateInitializationError.
  AnimationController? _monthFade;

  @override
  void initState() {
    super.initState();
    _monthFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    // Pass fromInit so _reloadDay skips setState() (the widget hasn't
    // built yet, so setState here is what was tearing the state down).
    _reloadDay(fromInit: true);
    _loadMonthIndicators();
  }

  @override
  void dispose() {
    for (final c in _rowAnims.values) {
      c.dispose();
    }
    _rowAnims.clear();
    _monthFade?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Future<void> _reloadDay({bool fromInit = false}) async {
    for (final c in _rowAnims.values) {
      c.dispose();
    }
    _rowAnims.clear();

    if (fromInit) {
      // No setState — initState is about to build anyway.
      _dayItems = null;
      _dayError = false;
    } else {
      setState(() {
        _dayItems = null;
        _dayError = false;
      });
    }

    try {
      final items = await _service.getScheduleForDate(
        DateFormatter.toDbDate(_selectedDate),
      );
      if (!mounted) return;
      setState(() {
        _dayItems = items;
        _dayError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dayItems = const [];
        _dayError = true;
      });
    }
  }

  Future<void> _loadMonthIndicators() async {
    if (mounted) setState(() => _loadingIndicators = true);

    final results = <String, bool>{};
    try {
      final items = await _service.getScheduleForMonth(
        _visibleMonth.year,
        _visibleMonth.month,
      );
      for (final item in items) {
        results[item.date] = true;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _monthIndicators
        ..clear()
        ..addAll(results);
      _loadingIndicators = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Calendar navigation
  // ---------------------------------------------------------------------------

  Future<void> _moveMonth(int months) async {
    await _monthFade?.reverse();
    if (!mounted) return;
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + months,
      );
    });
    _monthFade?.forward();
    _loadMonthIndicators();
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _reloadDay();
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month);
      _selectedDate = now;
    });
    _monthFade?.forward(from: 0);
    _reloadDay();
    _loadMonthIndicators();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isToday => _isSameDay(_selectedDate, DateTime.now());

  // ---------------------------------------------------------------------------
  // Completion
  // ---------------------------------------------------------------------------

  Future<void> _toggleDone(Schedule activity, bool isDone) async {
    setState(() {
      final items = _dayItems;
      if (items == null) return;
      _dayItems = [
        for (final item in items)
          if (item.id == activity.id)
            item.copyWith(isDone: isDone)
          else
            item,
      ];
    });

    try {
      await _service.updateScheduleItem(
        activity.copyWith(isDone: isDone),
      );
    } catch (_) {
      if (!mounted) return;
      await _reloadDay();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update this task. Please try again.'),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Add / scan / upload
  // ---------------------------------------------------------------------------

  Future<void> _openAddOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _AddOptionsSheet(
        onAddManually: () {
          Navigator.of(sheetContext).pop();
          _addManually();
        },
        onScan: () {
          Navigator.of(sheetContext).pop();
          _startScanFlow(source: _ScanSource.camera);
        },
        onUpload: () {
          Navigator.of(sheetContext).pop();
          _startScanFlow(source: _ScanSource.file);
        },
      ),
    );
  }

  Future<void> _addManually() async {
    final saved = await AddActivitySheet.show(context);
    if (saved == true && mounted) {
      await _reloadDay();
      _loadMonthIndicators();
    }
  }

  Future<void> _startScanFlow({required _ScanSource source}) async {
    final input = await _pickScheduleInput(source);
    if (input == null || !mounted) return;

    final imported = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleScanReviewSheet(
        source: source,
        input: input,
        scheduleService: _service,
        defaultDate: _selectedDate,
      ),
    );

    if (imported == true && mounted) {
      await _reloadDay();
      _loadMonthIndicators();
    }
  }

  Future<XFile?> _pickScheduleInput(_ScanSource source) async {
    if (source == _ScanSource.camera) {
      return ImagePicker().pickImage(source: ImageSource.camera);
    }

    const group = XTypeGroup(
      label: 'Schedule files',
      extensions: ['pdf', 'csv', 'txt', 'json', 'jpg', 'jpeg', 'png'],
    );

    final file = await openFile(acceptedTypeGroups: [group]);
    return file == null ? null : XFile(file.path);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = context.season;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'schedule_add_fab',
        backgroundColor: s.accent,
        elevation: 2,
        onPressed: _openAddOptions,
        icon: Icon(Icons.add, color: s.onAccent),
        label: Text(
          'Add',
          style: TextStyle(
            color: s.onAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
          children: [
            _header(context),
            const SizedBox(height: _headerBottomGap),
            _calendar(context),
            const SizedBox(height: _calendarBottomGap),
            _dayDetail(context),
            const SizedBox(height: _bottomInset),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: _headerHeight,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Schedule', style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text('Plan your days.', style: theme.textTheme.bodySmall),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<_ScheduleMenuAction>(
              tooltip: 'More options',
              icon: _iconChip(context, icon: Icons.more_vert_rounded),
              onSelected: (action) {
                switch (action) {
                  case _ScheduleMenuAction.today:
                    _jumpToToday();
                  case _ScheduleMenuAction.refresh:
                    _reloadDay();
                    _loadMonthIndicators();
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

  Widget _iconChip(
    BuildContext context, {
    required IconData icon,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final s = context.season;
    final chip = Container(
      width: _iconChipSize,
      height: _iconChipSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: s.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: s.accentText),
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

  // ---------------------------------------------------------------------------
  // Calendar
  // ---------------------------------------------------------------------------

  Widget _calendar(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;
    final monthLabel = DateFormatter.toDisplayDate(_visibleMonth);

    return _InlineCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _iconChip(
                context,
                icon: Icons.chevron_left_rounded,
                onTap: () => _moveMonth(-1),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    // Fallback if _monthFade is null (early dispose).
                    animation: _monthFade ?? kAlwaysCompleteAnimation,
                    builder: (context, child) => Opacity(
                      opacity: _monthFade?.value ?? 1.0,
                      child: child,
                    ),
                    child: Text(
                      monthLabel,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (_loadingIndicators) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: s.accentText,
                      ),
                    ),
                  ],
                ],
              ),
              _iconChip(
                context,
                icon: Icons.chevron_right_rounded,
                onTap: () => _moveMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _weekdayLabels(context),
          const SizedBox(height: _dayCellGap),
          AnimatedBuilder(
            animation: _monthFade ?? kAlwaysCompleteAnimation,
            builder: (context, child) => Opacity(
              opacity: _monthFade?.value ?? 1.0,
              child: child,
            ),
            child: _monthGrid(context),
          ),
        ],
      ),
    );
  }

  Widget _weekdayLabels(BuildContext context) {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        );
    return Row(
      children: [
        for (final label in labels)
          Expanded(child: Center(child: Text(label, style: style))),
      ],
    );
  }

  Widget _monthGrid(BuildContext context) {
    final firstOfMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    );
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Padding(
            padding: EdgeInsets.only(
              bottom: row == rows - 1 ? 0 : _dayCellGap,
            ),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _dayCell(
                      context,
                      row * 7 + col,
                      leadingBlanks,
                      daysInMonth,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dayCell(
    BuildContext context,
    int cellIndex,
    int leadingBlanks,
    int daysInMonth,
  ) {
    final dayNum = cellIndex - leadingBlanks + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const AspectRatio(
        aspectRatio: 1,
        child: SizedBox.shrink(),
      );
    }

    final date = DateTime(_visibleMonth.year, _visibleMonth.month, dayNum);
    final isSelected = _isSameDay(date, _selectedDate);
    final isToday = _isSameDay(date, DateTime.now());
    final hasItems =
        _monthIndicators[DateFormatter.toDbDate(date)] ?? false;
    final s = context.season;

    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTap: () => _selectDate(date),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected
                ? LifeTrackColors.highlight.withValues(alpha: 0.18)
                : isToday
                    ? s.accent.withValues(alpha: 0.06)
                    : null,
            borderRadius: BorderRadius.circular(12),
            border: isToday && !isSelected
                ? Border.all(color: s.accent.withValues(alpha: 0.4))
                : null,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$dayNum',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected || isToday ? FontWeight.bold : null,
                      color:
                          isSelected ? LifeTrackColors.highlight : null,
                    ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 6,
                width: 6,
                child: hasItems
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                          color: LifeTrackColors.highlight,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Day detail
  // ---------------------------------------------------------------------------

  Widget _dayDetail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dayDetailHeader(context),
        const SizedBox(height: 12),
        _dayDetailBody(context),
      ],
    );
  }

  Widget _dayDetailBody(BuildContext context) {
    if (_dayItems == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_dayError) return _errorState(context);

    final items = _dayItems!;
    if (items.isEmpty) return _emptyState(context);

    _rowAnims.removeWhere((index, c) {
      if (index >= items.length) {
        c.dispose();
        return true;
      }
      return false;
    });
    for (var i = 0; i < items.length; i++) {
      _rowAnims.putIfAbsent(
        i,
        () => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 350),
          lowerBound: 0.0,
          upperBound: 1.0,
          value: 0.0,
        )..forward(),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == items.length - 1 ? 0 : _itemGap,
            ),
            child: AnimatedBuilder(
              animation: _rowAnims[i]!,
              builder: (context, child) {
                final t = _rowAnims[i]!.value;
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 16),
                    child: child,
                  ),
                );
              },
              child: _activityRow(context, items[i]),
            ),
          ),
      ],
    );
  }

  Widget _dayDetailHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          DateFormatter.toDisplayDate(_selectedDate),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (_isToday) _todayBadge(context),
      ],
    );
  }

  Widget _activityRow(BuildContext context, Schedule activity) {
    final isDone = activity.isDone;
    final theme = Theme.of(context);
    final s = context.season;
    const cardMinHeight = 82.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: cardMinHeight),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showActivityDetails(activity),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _toggleDone(activity, !isDone),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, right: 12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      key: ValueKey(isDone),
                      size: 28,
                      color: isDone
                          ? LifeTrackColors.highlight
                          : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isDone ? 0.55 : 1,
                  child: _InlineCard(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: s.accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _iconForCategory(activity.category),
                            size: 20,
                            color: s.accentText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 12,
                                    color: theme
                                        .textTheme.bodyMedium?.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${activity.startTime} – ${activity.endTime}',
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      activity.category,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: s.accentText),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.45),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'coding':
        return Icons.code_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'personal':
        return Icons.person_rounded;
      case 'free':
        return Icons.bolt_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }

  // ---------------------------------------------------------------------------
  // Task details sheet
  // ---------------------------------------------------------------------------

  Future<void> _showActivityDetails(Schedule activity) async {
    final isDone = activity.isDone;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _TaskDetailsSheet(
        activity: activity,
        selectedDate: DateFormatter.toDisplayDate(_selectedDate),
        isDone: isDone,
        onToggleDone: () async {
          Navigator.of(sheetContext).pop();
          await _toggleDone(activity, !isDone);
        },
      ),
    );
  }

  Widget _todayBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: LifeTrackColors.highlight.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Today',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: LifeTrackColors.highlightDeep,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _errorState(BuildContext context) {
    final theme = Theme.of(context);
    return _InlineCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 36, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(height: 8),
            Text('Unable to load this day',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _reloadDay,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final s = context.season;
    final theme = Theme.of(context);
    return _InlineCard(
      child: Row(
        children: [
          Container(
            width: _iconChipSize,
            height: _iconChipSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.event_available_rounded,
                size: 20, color: s.accentText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nothing scheduled for this day.',
                    style: theme.textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text('Tap "Add" to create or scan a schedule.',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Local card surface
// ============================================================================

class _InlineCard extends StatelessWidget {
  const _InlineCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(LifeTrackMetrics.cardRadius),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ============================================================================
// Task details sheet
// ============================================================================

class _TaskDetailsSheet extends StatelessWidget {
  final Schedule activity;
  final String selectedDate;
  final bool isDone;
  final VoidCallback onToggleDone;

  const _TaskDetailsSheet({
    required this.activity,
    required this.selectedDate,
    required this.isDone,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : Icons.event_note_rounded,
                    color: isDone
                        ? LifeTrackColors.highlight
                        : s.accentText,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDone ? 'Completed' : 'Scheduled task',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDone
                              ? LifeTrackColors.highlightDeep
                              : s.accentText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _TaskDetailItem(
                icon: Icons.calendar_today_rounded,
                label: 'Date',
                value: selectedDate),
            const SizedBox(height: 10),
            _TaskDetailItem(
                icon: Icons.schedule_rounded,
                label: 'Time',
                value: '${activity.startTime} – ${activity.endTime}'),
            const SizedBox(height: 10),
            _TaskDetailItem(
                icon: Icons.category_rounded,
                label: 'Category',
                value: activity.category),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onToggleDone,
              icon: Icon(
                isDone
                    ? Icons.undo_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18,
              ),
              label: Text(
                isDone
                    ? 'Mark as not completed'
                    : 'Mark as completed',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskDetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TaskDetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: s.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: s.accentText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Add options sheet
// ============================================================================

class _AddOptionsSheet extends StatelessWidget {
  final VoidCallback onAddManually;
  final VoidCallback onScan;
  final VoidCallback onUpload;

  const _AddOptionsSheet({
    required this.onAddManually,
    required this.onScan,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = context.season;

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
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.event_note_rounded,
                      size: 24, color: s.accentText),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add to schedule',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text('Pick how you want to add.',
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _AddOptionTile(
              icon: Icons.edit_calendar_rounded,
              title: 'Add manually',
              subtitle: 'Fill in the details yourself',
              onTap: onAddManually,
            ),
            const SizedBox(height: 8),
            _AddOptionTile(
              icon: Icons.document_scanner_rounded,
              title: 'Scan handwritten schedule',
              subtitle: 'Take a photo — LifeTrack reads it for you',
              onTap: onScan,
            ),
            const SizedBox(height: 8),
            _AddOptionTile(
              icon: Icons.upload_file_rounded,
              title: 'Upload schedule file',
              subtitle: 'Import from a photo or PDF',
              onTap: onUpload,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AddOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    return Material(
      color: s.accent.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: s.accentText),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).textTheme.bodyMedium?.color
                      ?.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Enums
// ============================================================================

enum _ScheduleMenuAction { today, refresh }

enum _ScanSource { camera, file }

// ============================================================================
// Scanned activity + mock scan service
// ============================================================================

class _ScannedActivity {
  String title;
  String category;
  String startTime;
  String endTime;
  bool selected;

  _ScannedActivity({
    required this.title,
    required this.category,
    required this.startTime,
    required this.endTime,
  }) : selected = true;
}

/// TODO(backend): replace with a real OCR / parsing service.
class _ScheduleScanService {
  Future<List<_ScannedActivity>> scan(
    _ScanSource source,
    XFile input,
  ) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return [
      _ScannedActivity(
        title: 'Java Practice',
        category: 'Coding',
        startTime: '14:00',
        endTime: '15:00',
      ),
      _ScannedActivity(
        title: 'Freelance Project',
        category: 'Freelance',
        startTime: '17:00',
        endTime: '18:00',
      ),
      _ScannedActivity(
        title: 'Lunch',
        category: 'Personal',
        startTime: '12:00',
        endTime: '13:00',
      ),
    ];
  }
}

// ============================================================================
// Scan review sheet
// ============================================================================

class _ScheduleScanReviewSheet extends StatefulWidget {
  final _ScanSource source;
  final XFile input;
  final ScheduleService scheduleService;
  final DateTime defaultDate;

  const _ScheduleScanReviewSheet({
    required this.source,
    required this.input,
    required this.scheduleService,
    required this.defaultDate,
  });

  @override
  State<_ScheduleScanReviewSheet> createState() =>
      _ScheduleScanReviewSheetState();
}

class _ScheduleScanReviewSheetState
    extends State<_ScheduleScanReviewSheet> {
  final _scanService = _ScheduleScanService();
  bool _loading = true;
  bool _importing = false;
  List<_ScannedActivity> _results = [];

  @override
  void initState() {
    super.initState();
    _runScan();
  }

  Future<void> _runScan() async {
    final results = await _scanService.scan(widget.source, widget.input);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _importSelected() async {
    final selected = _results.where((r) => r.selected).toList();
    if (selected.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _importing = true);
    try {
      for (final item in selected) {
        final schedule = Schedule(
          title: item.title,
          category: item.category,
          startTime: item.startTime,
          endTime: item.endTime,
          date: DateFormatter.toDbDate(widget.defaultDate),
        );
        await widget.scheduleService.addScheduleItem(schedule);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not import — please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.season;
    final sourceLabel =
        widget.source == _ScanSource.camera ? 'photo' : 'file';

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _loading
              ? _loadingState(sourceLabel)
              : _resultsState(context),
        ),
      ),
    );
  }

  Widget _loadingState(String sourceLabel) {
    final s = context.season;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: s.accent),
        const SizedBox(height: 16),
        Text('Scanning your $sourceLabel...',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Looking for activities, times, and categories',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _resultsState(BuildContext context) {
    final s = context.season;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Review detected activities',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        Text(
          'Uncheck anything that looks wrong, then import the rest.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (_results.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                "Couldn't find anything to import.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _scannedItemTile(_results[index]),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: s.accent),
          onPressed: _importing ? null : _importSelected,
          child: _importing
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: s.onAccent,
                  ),
                )
              : Text(
                  'Import ${_results.where((r) => r.selected).length} activities',
                ),
        ),
      ],
    );
  }

  Widget _scannedItemTile(_ScannedActivity item) {
    final s = context.season;
    return _InlineCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: item.selected,
            activeColor: s.accent,
            onChanged: (value) {
              setState(() {
                item.selected = value ?? false;
              });
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: item.title,
                  onChanged: (value) {
                    item.title = value;
                  },
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.category} · ${item.startTime} – ${item.endTime}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
