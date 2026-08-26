import '../core/database/tables/liabilities_table.dart';

/// Money the user owes (e.g. Laptop Payment, Other debts).
class Liability {
  final int? id;
  final String name;
  final String type;
  final double amount;
  final String? dueDate;
  final String? note;

  const Liability({
    this.id,
    required this.name,
    required this.type,
    required this.amount,
    this.dueDate,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      LiabilitiesTable.colId: id,
      LiabilitiesTable.colName: name,
      LiabilitiesTable.colType: type,
      LiabilitiesTable.colAmount: amount,
      LiabilitiesTable.colDueDate: dueDate,
      LiabilitiesTable.colNote: note,
    };
  }

  factory Liability.fromMap(Map<String, dynamic> map) {
    return Liability(
      id: map[LiabilitiesTable.colId] as int?,
      name: map[LiabilitiesTable.colName] as String,
      type: map[LiabilitiesTable.colType] as String,
      amount: (map[LiabilitiesTable.colAmount] as num).toDouble(),
      dueDate: map[LiabilitiesTable.colDueDate] as String?,
      note: map[LiabilitiesTable.colNote] as String?,
    );
  }

  Liability copyWith({
    int? id,
    String? name,
    String? type,
    double? amount,
    String? dueDate,
    String? note,
  }) {
    return Liability(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      note: note ?? this.note,
    );
  }
}
