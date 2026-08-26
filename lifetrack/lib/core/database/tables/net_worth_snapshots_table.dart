/// Schema for the `net_worth_snapshots` table. NEW in Phase 5.
/// A recorded point-in-time net worth, so the app can show a trend
/// ("May ₱18,000 → June ₱23,500 → ...") instead of only today's number.
class NetWorthSnapshotsTable {
  static const String tableName = 'net_worth_snapshots';

  static const String colId = 'id';
  static const String colDate = 'date'; // 'yyyy-MM-dd'
  static const String colTotalAssets = 'total_assets';
  static const String colTotalLiabilities = 'total_liabilities';
  static const String colNetWorth = 'net_worth';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colDate TEXT NOT NULL,
      $colTotalAssets REAL NOT NULL,
      $colTotalLiabilities REAL NOT NULL,
      $colNetWorth REAL NOT NULL
    )
  ''';
}