import '../core/database/tables/skills_table.dart';

/// The user's learning progress for one skill (e.g. Java 70% / 100%).
class Skill {
  final int? id;
  final String name;
  final double progress;
  final double target;

  const Skill({
    this.id,
    required this.name,
    this.progress = 0,
    this.target = 100,
  });

  /// 0.0 to 1.0, for rendering bars like ███████░░░ 70%.
  double get percent => target <= 0 ? 0 : (progress / target).clamp(0, 1);

  Map<String, dynamic> toMap() {
    return {
      SkillsTable.colId: id,
      SkillsTable.colName: name,
      SkillsTable.colProgress: progress,
      SkillsTable.colTarget: target,
    };
  }

  factory Skill.fromMap(Map<String, dynamic> map) {
    return Skill(
      id: map[SkillsTable.colId] as int?,
      name: map[SkillsTable.colName] as String,
      progress: (map[SkillsTable.colProgress] as num).toDouble(),
      target: (map[SkillsTable.colTarget] as num).toDouble(),
    );
  }

  Skill copyWith({
    int? id,
    String? name,
    double? progress,
    double? target,
  }) {
    return Skill(
      id: id ?? this.id,
      name: name ?? this.name,
      progress: progress ?? this.progress,
      target: target ?? this.target,
    );
  }
}
