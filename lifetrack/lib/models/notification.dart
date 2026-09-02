import 'package:flutter/material.dart';

enum NotificationType {
  taskReminder,
  scheduleReminder,
  freeTimeAlert,
  goalProgress,
  achievement,
  general,
}

extension NotificationTypeX on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.taskReminder:
        return 'task_reminder';
      case NotificationType.scheduleReminder:
        return 'schedule_reminder';
      case NotificationType.freeTimeAlert:
        return 'free_time_alert';
      case NotificationType.goalProgress:
        return 'goal_progress';
      case NotificationType.achievement:
        return 'achievement';
      case NotificationType.general:
        return 'general';
    }
  }

  static NotificationType fromValue(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.general,
    );
  }

  IconData get icon {
    switch (this) {
      case NotificationType.taskReminder:
        return Icons.task_alt_rounded;
      case NotificationType.scheduleReminder:
        return Icons.event_rounded;
      case NotificationType.freeTimeAlert:
        return Icons.bolt_rounded;
      case NotificationType.goalProgress:
        return Icons.flag_rounded;
      case NotificationType.achievement:
        return Icons.star_rounded;
      case NotificationType.general:
        return Icons.notifications_rounded;
    }
  }
}

class AppNotification {
  final int? id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, String>? metadata;

  AppNotification({
    this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.value,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'metadata': metadata != null ? _jsonEncode(metadata!) : null,
    };
  }

  static AppNotification fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as int?,
      title: map['title'] as String,
      body: map['body'] as String,
      type: NotificationTypeX.fromValue(map['type'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      isRead: (map['is_read'] as int) == 1,
      metadata: map['metadata'] != null
          ? _jsonDecode(map['metadata'] as String)
          : null,
    );
  }

  static String _jsonEncode(Map<String, String> map) {
    final parts = <String>[];
    map.forEach((key, value) {
      parts.add('$key=$value');
    });
    return parts.join('&');
  }

  static Map<String, String> _jsonDecode(String encoded) {
    final result = <String, String>{};
    for (final pair in encoded.split('&')) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        result[parts[0]] = parts[1];
      }
    }
    return result;
  }

  AppNotification copyWith({
    int? id,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    Map<String, String>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }
}

