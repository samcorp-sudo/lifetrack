import '../core/database/tables/net_worth_snapshots_table.dart';

/// A recorded net worth at a point in time (e.g. "August ₱35,500").
class NetWorthSnapshot {
  final int? id;
  final String date;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;

  const NetWorthSnapshot({
    this.id,
    required this.date,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
  });

  Map<String, dynamic> toMap() {
    return {
      NetWorthSnapshotsTable.colId: id,
      NetWorthSnapshotsTable.colDate: date,
      NetWorthSnapshotsTable.colTotalAssets: totalAssets,
      NetWorthSnapshotsTable.colTotalLiabilities: totalLiabilities,
      NetWorthSnapshotsTable.colNetWorth: netWorth,
    };
  }

  factory NetWorthSnapshot.fromMap(Map<String, dynamic> map) {
    return NetWorthSnapshot(
      id: map[NetWorthSnapshotsTable.colId] as int?,
      date: map[NetWorthSnapshotsTable.colDate] as String,
      totalAssets: (map[NetWorthSnapshotsTable.colTotalAssets] as num).toDouble(),
      totalLiabilities: (map[NetWorthSnapshotsTable.colTotalLiabilities] as num).toDouble(),
      netWorth: (map[NetWorthSnapshotsTable.colNetWorth] as num).toDouble(),
    );
  }
}