import '../core/database/tables/skill_sessions_table.dart';

/// A single logged practice session for a [Skill] (Phase 6 §14/§15:
/// "Java practiced 8 sessions").
class SkillSession {
  final int? id;
  final int skillId;
  final String date;
  final int minutes;
  final String? note;

  const SkillSession({
    this.id,
    required this.skillId,
    required this.date,
    this.minutes = 0,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      SkillSessionsTable.colId: id,
      SkillSessionsTable.colSkillId: skillId,
      SkillSessionsTable.colDate: date,
      SkillSessionsTable.colMinutes: minutes,
      SkillSessionsTable.colNote: note,
    };
  }

  factory SkillSession.fromMap(Map<String, dynamic> map) {
    return SkillSession(
      id: map[SkillSessionsTable.colId] as int?,
      skillId: map[SkillSessionsTable.colSkillId] as int,
      date: map[SkillSessionsTable.colDate] as String,
      minutes: map[SkillSessionsTable.colMinutes] as int,
      note: map[SkillSessionsTable.colNote] as String?,
    );
  }
}