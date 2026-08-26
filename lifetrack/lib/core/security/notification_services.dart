import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class NotificationService {
  static const _channelId = 'lifetrack_reminders';
  static const _channelName = 'LifeTrack reminders';
  static const _channelDescription = 'Schedule and task reminders.';
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static Future<void>? _initialization;
  static int _nextNotificationId = 1;

  static Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    timezone_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: android, iOS: darwin, macOS: darwin);
    await _plugin.initialize(settings: settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleActivityReminder({
    required String title,
    required DateTime activityStart,
    Duration leadTime = const Duration(minutes: 15),
  }) async {
    await _schedule(
      title: title,
      body: 'Starting soon',
      scheduledAt: activityStart.subtract(leadTime),
    );
  }

  Future<void> scheduleTaskDueReminder({
    required String taskTitle,
    required DateTime dueDate,
  }) async {
    await _schedule(
      title: 'Task due',
      body: taskTitle,
      scheduledAt: dueDate,
    );
  }

  Future<void> scheduleFreeTimeReminder({
    required DateTime freeTimeStart,
  }) async {
    await _schedule(
      title: 'Free time available',
      body: 'You have an open block in your schedule.',
      scheduledAt: freeTimeStart,
    );
  }

  Future<void> _schedule({
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    await initialize();
    if (!scheduledAt.isAfter(DateTime.now())) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
    await _plugin.zonedSchedule(
      id: _nextNotificationId++,
      title: title,
      body: body,
      scheduledDate: timezone.TZDateTime.from(scheduledAt, timezone.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }
}
