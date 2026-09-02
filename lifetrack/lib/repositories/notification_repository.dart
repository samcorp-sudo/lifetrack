import '../core/database/database_helper.dart';
import '../core/database/tables/notifications_table.dart';
import '../models/notification.dart';

class NotificationRepository {
  final _database = DatabaseHelper.instance;

  /// Get all notifications, optionally filtered to unread only
  Future<List<AppNotification>> getNotifications({bool unreadOnly = false}) async {
    try {
      final db = await _database.database;
      const query =
          'SELECT * FROM ${NotificationsTable.tableName} ORDER BY ${NotificationsTable.colTimestamp} DESC';
      final results = await db.rawQuery(query);

      List<AppNotification> notifications =
          results.map((row) => AppNotification.fromMap(row)).toList();

      if (unreadOnly) {
        notifications = notifications.where((n) => !n.isRead).toList();
      }

      return notifications;
    } catch (e) {
      rethrow;
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final db = await _database.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${NotificationsTable.tableName} WHERE ${NotificationsTable.colIsRead} = 0',
      );
      final count = result.isNotEmpty ? (result.first['count'] as int? ?? 0) : 0;
      return count;
    } catch (e) {
      return 0;
    }
  }

  /// Add a new notification
  Future<int> addNotification(AppNotification notification) async {
    try {
      final db = await _database.database;
      return await db.insert(
        NotificationsTable.tableName,
        notification.toMap(),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Mark a notification as read
  Future<int> markAsRead(int notificationId) async {
    try {
      final db = await _database.database;
      return await db.update(
        NotificationsTable.tableName,
        {NotificationsTable.colIsRead: 1},
        where: '${NotificationsTable.colId} = ?',
        whereArgs: [notificationId],
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<int> markAllAsRead() async {
    try {
      final db = await _database.database;
      return await db.update(
        NotificationsTable.tableName,
        {NotificationsTable.colIsRead: 1},
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a notification
  Future<int> deleteNotification(int notificationId) async {
    try {
      final db = await _database.database;
      return await db.delete(
        NotificationsTable.tableName,
        where: '${NotificationsTable.colId} = ?',
        whereArgs: [notificationId],
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Clear all notifications
  Future<int> clearAll() async {
    try {
      final db = await _database.database;
      return await db.delete(NotificationsTable.tableName);
    } catch (e) {
      rethrow;
    }
  }
}
