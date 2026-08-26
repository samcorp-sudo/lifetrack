import 'goals_table.dart';

/// Schema for the `goal_contributions` table. NEW in Phase 2.
/// Each time the user adds money toward a goal, it's logged here instead of
/// just overwriting `goals.current_amount` — gives a history per goal.
class GoalContributionsTable {
  static const String tableName = 'goal_contributions';

  static const String colId = 'id';
  static const String colGoalId = 'goal_id';
  static const String colAmount = 'amount';
  static const String colDate = 'date';
  static const String colNote = 'note';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colGoalId INTEGER NOT NULL,
      $colAmount REAL NOT NULL,
      $colDate TEXT NOT NULL,
      $colNote TEXT,
      FOREIGN KEY ($colGoalId) REFERENCES ${GoalsTable.tableName} (${GoalsTable.colId})
        ON DELETE CASCADE
    )
  ''';
}
