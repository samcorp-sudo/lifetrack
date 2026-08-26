import 'accounts_table.dart';

/// Schema for the `transactions` table.
/// Every income or expense. One account has many transactions.
class TransactionsTable {
  static const String tableName = 'transactions';

  static const String colId = 'id';
  static const String colAccountId = 'account_id';
  static const String colType = 'type'; // 'income' | 'expense'
  static const String colAmount = 'amount';
  static const String colCategory = 'category';
  static const String colNote = 'note';
  static const String colDate = 'date';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colAccountId INTEGER NOT NULL,
      $colType TEXT NOT NULL,
      $colAmount REAL NOT NULL,
      $colCategory TEXT NOT NULL,
      $colNote TEXT,
      $colDate TEXT NOT NULL,
      FOREIGN KEY ($colAccountId) REFERENCES ${AccountsTable.tableName} (${AccountsTable.colId})
        ON DELETE CASCADE
    )
  ''';
}
