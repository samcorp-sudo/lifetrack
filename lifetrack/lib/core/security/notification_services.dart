import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import '../../models/notification.dart';
import '../../repositories/notification_repository.dart';

class NotificationService {
  static const _channelId = 'lifetrack_reminders';
  static const _channelName = 'LifeTrack reminders';
  static const _channelDescription = 'Schedule and task reminders.';

  static final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final NotificationRepository _repository = NotificationRepository();

  static Future<void>? _initialization;
  static int _nextNotificationId = 1;

  static Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    developer.log('Initializing Notification Service',
        name: 'LifeTrack.notifications');

    // Initialize timezone
    timezone_data.initializeTimeZones();

    // Initialize local notifications
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings =
        InitializationSettings(android: android, iOS: darwin, macOS: darwin);

    await _localPlugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    // Request permissions
    await _requestPermissions();

    // Initialize Firebase Cloud Messaging
    await _initializeFCM();

    developer.log('Notification Service initialized',
        name: 'LifeTrack.notifications');
  }

  static Future<void> _requestPermissions() async {
    await _localPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _localPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _localPlugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> _initializeFCM() async {
    try {
      // Request user permission for notifications
      await _fcm.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleFCMMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundFCMMessage);

      // Handle notification tap when app is terminated
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleFCMMessage(initialMessage);
      }

      // Get FCM token
      final token = await _fcm.getToken();
      developer.log('FCM Token: $token', name: 'LifeTrack.notifications');
    } catch (e) {
      developer.log('FCM initialization error: $e',
          name: 'LifeTrack.notifications', error: e);
    }
  }

  static Future<void> _handleFCMMessage(RemoteMessage message) async {
    developer.log(
      'Received FCM message: ${message.messageId}',
      name: 'LifeTrack.notifications',
    );

    // Store notification in database
    final notification = AppNotification(
      title: message.notification?.title ?? 'Notification',
      body: message.notification?.body ?? '',
      type: _parseNotificationType(message.data['type'] ?? 'general'),
      timestamp: DateTime.now(),
      isRead: false,
      metadata:
          message.data.isEmpty ? null : message.data.cast<String, String>(),
    );

    await _repository.addNotification(notification);

    // Show local notification
    if (message.notification != null) {
      await _showLocalNotification(
        title: message.notification!.title ?? 'LifeTrack',
        body: message.notification!.body ?? '',
      );
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _handleBackgroundFCMMessage(RemoteMessage message) async {
    await _handleFCMMessage(message);
  }

  static void _handleNotificationResponse(
    NotificationResponse response,
  ) {
    developer.log('Notification tapped: ${response.payload}',
        name: 'LifeTrack.notifications');
  }

  static NotificationType _parseNotificationType(String type) {
    switch (type) {
      case 'task_reminder':
        return NotificationType.taskReminder;
      case 'schedule_reminder':
        return NotificationType.scheduleReminder;
      case 'free_time_alert':
        return NotificationType.freeTimeAlert;
      case 'goal_progress':
        return NotificationType.goalProgress;
      case 'achievement':
        return NotificationType.achievement;
      default:
        return NotificationType.general;
    }
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
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

    await _localPlugin.show(
      id: _nextNotificationId++,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  static Future<void> scheduleActivityReminder({
    required String title,
    required DateTime activityStart,
    Duration leadTime = const Duration(minutes: 15),
  }) async {
    await _schedule(
      title: title,
      body: 'Starting soon',
      scheduledAt: activityStart.subtract(leadTime),
      type: NotificationType.scheduleReminder,
    );
  }

  static Future<void> scheduleTaskDueReminder({
    required String taskTitle,
    required DateTime dueDate,
  }) async {
    await _schedule(
      title: 'Task due',
      body: taskTitle,
      scheduledAt: dueDate,
      type: NotificationType.taskReminder,
    );
  }

  static Future<void> scheduleFreeTimeReminder({
    required DateTime freeTimeStart,
  }) async {
    await _schedule(
      title: 'Free time available',
      body: 'You have an open block in your schedule.',
      scheduledAt: freeTimeStart,
      type: NotificationType.freeTimeAlert,
    );
  }

  static Future<void> _schedule({
    required String title,
    required String body,
    required DateTime scheduledAt,
    required NotificationType type,
  }) async {
    await initialize();
    if (!scheduledAt.isAfter(DateTime.now())) return;

    // Store in database
    final notification = AppNotification(
      title: title,
      body: body,
      type: type,
      timestamp: scheduledAt,
      isRead: false,
    );
    await _repository.addNotification(notification);

    // Schedule local notification
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

    await _localPlugin.zonedSchedule(
      id: _nextNotificationId++,
      title: title,
      body: body,
      scheduledDate: timezone.TZDateTime.from(scheduledAt, timezone.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelAll() async {
    await initialize();
    await _localPlugin.cancelAll();
  }

  /// Get FCM token for testing
  static Future<String?> getFCMToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      developer.log('Error getting FCM token: $e',
          name: 'LifeTrack.notifications', error: e);
      return null;
    }
  }
}
