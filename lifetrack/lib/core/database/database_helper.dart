import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'tables/accounts_table.dart';
import 'tables/transactions_table.dart';
import 'tables/assets_table.dart';
import 'tables/liabilities_table.dart';
import 'tables/goals_table.dart';
import 'tables/goal_contributions_table.dart';
import 'tables/tasks_table.dart';
import 'tables/schedule_table.dart';
import 'tables/skills_table.dart';
import 'tables/skill_sessions_table.dart';
import 'tables/recommendation_history_table.dart';
import 'tables/net_worth_snapshots_table.dart';
import 'tables/notifications_table.dart';

/// Singleton that opens/creates the local SQLite database and
/// runs every table's CREATE TABLE statement.
///
///   LifeTrack
///     +-- TIME SYSTEM   -> schedule, tasks
///     +-- MONEY SYSTEM  -> accounts, transactions, assets, liabilities,
///                          net_worth_snapshots
///     +-- GROWTH        -> goals, goal_contributions, skills,
///                          skill_sessions, recommendation_history
///
/// Screens -> Services -> Repositories -> SQLite (this file)
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'lifetrack.db';
  static const int _dbVersion = 3;

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String dbPath = await getDatabasesPath();
    final String path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
      onUpgrade: _onUpgrade,
      onDowngrade: _onDowngrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // --- Schedule: add is_done column (v3) -----------------------------------
    // Uses the same ensure-columns strategy below so existing rows keep
    // their data; new column defaults to 0 (not done).
    await _ensureTableColumns(
      db,
      ScheduleTable.tableName,
      ScheduleTable.createTable,
      <String, String>{
        ScheduleTable.colTitle: 'TEXT NOT NULL DEFAULT ""',
        ScheduleTable.colCategory: 'TEXT NOT NULL DEFAULT ""',
        ScheduleTable.colStartTime: 'TEXT NOT NULL DEFAULT ""',
        ScheduleTable.colEndTime: 'TEXT NOT NULL DEFAULT ""',
        ScheduleTable.colDate: 'TEXT NOT NULL DEFAULT ""',
        ScheduleTable.colRepeatType: 'TEXT NOT NULL DEFAULT "None"',
        ScheduleTable.colPriority: 'TEXT NOT NULL DEFAULT "Medium"',
        ScheduleTable.colNotes: 'TEXT',
        ScheduleTable.colIsDone: 'INTEGER NOT NULL DEFAULT 0', // ← NEW
      },
    );

    // --- Assets -------------------------------------------------------------
    await _ensureTableColumns(
      db,
      AssetsTable.tableName,
      AssetsTable.createTable,
      <String, String>{
        AssetsTable.colName: 'TEXT NOT NULL DEFAULT ""',
        AssetsTable.colType: 'TEXT NOT NULL DEFAULT ""',
        AssetsTable.colValue: 'REAL NOT NULL DEFAULT 0',
        AssetsTable.colNote: 'TEXT',
        AssetsTable.colUpdatedAt: 'TEXT NOT NULL DEFAULT ""',
      },
    );

    // --- Liabilities --------------------------------------------------------
    await _ensureTableColumns(
      db,
      LiabilitiesTable.tableName,
      LiabilitiesTable.createTable,
      <String, String>{
        LiabilitiesTable.colName: 'TEXT NOT NULL DEFAULT ""',
        LiabilitiesTable.colType: 'TEXT NOT NULL DEFAULT ""',
        LiabilitiesTable.colAmount: 'REAL NOT NULL DEFAULT 0',
        LiabilitiesTable.colDueDate: 'TEXT',
        LiabilitiesTable.colNote: 'TEXT',
        LiabilitiesTable.colUpdatedAt: 'TEXT NOT NULL DEFAULT ""',
      },
    );
  }

  Future<void> _ensureTableColumns(
    Database db,
    String tableName,
    String createSql,
    Map<String, String> requiredColumns,
  ) async {
    final tableExists = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );

    if (tableExists.isEmpty) {
      await db.execute(createSql);
      return;
    }

    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final existingColumns = columns.map((row) => row['name'] as String).toSet();

    for (final entry in requiredColumns.entries) {
      if (!existingColumns.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE $tableName ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
  }

  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('PRAGMA foreign_keys = OFF');
  }

  Future<void> _onCreate(Database db, int version) async {
    // TIME SYSTEM
    await db.execute(ScheduleTable.createTable);
    await db.execute(TasksTable.createTable);

    // MONEY SYSTEM
    await db.execute(AccountsTable.createTable);
    await db.execute(TransactionsTable.createTable);
    await db.execute(AssetsTable.createTable);
    await db.execute(LiabilitiesTable.createTable);
    await db.execute(NetWorthSnapshotsTable.createTable);

    // GROWTH
    await db.execute(GoalsTable.createTable);
    await db.execute(GoalContributionsTable.createTable);
    await db.execute(SkillsTable.createTable);
    await db.execute(SkillSessionsTable.createTable);
    await db.execute(RecommendationHistoryTable.createTable);

    // NOTIFICATIONS
    await db.execute(NotificationsTable.createTable);
  }

  Future<void> clearAllData() async {
    final db = await database;
    const tables = <String>[
      'recommendation_history',
      'skill_sessions',
      'goal_contributions',
      'transactions',
      'assets',
      'liabilities',
      'net_worth_snapshots',
      'tasks',
      'schedule',
      'skills',
      'goals',
      'accounts',
      'notifications'
    ];
    await db.transaction((transaction) async {
      for (final table in tables) {
        await transaction.delete(table);
      }
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

