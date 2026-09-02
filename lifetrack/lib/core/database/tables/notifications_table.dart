/// Schema for the `notifications` table.
/// Local storage for all app notifications (tasks, schedules, achievements).
class NotificationsTable {
  static const String tableName = 'notifications';

  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colBody = 'body';
  static const String colType = 'type'; // e.g. 'task_reminder' | 'schedule_reminder'
  static const String colTimestamp = 'timestamp';
  static const String colIsRead = 'is_read';
  static const String colMetadata = 'metadata';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colTitle TEXT NOT NULL,
      $colBody TEXT NOT NULL,
      $colType TEXT NOT NULL DEFAULT 'general',
      $colTimestamp TEXT NOT NULL,
      $colIsRead INTEGER NOT NULL DEFAULT 0,
      $colMetadata TEXT
    )
  ''';
}