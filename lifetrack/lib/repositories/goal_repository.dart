import '../core/database/database_helper.dart';
import '../core/database/tables/goals_table.dart';
import '../models/goal.dart';

/// Data operations for [Goal]. Talks to SQLite only — no business logic.
class GoalRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(Goal goal) async {
    final db = await _db.database;
    return db.insert(GoalsTable.tableName, goal.toMap());
  }

  Future<List<Goal>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(GoalsTable.tableName, orderBy: GoalsTable.colDeadline);
    return rows.map(Goal.fromMap).toList();
  }

  Future<Goal?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      GoalsTable.tableName,
      where: '${GoalsTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Goal.fromMap(rows.first);
  }

  Future<int> update(Goal goal) async {
    final db = await _db.database;
    return db.update(
      GoalsTable.tableName,
      goal.toMap(),
      where: '${GoalsTable.colId} = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete(
      GoalsTable.tableName,
      where: '${GoalsTable.colId} = ?',
      whereArgs: [id],
    );
  }
}
