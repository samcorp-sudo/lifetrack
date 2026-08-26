import '../core/database/database_helper.dart';
import '../core/database/tables/accounts_table.dart';
import '../models/account.dart';

/// Data operations for [Account]. Talks to SQLite only — no business logic.
/// Used by services (e.g. MoneyService), never called directly from screens.
class AccountRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(Account account) async {
    final db = await _db.database;
    return db.insert(AccountsTable.tableName, account.toMap());
  }

  Future<List<Account>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(AccountsTable.tableName, orderBy: AccountsTable.colName);
    return rows.map(Account.fromMap).toList();
  }

  Future<Account?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      AccountsTable.tableName,
      where: '${AccountsTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Account.fromMap(rows.first);
  }

  Future<int> update(Account account) async {
    final db = await _db.database;
    return db.update(
      AccountsTable.tableName,
      account.toMap(),
      where: '${AccountsTable.colId} = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete(
      AccountsTable.tableName,
      where: '${AccountsTable.colId} = ?',
      whereArgs: [id],
    );
  }
}
