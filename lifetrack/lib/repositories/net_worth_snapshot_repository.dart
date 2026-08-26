import '../core/database/database_helper.dart';
import '../core/database/tables/net_worth_snapshots_table.dart';
import '../models/net_worth_snapshot.dart';

/// Data operations for [NetWorthSnapshot]. Talks to SQLite only — no business logic.
class NetWorthSnapshotRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(NetWorthSnapshot snapshot) async {
    final db = await _db.database;
    return db.insert(NetWorthSnapshotsTable.tableName, snapshot.toMap());
  }

  Future<List<NetWorthSnapshot>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(
      NetWorthSnapshotsTable.tableName,
      orderBy: NetWorthSnapshotsTable.colDate,
    );
    return rows.map(NetWorthSnapshot.fromMap).toList();
  }

  /// Replaces any existing snapshot for the same date (one snapshot/day max).
  Future<void> upsertForDate(NetWorthSnapshot snapshot) async {
    final db = await _db.database;
    await db.delete(
      NetWorthSnapshotsTable.tableName,
      where: '${NetWorthSnapshotsTable.colDate} = ?',
      whereArgs: [snapshot.date],
    );
    await db.insert(NetWorthSnapshotsTable.tableName, snapshot.toMap());
  }
}