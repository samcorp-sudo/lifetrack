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

/// Singleton that opens/creates the local SQLite database and
/// runs every table's CREATE TABLE statement.
///
///   LifeTrack
///     â”œâ”€â”€ TIME SYSTEM   -> schedule, tasks
///     â”œâ”€â”€ MONEY SYSTEM  -> accounts, transactions, assets, liabilities,
///     â”‚                    net_worth_snapshots
///     â””â”€â”€ GROWTH        -> goals, goal_contributions, skills,
///                          skill_sessions, recommendation_history
///
/// Screens -> Services -> Repositories -> SQLite (this file)
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'lifetrack.db';
  static const int _dbVersion = 1;

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
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
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
      'accounts'
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
