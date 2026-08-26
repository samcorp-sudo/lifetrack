import '../core/database/tables/transactions_table.dart';

enum TransactionType { income, expense }

extension TransactionTypeX on TransactionType {
  String get value => name; // 'income' | 'expense'

  static TransactionType fromValue(String value) {
    return TransactionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TransactionType.expense,
    );
  }
}

/// A single income or expense, linked to an [Account].
class Transaction {
  final int? id;
  final int accountId;
  final TransactionType type;
  final double amount;
  final String category;
  final String? note;
  final String date;

  const Transaction({
    this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      TransactionsTable.colId: id,
      TransactionsTable.colAccountId: accountId,
      TransactionsTable.colType: type.value,
      TransactionsTable.colAmount: amount,
      TransactionsTable.colCategory: category,
      TransactionsTable.colNote: note,
      TransactionsTable.colDate: date,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map[TransactionsTable.colId] as int?,
      accountId: map[TransactionsTable.colAccountId] as int,
      type: TransactionTypeX.fromValue(map[TransactionsTable.colType] as String),
      amount: (map[TransactionsTable.colAmount] as num).toDouble(),
      category: map[TransactionsTable.colCategory] as String,
      note: map[TransactionsTable.colNote] as String?,
      date: map[TransactionsTable.colDate] as String,
    );
  }

  Transaction copyWith({
    int? id,
    int? accountId,
    TransactionType? type,
    double? amount,
    String? category,
    String? note,
    String? date,
  }) {
    return Transaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
    );
  }
}
