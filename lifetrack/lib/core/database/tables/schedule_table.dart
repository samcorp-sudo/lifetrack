// ============================================================================
// Schema for the `schedule` table.
// The user's actual time blocks (e.g. "Java Practice", 14:00-15:00, Weekly).
//
// NOTE: `is_done` was added so the Schedule screen can track completion
// without dynamic casts. Defaults to 0 (not done) for existing rows.
// ============================================================================

class ScheduleTable {
  static const String tableName = 'schedule';

  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colCategory =
      'category'; // School, Coding, Freelance, Farming, Personal, Rest...
  static const String colStartTime = 'start_time';
  static const String colEndTime = 'end_time';
  static const String colDate = 'date';
  static const String colRepeatType =
      'repeat_type'; // e.g. 'None' | 'Daily' | 'Weekly'
  static const String colPriority =
      'priority'; // 'Low' | 'Medium' | 'High' — Phase 4
  static const String colNotes = 'notes'; // Phase 4
  static const String colIsDone = 'is_done'; // ← NEW — 0 = not done, 1 = done

  static const String createTable = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colTitle TEXT NOT NULL,
      $colCategory TEXT NOT NULL,
      $colStartTime TEXT NOT NULL,
      $colEndTime TEXT NOT NULL,
      $colDate TEXT NOT NULL,
      $colRepeatType TEXT NOT NULL DEFAULT 'None',
      $colPriority TEXT NOT NULL DEFAULT 'Medium',
      $colNotes TEXT,
      $colIsDone INTEGER NOT NULL DEFAULT 0
    )
  ''';
}
