// ============================================================================
// Schedule Screen
// ----------------------------------------------------------------------------
// DESIGN PASS:
// - FAB is now an extended FAB ("Add") instead of a bare "+" icon —
//   clearer affordance now that it opens a menu with 3 choices.
// - Tapping the FAB opens a bottom sheet with three options: Add manually,
//   Scan handwritten schedule (camera), Upload schedule file. Each uses
//   the same _AddOptionTile for a consistent icon-chip + title/subtitle
//   look, matching the header's icon-chip style.
// - Softer shadows/spacing pass on the calendar and day-detail cards.
//
// NEW: SCAN / UPLOAD FLOW
// - "Scan handwritten schedule" and "Upload schedule file" both lead to
//   the same _ScheduleScanReviewSheet: a loading state ("Scanning your
//   schedule...") followed by a checklist of detected activities the user
//   can review, edit, deselect, and then import in one batch.
// - Right now the "scan" step is MOCKED — it returns fixed sample data
//   after a short delay so the full flow is clickable and demoable. It is
//   NOT reading any real photo or file yet. See the TODO block below for
//   exactly what to wire up.
//
// TODO(packages): add these to pubspec.yaml when ready to wire real capture:
//   - image_picker        -> camera capture for "Scan handwritten schedule"
//   - file_picker          -> file selection for "Upload schedule file"
//   - a text-recognition/OCR package (e.g. google_mlkit_text_recognition)
//     OR a cloud OCR API call, to turn the captured image into raw text
//
// TODO(backend): replace `_ScheduleScanService.mockScan()` below with a
// real implementation that:
//   1. Takes the captured/uploaded image (or PDF) file
//   2. Runs OCR to extract raw text
//   3. Parses that raw text into structured activities (title, category
//      guess, start_time, end_time, date) — this parsing step is the
//      hard part and will likely need its own service/heuristics, or an
//      LLM call if you want smarter parsing than plain regex.
//   4. Returns a List<_ScannedActivity> the review sheet can display
//
// TODO(service): once real Schedule items are created from the reviewed
// scan results, confirm the actual persistence call on ScheduleService
// (e.g. `_service.addScheduleItem(schedule)` per item, or a batch method
// if one exists) — see `_importSelected()` below.
//
// EXISTING TODOs (unchanged from prior version):
// - `Schedule.id` / `isDone` field name assumptions — see `// TODO(model)`
// - `ScheduleService` completion-persistence stub — see `// TODO(service)`
// - Month-indicator batch fetch — see `_loadMonthIndicators()`
// ============================================================================

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
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
  static const double _calendarBottomGap = 20;
  static const double _itemGap = 12;
  static const double _bottomInset = 80;
  static const double _headerHeight = 48;
  static const double _iconChipSize = 36;
  static const double _dayCellGap = 4;

  final _service = ScheduleService();

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();

  late Future<List<Schedule>> _dayFuture;

  // Cache of "does this date have any items" for the visible month, used to
  // render the dot indicators. Keyed by yyyy-MM-dd via DateFormatter.
  final Map<String, bool> _monthIndicators = {};
  bool _loadingIndicators = false;

  @override
  void initState() {
    super.initState();
    _reloadDay();
    _loadMonthIndicators();
  }

  void _reloadDay() {
    _dayFuture =
        _service.getScheduleForDate(DateFormatter.toDbDate(_selectedDate));
  }

  // TODO(backend): Replace this per-day fan-out with a single
  // `getScheduleForMonth(year, month)` call if/when that exists on
  // ScheduleService — this is O(days in month) requests as written.
  Future<void> _loadMonthIndicators() async {
    setState(() => _loadingIndicators = true);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final results = <String, bool>{};
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
      try {
        final items =
            await _service.getScheduleForDate(DateFormatter.toDbDate(date));
        results[DateFormatter.toDbDate(date)] = items.isNotEmpty;
      } catch (_) {
        // Ignore indicator failures — the grid just won't show a dot.
      }
    }
    if (!mounted) return;
    setState(() {
      _monthIndicators
        ..clear()
        ..addAll(results);
      _loadingIndicators = false;
    });
  }

  void _moveMonth(int months) {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + months);
    });
    _loadMonthIndicators();
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _reloadDay();
    });
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month);
      _selectedDate = now;
      _reloadDay();
    });
    _loadMonthIndicators();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isToday => _isSameDay(_selectedDate, DateTime.now());

  // TODO(model): assumes `Schedule.id` exists as a unique identifier.
  // TODO(service): assumes/stubs a persistence call for completion state.
  Future<void> _toggleDone(Schedule activity, bool isDone) async {
    // Optimistic local update so the UI responds instantly.
    setState(() {
      _dayFuture = _dayFuture.then((items) {
        return [
          for (final item in items)
            if (item.id == activity.id) // TODO(model): confirm `id` field
              _copyWithDone(item, isDone)
            else
              item,
        ];
      });
    });

    try {
      // TODO(service): swap this stub for the real persistence call, e.g.
      // await _service.setDone(activity.id, isDone);
      await _persistDoneStub(activity, isDone);
    } catch (_) {
      // Revert on failure by reloading from source of truth.
      if (!mounted) return;
      setState(_reloadDay);
    }
  }

  // TODO(service): DELETE this stub once ScheduleService exposes a real
  // method for persisting completion state, and call that instead.
  Future<void> _persistDoneStub(Schedule activity, bool isDone) async {
    // Intentionally a no-op placeholder so the UI is wired end-to-end and
    // ready to connect to a real backend call.
    await Future<void>.delayed(Duration.zero);
  }

  // TODO(model): this helper assumes `Schedule` has a `copyWith`-style
  // constructor and an `isDone` bool field. Adjust field names as needed,
  // or replace this with `activity.copyWith(isDone: isDone)` if that
  // already exists on your model.
  Schedule _copyWithDone(Schedule activity, bool isDone) {
    try {
      // If Schedule already has copyWith, prefer using it directly instead
      // of this reflection-free placeholder logic.
      return (activity as dynamic).copyWith(isDone: isDone) as Schedule;
    } catch (_) {
      // Fallback: if there's no copyWith/isDone yet, just return the
      // original object unchanged. Remove this fallback once the model
      // TODO above is resolved.
      return activity;
    }
  }

  // ---------------------------------------------------------------------
  // Add menu (FAB) — manual entry, scan, or upload.
  // ---------------------------------------------------------------------

  Future<void> _openAddOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
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
      setState(_reloadDay);
      _loadMonthIndicators();
    }
  }

  // TODO(packages): source == camera should use image_picker's
  // ImagePicker().pickImage(source: ImageSource.camera); source == file
  // should use file_picker's FilePicker.platform.pickFiles(type: image/pdf).
  // Right now both paths skip straight to the mocked scan, ignoring the
  // actual picked file, so the flow is clickable end-to-end without those
  // packages installed yet.
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
      setState(_reloadDay);
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

  @override
  Widget build(BuildContext context) => SafeArea(
      child: Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
              backgroundColor: LifeTrackColors.highlight,
              elevation: 2,
              onPressed: _openAddOptions,
              icon: const Icon(Icons.add, color: LifeTrackColors.ink),
              label: const Text('Add',
                  style: TextStyle(
                      color: LifeTrackColors.ink,
                      fontWeight: FontWeight.w600))),
          body: ListView(
              padding: const EdgeInsets.all(LifeTrackMetrics.screenPadding),
              children: [
                _header(context),
                const SizedBox(height: _headerBottomGap),
                _calendar(context),
                const SizedBox(height: _calendarBottomGap),
                _dayDetail(context),
                const SizedBox(height: _bottomInset),
              ])));

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
                    setState(_reloadDay);
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
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  Widget _calendar(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final monthLabel = DateFormatter.toDisplayDate(_visibleMonth);
    return LifeTrackCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _iconChip(
                color: primary,
                icon: Icons.chevron_left_rounded,
                onTap: () => _moveMonth(-1),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(monthLabel,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (_loadingIndicators) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              _iconChip(
                color: primary,
                icon: Icons.chevron_right_rounded,
                onTap: () => _moveMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _weekdayLabels(context),
          const SizedBox(height: _dayCellGap),
          _monthGrid(context),
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
          Expanded(
            child: Center(child: Text(label, style: style)),
          ),
      ],
    );
  }

  Widget _monthGrid(BuildContext context) {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // DateTime.weekday: Mon=1..Sun=7. We want a Sun-first grid, so shift.
    final leadingBlanks = firstOfMonth.weekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Padding(
            padding: EdgeInsets.only(bottom: row == rows - 1 ? 0 : _dayCellGap),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                      child: _dayCell(
                          context, row * 7 + col, leadingBlanks, daysInMonth)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dayCell(
      BuildContext context, int cellIndex, int leadingBlanks, int daysInMonth) {
    final dayNum = cellIndex - leadingBlanks + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
    }

    final date = DateTime(_visibleMonth.year, _visibleMonth.month, dayNum);
    final isSelected = _isSameDay(date, _selectedDate);
    final isToday = _isSameDay(date, DateTime.now());
    final hasItems = _monthIndicators[DateFormatter.toDbDate(date)] ?? false;
    final primary = Theme.of(context).colorScheme.primary;

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
                : (isToday ? primary.withValues(alpha: 0.06) : null),
            borderRadius: BorderRadius.circular(12),
            border: isToday && !isSelected
                ? Border.all(color: primary.withValues(alpha: 0.4))
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
                      color: isSelected ? LifeTrackColors.highlight : null,
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

  Widget _dayDetail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dayDetailHeader(context),
        const SizedBox(height: 12),
        FutureBuilder<List<Schedule>>(
          future: _dayFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _errorState(context);
            }
            final items = snapshot.data ?? const <Schedule>[];
            if (items.isEmpty) return _emptyState(context);
            return Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: i == items.length - 1 ? 0 : _itemGap),
                    child: _activityRow(context, items[i]),
                  ),
              ],
            );
          },
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

  // TODO(model): reads `activity.isDone`. Update the field name here if
  // your Schedule model calls it something else (e.g. `completed`, `done`).
  Widget _activityRow(BuildContext context, Schedule activity) {
    bool isDone = false;
    try {
      isDone = (activity as dynamic).isDone as bool? ?? false;
    } catch (_) {
      // TODO(model): `isDone` not found on Schedule yet — treat as not done
      // until the field is added.
      isDone = false;
    }

    return LifeTrackCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _toggleDone(activity, !isDone),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Icon(
                isDone
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 24,
                color: isDone
                    ? LifeTrackColors.highlight
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: isDone ? 0.55 : 1,
              child: ScheduleCard(activity: activity),
            ),
          ),
        ],
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
              color: LifeTrackColors.highlight,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _errorState(BuildContext context) {
    return LifeTrackCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 36,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          const SizedBox(height: 8),
          Text('Unable to load this day',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('Check your connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => setState(_reloadDay),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
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
                Text('Tap "Add" to create or scan a schedule.',
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

enum _ScanSource { camera, file }

// ============================================================================
// Add-options bottom sheet
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
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text('Add to schedule',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
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
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).textTheme.bodyMedium?.color),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Scan / Upload review flow
// ============================================================================

/// A single detected activity from the scan step, before it's converted
/// into a real [Schedule] and saved. Kept as its own light model (rather
/// than reusing Schedule directly) so the review UI can hold an editable,
/// possibly-wrong draft without touching the real model until the user
/// confirms import.
class _ScannedActivity {
  String title;
  String category;
  String startTime; // 'HH:mm'
  String endTime; // 'HH:mm'
  bool selected;

  _ScannedActivity({
    required this.title,
    required this.category,
    required this.startTime,
    required this.endTime,
    this.selected = true,
  });
}

/// TODO(backend): this whole class is a placeholder. Replace `mockScan()`
/// with a real pipeline: capture/pick file -> OCR -> text parsing ->
/// structured activities. See the file-level TODO block up top for the
/// exact steps and suggested packages.
class _ScheduleScanService {
  Future<List<_ScannedActivity>> scan(_ScanSource source, XFile input) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    // Fixed sample data so the review UI is fully clickable/demoable
    // without a real OCR call wired up yet.
    return [
      _ScannedActivity(
          title: 'Java Practice',
          category: 'Coding',
          startTime: '14:00',
          endTime: '15:00'),
      _ScannedActivity(
          title: 'Freelance Project',
          category: 'Freelance',
          startTime: '17:00',
          endTime: '18:00'),
      _ScannedActivity(
          title: 'Lunch',
          category: 'Personal',
          startTime: '12:00',
          endTime: '13:00'),
    ];
  }
}

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

class _ScheduleScanReviewSheetState extends State<_ScheduleScanReviewSheet> {
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
    // TODO(packages): before calling mockScan, this is where you'd:
    //   - source == camera: final photo = await ImagePicker().pickImage(source: ImageSource.camera);
    //   - source == file: final file = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg','png','pdf']);
    // then pass that file into the real scan/parse pipeline instead of
    // calling the mock directly.
    final results = await _scanService.scan(widget.source, widget.input);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  // TODO(service): confirm the actual persistence method/signature on
  // ScheduleService — assuming `addScheduleItem(Schedule item)` here based
  // on the rest of this codebase's ScheduleService. Swap if it's named
  // differently, or if a batch-insert method exists, prefer that instead
  // of looping one-by-one.
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
        // TODO(service): confirm this call — see class-level TODO above.
        await widget.scheduleService.addScheduleItem(schedule);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not import — please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceLabel = widget.source == _ScanSource.camera ? 'photo' : 'file';

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
          child: _loading ? _loadingState(sourceLabel) : _resultsState(context),
        ),
      ),
    );
  }

  Widget _loadingState(String sourceLabel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text('Scanning your $sourceLabel...',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text('Looking for activities, times, and categories',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _resultsState(BuildContext context) {
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
              child: Text("Couldn't find anything to import.",
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _scannedItemTile(_results[index]),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _importing ? null : _importSelected,
          child: _importing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'Import ${_results.where((r) => r.selected).length} activities'),
        ),
      ],
    );
  }

  Widget _scannedItemTile(_ScannedActivity item) {
    return LifeTrackCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: item.selected,
            onChanged: (value) =>
                setState(() => item.selected = value ?? false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: item.title,
                  onChanged: (value) => item.title = value,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
