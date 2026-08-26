/// Schema for the `assets` table.
/// Things the user owns (used for Net Worth = Assets - Liabilities).
class AssetsTable {
  static const String tableName = 'assets';

  static const String colId = 'id';
  static const String colName = 'name';
  static const String colType = 'type';
  static const String colValue = 'value';
  static const String colNote = 'note';
  static const String colUpdatedAt = 'updated_at';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colName TEXT NOT NULL,
      $colType TEXT NOT NULL,
      $colValue REAL NOT NULL DEFAULT 0,
      $colNote TEXT,
      $colUpdatedAt TEXT NOT NULL
    )
  ''';
}
