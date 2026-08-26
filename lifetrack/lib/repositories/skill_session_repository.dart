import '../core/database/database_helper.dart';
import '../core/database/tables/skill_sessions_table.dart';
import '../models/skill_session.dart';

/// Data operations for [SkillSession]. Talks to SQLite only — no business logic.
class SkillSessionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(SkillSession session) async {
    final db = await _db.database;
    return db.insert(SkillSessionsTable.tableName, session.toMap());
  }

  Future<List<SkillSession>> getBySkill(int skillId) async {
    final db = await _db.database;
    final rows = await db.query(
      SkillSessionsTable.tableName,
      where: '${SkillSessionsTable.colSkillId} = ?',
      whereArgs: [skillId],
      orderBy: '${SkillSessionsTable.colDate} DESC',
    );
    return rows.map(SkillSession.fromMap).toList();
  }

  Future<List<SkillSession>> getByDateRange(String startDate, String endDate) async {
    final db = await _db.database;
    final rows = await db.query(
      SkillSessionsTable.tableName,
      where: '${SkillSessionsTable.colDate} BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: SkillSessionsTable.colDate,
    );
    return rows.map(SkillSession.fromMap).toList();
  }

  Future<List<SkillSession>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(SkillSessionsTable.tableName, orderBy: SkillSessionsTable.colDate);
    return rows.map(SkillSession.fromMap).toList();
  }
}