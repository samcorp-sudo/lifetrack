/// Schema for the `liabilities` table.
/// Money the user owes (used for Net Worth = Assets - Liabilities).
class LiabilitiesTable {
  static const String tableName = 'liabilities';

  static const String colId = 'id';
  static const String colName = 'name';
  static const String colType = 'type';
  static const String colAmount = 'amount';
  static const String colDueDate = 'due_date';
  static const String colNote = 'note';
  static const String colUpdatedAt = 'updated_at';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colName TEXT NOT NULL,
      $colType TEXT NOT NULL,
      $colAmount REAL NOT NULL DEFAULT 0,
      $colDueDate TEXT,
      $colNote TEXT,
      $colUpdatedAt TEXT NOT NULL
    )
  ''';
}
