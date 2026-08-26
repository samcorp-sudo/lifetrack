import '../core/database/database_helper.dart';
import '../core/database/tables/assets_table.dart';
import '../models/asset.dart';

/// Data operations for [Asset]. Talks to SQLite only — no business logic.
class AssetRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(Asset asset) async {
    final db = await _db.database;
    return db.insert(AssetsTable.tableName, asset.toMap());
  }

  Future<List<Asset>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(AssetsTable.tableName, orderBy: AssetsTable.colName);
    return rows.map(Asset.fromMap).toList();
  }

  Future<Asset?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      AssetsTable.tableName,
      where: '${AssetsTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Asset.fromMap(rows.first);
  }

  Future<int> update(Asset asset) async {
    final db = await _db.database;
    return db.update(
      AssetsTable.tableName,
      asset.toMap(),
      where: '${AssetsTable.colId} = ?',
      whereArgs: [asset.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete(
      AssetsTable.tableName,
      where: '${AssetsTable.colId} = ?',
      whereArgs: [id],
    );
  }
}
