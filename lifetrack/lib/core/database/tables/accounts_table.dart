/// Schema for the `accounts` table.
/// Stores where the user's money is (Cash, GCash, Bank, PayPal, Other...).
class AccountsTable {
  static const String tableName = 'accounts';

  static const String colId = 'id';
  static const String colName = 'name';
  static const String colType = 'type';
  static const String colBalance = 'balance';
  static const String colCreatedAt = 'created_at';
  static const String colInterestRate = 'interest_rate'; // % per year, new

  static const String createTable = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colName TEXT NOT NULL,
      $colType TEXT NOT NULL,
      $colBalance REAL NOT NULL DEFAULT 0,
      $colCreatedAt TEXT NOT NULL,
      $colInterestRate REAL NOT NULL DEFAULT 0
    )
  ''';
}
