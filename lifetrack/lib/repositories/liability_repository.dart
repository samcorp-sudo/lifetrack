import '../core/database/database_helper.dart';
import '../core/database/tables/liabilities_table.dart';
import '../models/liability.dart';

/// Data operations for [Liability]. Talks to SQLite only — no business logic.
class LiabilityRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(Liability liability) async {
    final db = await _db.database;
    return db.insert(LiabilitiesTable.tableName, liability.toMap());
  }

  Future<List<Liability>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(LiabilitiesTable.tableName, orderBy: LiabilitiesTable.colName);
    return rows.map(Liability.fromMap).toList();
  }

  Future<Liability?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      LiabilitiesTable.tableName,
      where: '${LiabilitiesTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Liability.fromMap(rows.first);
  }

  Future<int> update(Liability liability) async {
    final db = await _db.database;
    return db.update(
      LiabilitiesTable.tableName,
      liability.toMap(),
      where: '${LiabilitiesTable.colId} = ?',
      whereArgs: [liability.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete(
      LiabilitiesTable.tableName,
      where: '${LiabilitiesTable.colId} = ?',
      whereArgs: [id],
    );
  }
}
