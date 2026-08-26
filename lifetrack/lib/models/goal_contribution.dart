import '../core/database/tables/goal_contributions_table.dart';

/// A single deposit toward a [Goal]. NEW in Phase 2 — lets a goal's
/// current_amount be built up from a history of contributions instead
/// of a single manual overwrite.
class GoalContribution {
  final int? id;
  final int goalId;
  final double amount;
  final String date;
  final String? note;

  const GoalContribution({
    this.id,
    required this.goalId,
    required this.amount,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      GoalContributionsTable.colId: id,
      GoalContributionsTable.colGoalId: goalId,
      GoalContributionsTable.colAmount: amount,
      GoalContributionsTable.colDate: date,
      GoalContributionsTable.colNote: note,
    };
  }

  factory GoalContribution.fromMap(Map<String, dynamic> map) {
    return GoalContribution(
      id: map[GoalContributionsTable.colId] as int?,
      goalId: map[GoalContributionsTable.colGoalId] as int,
      amount: (map[GoalContributionsTable.colAmount] as num).toDouble(),
      date: map[GoalContributionsTable.colDate] as String,
      note: map[GoalContributionsTable.colNote] as String?,
    );
  }

  GoalContribution copyWith({
    int? id,
    int? goalId,
    double? amount,
    String? date,
    String? note,
  }) {
    return GoalContribution(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }
}
