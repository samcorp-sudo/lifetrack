import '../core/database/database_helper.dart';
import '../core/database/tables/skills_table.dart';
import '../models/skill.dart';

/// Data operations for [Skill]. Talks to SQLite only — no business logic.
class SkillRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(Skill skill) async {
    final db = await _db.database;
    return db.insert(SkillsTable.tableName, skill.toMap());
  }

  Future<List<Skill>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(SkillsTable.tableName, orderBy: SkillsTable.colName);
    return rows.map(Skill.fromMap).toList();
  }

  Future<Skill?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      SkillsTable.tableName,
      where: '${SkillsTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Skill.fromMap(rows.first);
  }

  Future<int> update(Skill skill) async {
    final db = await _db.database;
    return db.update(
      SkillsTable.tableName,
      skill.toMap(),
      where: '${SkillsTable.colId} = ?',
      whereArgs: [skill.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete(
      SkillsTable.tableName,
      where: '${SkillsTable.colId} = ?',
      whereArgs: [id],
    );
  }
}
