import '../core/database/tables/assets_table.dart';

/// Something the user owns (e.g. Laptop, Phone, Equipment).
class Asset {
  final int? id;
  final String name;
  final String type;
  final double value;
  final String? note;
  final String updatedAt;

  const Asset({
    this.id,
    required this.name,
    required this.type,
    required this.value,
    this.note,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      AssetsTable.colId: id,
      AssetsTable.colName: name,
      AssetsTable.colType: type,
      AssetsTable.colValue: value,
      AssetsTable.colNote: note,
      AssetsTable.colUpdatedAt: updatedAt,
    };
  }

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map[AssetsTable.colId] as int?,
      name: map[AssetsTable.colName] as String,
      type: map[AssetsTable.colType] as String,
      value: (map[AssetsTable.colValue] as num).toDouble(),
      note: map[AssetsTable.colNote] as String?,
      updatedAt: map[AssetsTable.colUpdatedAt] as String,
    );
  }

  Asset copyWith({
    int? id,
    String? name,
    String? type,
    double? value,
    String? note,
    String? updatedAt,
  }) {
    return Asset(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      value: value ?? this.value,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
