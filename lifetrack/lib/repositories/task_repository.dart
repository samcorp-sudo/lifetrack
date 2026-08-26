import '../core/database/database_helper.dart';
import '../core/database/tables/tasks_table.dart';
import '../models/task.dart';

/// Data operations for [Task]. Talks to SQLite only — no business logic.
class TaskRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(Task task) async {
    final db = await _db.database;
    return db.insert(TasksTable.tableName, task.toMap());
  }

  Future<List<Task>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(TasksTable.tableName, orderBy: TasksTable.colDueDate);
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> getByDate(String dueDate) async {
    final db = await _db.database;
    final rows = await db.query(
      TasksTable.tableName,
      where: '${TasksTable.colDueDate} = ?',
      whereArgs: [dueDate],
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<Task?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      TasksTable.tableName,
      where: '${TasksTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  Future<int> update(Task task) async {
    final db = await _db.database;
    return db.update(
      TasksTable.tableName,
      task.toMap(),
      where: '${TasksTable.colId} = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete(
      TasksTable.tableName,
      where: '${TasksTable.colId} = ?',
      whereArgs: [id],
    );
  }
}
