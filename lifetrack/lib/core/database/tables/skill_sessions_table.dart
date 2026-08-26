/// Schema for the `skill_sessions` table. NEW in Phase 6.
/// One row per practice session, so Growth Analytics can show
/// "Java practiced 8 sessions" instead of just a progress percentage.
class SkillSessionsTable {
  static const String tableName = 'skill_sessions';

  static const String colId = 'id';
  static const String colSkillId = 'skill_id';
  static const String colDate = 'date';
  static const String colMinutes = 'minutes';
  static const String colNote = 'note';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colSkillId INTEGER NOT NULL,
      $colDate TEXT NOT NULL,
      $colMinutes INTEGER NOT NULL DEFAULT 0,
      $colNote TEXT
    )
  ''';
}