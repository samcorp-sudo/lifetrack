import '../core/database/tables/schedule_table.dart';
import 'task.dart' show TaskPriority, TaskPriorityX;

enum RepeatType { none, daily, weekly }

extension RepeatTypeX on RepeatType {
  String get value {
    switch (this) {
      case RepeatType.none:
        return 'None';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
    }
  }

  static RepeatType fromValue(String value) {
    return RepeatType.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => RepeatType.none,
    );
  }
}

/// An actual time block on the user's calendar (e.g. "Java Practice", 14:00-15:00).
class Schedule {
  final int? id;
  final String title;
  final String category;
  final String startTime;
  final String endTime;
  final String date;
  final RepeatType repeatType;
  final TaskPriority priority;
  final String? notes;

  const Schedule({
    this.id,
    required this.title,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.date,
    this.repeatType = RepeatType.none,
    this.priority = TaskPriority.medium,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      ScheduleTable.colId: id,
      ScheduleTable.colTitle: title,
      ScheduleTable.colCategory: category,
      ScheduleTable.colStartTime: startTime,
      ScheduleTable.colEndTime: endTime,
      ScheduleTable.colDate: date,
      ScheduleTable.colRepeatType: repeatType.value,
      ScheduleTable.colPriority: priority.value,
      ScheduleTable.colNotes: notes,
    };
  }

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map[ScheduleTable.colId] as int?,
      title: map[ScheduleTable.colTitle] as String,
      category: map[ScheduleTable.colCategory] as String,
      startTime: map[ScheduleTable.colStartTime] as String,
      endTime: map[ScheduleTable.colEndTime] as String,
      date: map[ScheduleTable.colDate] as String,
      repeatType: RepeatTypeX.fromValue(map[ScheduleTable.colRepeatType] as String),
      priority: TaskPriorityX.fromValue(
        (map[ScheduleTable.colPriority] as String?) ?? 'Medium',
      ),
      notes: map[ScheduleTable.colNotes] as String?,
    );
  }

  Schedule copyWith({
    int? id,
    String? title,
    String? category,
    String? startTime,
    String? endTime,
    String? date,
    RepeatType? repeatType,
    TaskPriority? priority,
    String? notes,
  }) {
    return Schedule(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      date: date ?? this.date,
      repeatType: repeatType ?? this.repeatType,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
    );
  }
}