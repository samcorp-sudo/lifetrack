/// Schema for the `goals` table.
/// User's savings/skill targets (e.g. "New Laptop", "Emergency Fund").
class GoalsTable {
  static const String tableName = 'goals';

  static const String colId = 'id';
  static const String colName = 'name';
  static const String colTargetAmount = 'target_amount';
  static const String colCurrentAmount = 'current_amount';
  static const String colDeadline = 'deadline';
  static const String colCategory = 'category';
  static const String colPriority = 'priority'; // 'Low' | 'Medium' | 'High' — Phase 5
  static const String colStatus = 'status'; // e.g. 'Active' | 'Completed'

  static const String createTable = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colName TEXT NOT NULL,
      $colTargetAmount REAL NOT NULL,
      $colCurrentAmount REAL NOT NULL DEFAULT 0,
      $colDeadline TEXT,
      $colCategory TEXT,
      $colPriority TEXT NOT NULL DEFAULT 'Medium',
      $colStatus TEXT NOT NULL DEFAULT 'Active'
    )
  ''';
}