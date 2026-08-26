import '../core/database/database_helper.dart';
import '../core/database/tables/schedule_table.dart';
import '../models/schedule.dart';

/// Data operations for [Schedule]. Talks to SQLite only — no business logic.
class ScheduleRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(Schedule schedule) async {
    final db = await _db.database;
    return db.insert(ScheduleTable.tableName, schedule.toMap());
  }

  Future<List<Schedule>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(ScheduleTable.tableName, orderBy: ScheduleTable.colStartTime);
    return rows.map(Schedule.fromMap).toList();
  }

  Future<List<Schedule>> getByDate(String date) async {
    final db = await _db.database;
    final rows = await db.query(
      ScheduleTable.tableName,
      where: '${ScheduleTable.colDate} = ?',
      whereArgs: [date],
      orderBy: ScheduleTable.colStartTime,
    );
    return rows.map(Schedule.fromMap).toList();
  }

  /// Inclusive range, e.g. Week/Month views (Phase 4 §2). Dates are
  /// 'yyyy-MM-dd' strings, which sort correctly with plain `BETWEEN`.
  Future<List<Schedule>> getByDateRange(String startDate, String endDate) async {
    final db = await _db.database;
    final rows = await db.query(
      ScheduleTable.tableName,
      where: '${ScheduleTable.colDate} BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: '${ScheduleTable.colDate}, ${ScheduleTable.colStartTime}',
    );
    return rows.map(Schedule.fromMap).toList();
  }

  Future<Schedule?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      ScheduleTable.tableName,
      where: '${ScheduleTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Schedule.fromMap(rows.first);
  }

  Future<int> update(Schedule schedule) async {
    final db = await _db.database;
    return db.update(
      ScheduleTable.tableName,
      schedule.toMap(),
      where: '${ScheduleTable.colId} = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete(
      ScheduleTable.tableName,
      where: '${ScheduleTable.colId} = ?',
      whereArgs: [id],
    );
  }
}