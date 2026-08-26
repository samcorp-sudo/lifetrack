import '../core/database/tables/tasks_table.dart';

enum TaskPriority { low, medium, high }

extension TaskPriorityX on TaskPriority {
  String get value {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  static TaskPriority fromValue(String value) {
    return TaskPriority.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => TaskPriority.medium,
    );
  }
}

enum TaskStatus { pending, inProgress, done }

extension TaskStatusX on TaskStatus {
  String get value {
    switch (this) {
      case TaskStatus.pending:
        return 'Pending';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Done';
    }
  }

  static TaskStatus fromValue(String value) {
    return TaskStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => TaskStatus.pending,
    );
  }
}

/// Something the user needs to accomplish (shown on the Dashboard).
class Task {
  final int? id;
  final String title;
  final String? description;
  final TaskPriority priority;
  final TaskStatus status;
  final String? dueDate;
  final String? category;

  const Task({
    this.id,
    required this.title,
    this.description,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    this.dueDate,
    this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      TasksTable.colId: id,
      TasksTable.colTitle: title,
      TasksTable.colDescription: description,
      TasksTable.colPriority: priority.value,
      TasksTable.colStatus: status.value,
      TasksTable.colDueDate: dueDate,
      TasksTable.colCategory: category,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map[TasksTable.colId] as int?,
      title: map[TasksTable.colTitle] as String,
      description: map[TasksTable.colDescription] as String?,
      priority: TaskPriorityX.fromValue(map[TasksTable.colPriority] as String),
      status: TaskStatusX.fromValue(map[TasksTable.colStatus] as String),
      dueDate: map[TasksTable.colDueDate] as String?,
      category: map[TasksTable.colCategory] as String?,
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    TaskPriority? priority,
    TaskStatus? status,
    String? dueDate,
    String? category,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      category: category ?? this.category,
    );
  }
}