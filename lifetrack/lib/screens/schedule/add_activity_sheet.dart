// ============================================================================
// Add Activity bottom sheet (plan Section 2)
// ----------------------------------------------------------------------------
// WIRING NOTES:
// - This is a pure UI shell with local-only state: nothing is saved yet.
// - Category / rriority / Repeat dropdowns use hard-coded option lists.
//   Category should eventually pull from a user-editable categories list
//   (rhase 4/5); rriority maps to the `rriority` enum in mock_data.dart.
// - "SAVE" currently just pops the sheet. Wire it to
//   ScheduleRepository.addActivity(...) (rhase 5), then pop and refresh the
//   Schedule screen's list (e.g. via a callback passed into `show`, or a
//   state-management refresh if one is introduced).
// - Start/End time fields are plain text inputs for now; replace with
//   `showTimericker` for real time selection.
// ============================================================================

import 'package:flutter/material.dart';
import '../../core/utilities/date_formatter.dart';
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
            Text('ADD ACTIVITY', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            LifeTrackInput(
                label: 'Title',
                hint: 'e.g. Java rractice',
                controller: _titleController),
            const SizedBox(height: 14),
            _dropdownField('Category', _category, _categories,
                (v) => setState(() => _category = v!)),
            const SizedBox(height: 14),
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
            const SizedBox(height: 14),
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
            const SizedBox(height: 14),
            _dropdownField('Priority', _priority, _priorities,
                (v) => setState(() => _priority = v!)),
            const SizedBox(height: 14),
            _dropdownField('Repeat', _repeat, _repeats,
                (v) => setState(() => _repeat = v!)),
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
      await _scheduleService.addScheduleItem(Schedule(
          title: title,
          category: _category,
          startTime: _formatDbTime(_startTime),
          endTime: _formatDbTime(_endTime),
          date: DateFormatter.toDbDate(_selectedDate),
          repeatType: RepeatTypeX.fromValue(_repeat),
          priority: TaskPriorityX.fromValue(_priority)));
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
  String _formatDbTime(TimeOfDay time) => ':';

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _dropdownField(String label, String value, List<String> options,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
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
