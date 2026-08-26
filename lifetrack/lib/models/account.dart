import '../core/database/tables/accounts_table.dart';

/// Where the user's money is (Cash, GCash, Bank, PayPal, Other...).
class Account {
  final int? id;
  final String name;
  final String type;
  final double balance;
  final String createdAt;

  const Account({
    this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      AccountsTable.colId: id,
      AccountsTable.colName: name,
      AccountsTable.colType: type,
      AccountsTable.colBalance: balance,
      AccountsTable.colCreatedAt: createdAt,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map[AccountsTable.colId] as int?,
      name: map[AccountsTable.colName] as String,
      type: map[AccountsTable.colType] as String,
      balance: (map[AccountsTable.colBalance] as num).toDouble(),
      createdAt: map[AccountsTable.colCreatedAt] as String,
    );
  }

  Account copyWith({
    int? id,
    String? name,
    String? type,
    double? balance,
    String? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
