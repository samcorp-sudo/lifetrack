// ============================================================================
// Add Activity bottom sheet (plan Section 2)
// ----------------------------------------------------------------------------
// IMPROVEMENTS OVER PREVIOUS VERSION (layout only — validation, save logic,
// and all field state are unchanged):
// - Close button now uses the same tinted icon-chip style as the header
//   icons on Settings/Money/Schedule, instead of a bare IconButton.
// - Priority and Repeat are now a side-by-side row, mirroring the existing
//   Start/End time row pattern already in this file — cuts the form's
//   vertical length by one field-row and groups two short dropdowns the
//   same way two short time pickers are already grouped.
// - Dropdown field container gets a touch of vertical padding so its height
//   reads closer to the adjacent LifeTrackInput fields.
//
// WIRING NOTES (unchanged from original):
// - This is a pure UI shell with local-only state: nothing is saved yet
//   beyond ScheduleService.addScheduleItem, which is already wired below.
// - Category / Priority / Repeat dropdowns use hard-coded option lists.
//   Category should eventually pull from a user-editable categories list
//   (Phase 4/5); Priority maps to the `Priority` enum in mock_data.dart.
// - Start/End time fields use showTimePicker for real time selection.
//
// NOTIFICATIONS:
// - On save, a real status-bar alert is scheduled 15 minutes before the
//   activity start via NotificationService.scheduleActivityReminder.
//   The alert fires even when the app is closed, provided the Android
//   manifest has POST_NOTIFICATIONS + the flutter_local_notifications
//   boot receiver (see AndroidManifest.xml).
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/utilities/date_formatter.dart';
import '../../core/security/notification_services.dart';
import '../../models/schedule.dart';
import '../../models/task.dart';
import '../../services/schedule_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lifetrack_button.dart';
import '../../widgets/lifetrack_input.dart';

class AddActivitySheet extends StatefulWidget {
  const AddActivitySheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddActivitySheet(),
    );
  }

  @override
  State<AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends State<AddActivitySheet> {
  static const _fieldGap = 14.0;
  static const _iconChipSize = 34.0;

  final _titleController = TextEditingController();
  final _scheduleService = ScheduleService();
  bool _isSaving = false;
  String _category = 'Coding';
  String _priority = 'High';
  String _repeat = 'None';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  static const _categories = ['Coding', 'School', 'Work', 'Personal', 'Free'];
  static const _priorities = ['High', 'Medium', 'Low'];
  static const _repeats = ['None', 'Daily', 'Weekly'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: LifeTrackColors.strokeDark,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('ADD ACTIVITY',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                _iconChip(
                  context,
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LifeTrackInput(
                label: 'Title',
                hint: 'e.g. Java Practice',
                controller: _titleController),
            const SizedBox(height: _fieldGap),
            _dropdownField('Category', _category, _categories,
                (v) => setState(() => _category = v!)),
            const SizedBox(height: _fieldGap),
            LifeTrackInput(
                label: 'Date',
                hint: DateFormatter.toDisplayDate(_selectedDate),
                readOnly: true,
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null && mounted) {
                    setState(() => _selectedDate = pickedDate);
                  }
                }),
            const SizedBox(height: _fieldGap),
            Row(
              children: [
                Expanded(
                    child: LifeTrackInput(
                        label: 'Start',
                        hint: _formatTime(_startTime),
                        readOnly: true,
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: _startTime,
                          );
                          if (pickedTime != null && mounted) {
                            setState(() => _startTime = pickedTime);
                          }
                        })),
                const SizedBox(width: 12),
                Expanded(
                    child: LifeTrackInput(
                        label: 'End',
                        hint: _formatTime(_endTime),
                        readOnly: true,
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: _endTime,
                          );
                          if (pickedTime != null && mounted) {
                            setState(() => _endTime = pickedTime);
                          }
                        })),
              ],
            ),
            const SizedBox(height: _fieldGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _dropdownField('Priority', _priority, _priorities,
                      (v) => setState(() => _priority = v!)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dropdownField('Repeat', _repeat, _repeats,
                      (v) => setState(() => _repeat = v!)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: LifeTrackButton(
                    label: 'CANCEL',
                    style: LifeTrackButtonStyle.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LifeTrackButton(
                    label: 'SAVE',
                    isLoading: _isSaving,
                    onPressed: _saveActivity,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveActivity() async {
    final title = _titleController.text.trim();
    if (title.isEmpty ||
        _timeToMinutes(_endTime) <= _timeToMinutes(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a title and choose a valid time range.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      await _scheduleService.addScheduleItem(Schedule(
          title: title,
          category: _category,
          startTime: _formatDbTime(_startTime),
          endTime: _formatDbTime(_endTime),
          date: DateFormatter.toDbDate(_selectedDate),
          repeatType: RepeatTypeX.fromValue(_repeat),
          priority: TaskPriorityX.fromValue(_priority)));

      // Schedule a real status-bar alert 15 minutes before the activity
      // starts. The helper silently no-ops if the start time is already in
      // the past, so adding a same-day activity that has already begun is
      // safe.
      await NotificationService.scheduleActivityReminder(
        title: title,
        activityStart: startDateTime,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to save activity.')));
      }
    }
  }

  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  // Stores time in 24-hour "HH:mm" form for the database.
  String _formatDbTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // Shared tinted-chip look for icon buttons, matching the header icons on
  // Settings/Money/Schedule.
  Widget _iconChip(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final color = Theme.of(context).colorScheme.primary;
    final chip = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _iconChipSize,
        height: _iconChipSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
  }

  Widget _dropdownField(String label, String value, List<String> options,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LifeTrackMetrics.chipRadius),
            border: Border.all(color: LifeTrackColors.strokeDark),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
