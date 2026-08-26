/// Schema for the `recommendation_history` table. Redesigned in Phase 7
/// to match §13 exactly (task_id, activity_title, recommended_at, result,
/// completed_at), plus a few extra columns needed to actually run the
/// scoring engine (category, estimated_minutes, feedback).
class RecommendationHistoryTable {
  static const String tableName = 'recommendation_history';

  static const String colId = 'id';
  static const String colTaskId = 'task_id'; // nullable — not every suggestion is task-based (could be a skill/rest)
  static const String colActivityTitle = 'activity_title';
  static const String colCategory = 'category';
  static const String colAvailableMinutes = 'available_minutes';
  static const String colEstimatedMinutes = 'estimated_minutes';
  static const String colRecommendedAt = 'recommended_at'; // 'yyyy-MM-dd HH:mm'
  static const String colResult = 'result'; // 'in_progress' | 'completed' | 'skipped'
  static const String colFeedback = 'feedback'; // 'positive' | 'neutral' | 'negative' | null
  static const String colCompletedAt = 'completed_at'; // 'yyyy-MM-dd HH:mm', nullable

  static const String createTable = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colTaskId INTEGER,
      $colActivityTitle TEXT NOT NULL,
      $colCategory TEXT,
      $colAvailableMinutes INTEGER NOT NULL,
      $colEstimatedMinutes INTEGER NOT NULL,
      $colRecommendedAt TEXT NOT NULL,
      $colResult TEXT NOT NULL DEFAULT 'in_progress',
      $colFeedback TEXT,
      $colCompletedAt TEXT
    )
  ''';
}