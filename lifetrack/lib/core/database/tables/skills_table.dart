/// Schema for the `skills` table.
/// The user's learning progress (e.g. Java 70%, Flutter 30%).
class SkillsTable {
  static const String tableName = 'skills';

  static const String colId = 'id';
  static const String colName = 'name';
  static const String colProgress = 'progress';
  static const String colTarget = 'target';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colName TEXT NOT NULL,
      $colProgress REAL NOT NULL DEFAULT 0,
      $colTarget REAL NOT NULL DEFAULT 100
    )
  ''';
}
