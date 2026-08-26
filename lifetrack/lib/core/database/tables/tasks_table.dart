/// Schema for the `tasks` table.
/// Things the user needs to accomplish (e.g. Dashboard "Today's Tasks").
class TasksTable {
  static const String tableName = 'tasks';

  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colDescription = 'description';
  static const String colPriority = 'priority'; // e.g. 'Low' | 'Medium' | 'High'
  static const String colStatus = 'status'; // e.g. 'Pending' | 'Done'
  static const String colDueDate = 'due_date';
  static const String colCategory = 'category';

  static const String createTable = '''
    CREATE TABLE $tableName (
      $colId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colTitle TEXT NOT NULL,
      $colDescription TEXT,
      $colPriority TEXT NOT NULL DEFAULT 'Medium',
      $colStatus TEXT NOT NULL DEFAULT 'Pending',
      $colDueDate TEXT,
      $colCategory TEXT
    )
  ''';
}
