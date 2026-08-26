import '../core/database/database_helper.dart';
import '../core/database/tables/goal_contributions_table.dart';
import '../models/goal_contribution.dart';

/// Data operations for [GoalContribution]. Talks to SQLite only — no business logic.
class GoalContributionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(GoalContribution contribution) async {
    final db = await _db.database;
    return db.insert(GoalContributionsTable.tableName, contribution.toMap());
  }

  Future<List<GoalContribution>> getByGoal(int goalId) async {
    final db = await _db.database;
    final rows = await db.query(
      GoalContributionsTable.tableName,
      where: '${GoalContributionsTable.colGoalId} = ?',
      whereArgs: [goalId],
      orderBy: '${GoalContributionsTable.colDate} DESC',
    );
    return rows.map(GoalContribution.fromMap).toList();
  }

  Future<List<GoalContribution>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(
      GoalContributionsTable.tableName,
      orderBy: '${GoalContributionsTable.colDate} DESC',
    );
    return rows.map(GoalContribution.fromMap).toList();
  }

  Future<List<GoalContribution>> getByDateRange(String startDate, String endDate) async {
    final db = await _db.database;
    final rows = await db.query(
      GoalContributionsTable.tableName,
      where: '${GoalContributionsTable.colDate} BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: GoalContributionsTable.colDate,
    );
    return rows.map(GoalContribution.fromMap).toList();
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete(
      GoalContributionsTable.tableName,
      where: '${GoalContributionsTable.colId} = ?',
      whereArgs: [id],
    );
  }
}