import '../core/database/database_helper.dart';
import '../core/database/tables/recommendation_history_table.dart';
import '../models/recommendation_history.dart';

/// Data operations for [RecommendationHistory]. Talks to SQLite only — no business logic.
class RecommendationRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(RecommendationHistory entry) async {
    final db = await _db.database;
    return db.insert(RecommendationHistoryTable.tableName, entry.toMap());
  }

  Future<List<RecommendationHistory>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(
      RecommendationHistoryTable.tableName,
      orderBy: '${RecommendationHistoryTable.colRecommendedAt} DESC',
    );
    return rows.map(RecommendationHistory.fromMap).toList();
  }

  Future<RecommendationHistory?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      RecommendationHistoryTable.tableName,
      where: '${RecommendationHistoryTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return RecommendationHistory.fromMap(rows.first);
  }

  Future<List<RecommendationHistory>> getByResult(String result) async {
    final db = await _db.database;
    final rows = await db.query(
      RecommendationHistoryTable.tableName,
      where: '${RecommendationHistoryTable.colResult} = ?',
      whereArgs: [result],
      orderBy: '${RecommendationHistoryTable.colRecommendedAt} DESC',
    );
    return rows.map(RecommendationHistory.fromMap).toList();
  }

  Future<int> update(RecommendationHistory entry) async {
    final db = await _db.database;
    return db.update(
      RecommendationHistoryTable.tableName,
      entry.toMap(),
      where: '${RecommendationHistoryTable.colId} = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete(
      RecommendationHistoryTable.tableName,
      where: '${RecommendationHistoryTable.colId} = ?',
      whereArgs: [id],
    );
  }
}