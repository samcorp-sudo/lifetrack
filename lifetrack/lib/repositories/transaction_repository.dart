import '../core/database/database_helper.dart';
import '../core/database/tables/transactions_table.dart';
import '../models/transaction.dart';

/// Data operations for [Transaction]. Talks to SQLite only — no business logic.
class TransactionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(Transaction transaction) async {
    final db = await _db.database;
    return db.insert(TransactionsTable.tableName, transaction.toMap());
  }

  Future<List<Transaction>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(
      TransactionsTable.tableName,
      orderBy: '${TransactionsTable.colDate} DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> getByAccount(int accountId) async {
    final db = await _db.database;
    final rows = await db.query(
      TransactionsTable.tableName,
      where: '${TransactionsTable.colAccountId} = ?',
      whereArgs: [accountId],
      orderBy: '${TransactionsTable.colDate} DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<List<Transaction>> getByDateRange(String startDate, String endDate) async {
    final db = await _db.database;
    final rows = await db.query(
      TransactionsTable.tableName,
      where: '${TransactionsTable.colDate} BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: TransactionsTable.colDate,
    );
    return rows.map(Transaction.fromMap).toList();
  }

  Future<Transaction?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      TransactionsTable.tableName,
      where: '${TransactionsTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Transaction.fromMap(rows.first);
  }

  Future<int> update(Transaction transaction) async {
    final db = await _db.database;
    return db.update(
      TransactionsTable.tableName,
      transaction.toMap(),
      where: '${TransactionsTable.colId} = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete(
      TransactionsTable.tableName,
      where: '${TransactionsTable.colId} = ?',
      whereArgs: [id],
    );
  }
}