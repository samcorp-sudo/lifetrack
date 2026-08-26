import '../core/database/tables/goals_table.dart';
import 'task.dart' show TaskPriority, TaskPriorityX;

enum GoalStatus { active, completed }

extension GoalStatusX on GoalStatus {
  String get value {
    switch (this) {
      case GoalStatus.active:
        return 'Active';
      case GoalStatus.completed:
        return 'Completed';
    }
  }

  static GoalStatus fromValue(String value) {
    return GoalStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => GoalStatus.active,
    );
  }
}

/// A savings/skill target (e.g. "New Laptop", "Emergency Fund").
class Goal {
  final int? id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? deadline; // 'yyyy-MM-dd'
  final String? category;
  final TaskPriority priority;
  final GoalStatus status;

  const Goal({
    this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.deadline,
    this.category,
    this.priority = TaskPriority.medium,
    this.status = GoalStatus.active,
  });

  /// Progress from 0.0 to 1.0, used to render progress bars like ████████░░░░ 40%.
  double get progress =>
      targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1);

  double get remaining => (targetAmount - currentAmount).clamp(0, double.infinity);

  Map<String, dynamic> toMap() {
    return {
      GoalsTable.colId: id,
      GoalsTable.colName: name,
      GoalsTable.colTargetAmount: targetAmount,
      GoalsTable.colCurrentAmount: currentAmount,
      GoalsTable.colDeadline: deadline,
      GoalsTable.colCategory: category,
      GoalsTable.colPriority: priority.value,
      GoalsTable.colStatus: status.value,
    };
  }

  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map[GoalsTable.colId] as int?,
      name: map[GoalsTable.colName] as String,
      targetAmount: (map[GoalsTable.colTargetAmount] as num).toDouble(),
      currentAmount: (map[GoalsTable.colCurrentAmount] as num).toDouble(),
      deadline: map[GoalsTable.colDeadline] as String?,
      category: map[GoalsTable.colCategory] as String?,
      priority: TaskPriorityX.fromValue(
        (map[GoalsTable.colPriority] as String?) ?? 'Medium',
      ),
      status: GoalStatusX.fromValue(map[GoalsTable.colStatus] as String),
    );
  }

  Goal copyWith({
    int? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    String? deadline,
    String? category,
    TaskPriority? priority,
    GoalStatus? status,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
    );
  }
}