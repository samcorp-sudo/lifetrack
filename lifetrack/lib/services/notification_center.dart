import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/currency_controller.dart';
import '../core/database/tables/liabilities_table.dart';
import '../core/utilities/date_formatter.dart';
import '../models/notification.dart';
import '../models/task.dart';
import '../repositories/notification_repository.dart';
import 'money_service.dart';
import 'schedule_service.dart';

/// Drives the bell badge and creates in-app reminders.
///
/// - [unreadCount] feeds the badge on the bell.
/// - [generateReminders] looks at tasks, bills (liabilities with a due date)
///   and today's schedule, and writes reminder notifications into the
///   database. Each reminder is created once and never duplicated.
///
/// Reminder rules (change the constants below to tune them):
///   TASKS      due today . due tomorrow . overdue (last 7 days)
///   BILLS      due in 1-3 days . due today . overdue (last 7 days)
///   SCHEDULE   a block starts within the next 30 minutes
class NotificationCenter {
  NotificationCenter._();
  static final NotificationCenter instance = NotificationCenter._();

  // --- Tuning -------------------------------------------------------------

  /// A schedule block triggers a reminder when it starts within this many
  /// minutes (and has not started yet).
  static const int scheduleLeadMinutes = 30;

  /// Tasks get a "due soon" reminder this many days before the due date.
  static const int taskLeadDays = 1;

  /// Bills get a "due soon" reminder this many days before the due date.
  static const int billLeadDays = 3;

  /// Overdue reminders only look back this far, so old forgotten items do
  /// not flood the list.
  static const int overdueLookbackDays = 7;

  /// Safety cap: never create more than this many reminders in one run.
  static const int _maxPerRun = 15;

  static const String _prefsKey = 'generated_reminder_refs';
  static const int _maxStoredRefs = 400;

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final NotificationRepository _repository = NotificationRepository();
  final ScheduleService _schedule = ScheduleService();
  final MoneyService _money = MoneyService();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  bool _generating = false;

  Future<void> refreshUnread() async {
    unreadCount.value = await _repository.getUnreadCount();
  }

  Future<void> generateReminders() async {
    if (_generating) return;
    _generating = true;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayKey = DateFormatter.toDbDate(now);
      final nowMinutes = now.hour * 60 + now.minute;

      final prefs = await SharedPreferences.getInstance();
      final refs = List<String>.from(prefs.getStringList(_prefsKey) ?? []);
      final newRefs = <String>[];

      Future<void> create({
        required String ref,
        required String title,
        required String body,
        required NotificationType type,
      }) async {
        if (newRefs.length >= _maxPerRun) return;
        if (refs.contains(ref) || newRefs.contains(ref)) return;
        await _repository.addNotification(AppNotification(
          title: title,
          body: body,
          type: type,
          timestamp: DateTime.now(),
          metadata: {'ref': ref},
        ));
        newRefs.add(ref);
      }

      // Each section is isolated so one failing source cannot block the rest.

      // --- Schedule blocks starting soon ----------------------------------
      try {
        final items = await _schedule.getScheduleForDate(todayKey);
        for (final item in items) {
          if (item.isDone || item.id == null) continue;
          final minutesUntil = _minutesOfDay(item.startTime) - nowMinutes;
          if (minutesUntil < 0 || minutesUntil > scheduleLeadMinutes) continue;

          await create(
            ref: 'schedule-${item.id}-$todayKey',
            title: 'Starting soon: ${item.title}',
            body: minutesUntil == 0
                ? 'Starts now (${item.startTime} - ${item.endTime})'
                : 'In $minutesUntil min (${item.startTime} - ${item.endTime})',
            type: NotificationType.scheduleReminder,
          );
        }
      } catch (e) {
        debugPrint('Schedule reminders failed: $e');
      }

      // --- Tasks: due today / due soon / overdue ---------------------------
      try {
        final tasks = await _schedule.getAllTasks();
        for (final task in tasks) {
          final id = task.id;
          if (id == null || task.status == TaskStatus.done) continue;

          final due = _parseDay(task.dueDate);
          if (due == null) continue;
          final days = due.difference(today).inDays;
          final dueKey = DateFormatter.toDbDate(due);

          if (days == 0) {
            await create(
              ref: 'task-today-$id-$dueKey',
              title: 'Task due today',
              body: task.title,
              type: NotificationType.taskReminder,
            );
          } else if (days > 0 && days <= taskLeadDays) {
            await create(
              ref: 'task-soon-$id-$dueKey',
              title: 'Task due ${_inDays(days)}',
              body: task.title,
              type: NotificationType.taskReminder,
            );
          } else if (days < 0 && days >= -overdueLookbackDays) {
            await create(
              ref: 'task-overdue-$id-$dueKey',
              title: 'Task overdue',
              body: '${task.title} was due ${_label(due)}',
              type: NotificationType.taskReminder,
            );
          }
        }
      } catch (e) {
        debugPrint('Task reminders failed: $e');
      }

      // --- Bills (liabilities with a due date) -----------------------------
      try {
        final liabilities = await _money.getLiabilities();
        for (final liability in liabilities) {
          final map = liability.toMap();
          final due = _parseDay(map[LiabilitiesTable.colDueDate] as String?);
          if (due == null) continue;

          final name = (map[LiabilitiesTable.colName] as String?) ?? 'Bill';
          final amount =
              (map[LiabilitiesTable.colAmount] as num?)?.toDouble() ?? 0;
          final id = map['id'] ?? name;
          final days = due.difference(today).inDays;
          final dueKey = DateFormatter.toDbDate(due);
          final detail = '$name \u2022 ${CurrencyController.format(amount)}';

          if (days == 0) {
            await create(
              ref: 'bill-today-$id-$dueKey',
              title: 'Bill due today',
              body: detail,
              type: NotificationType.general,
            );
          } else if (days > 0 && days <= billLeadDays) {
            await create(
              ref: 'bill-soon-$id-$dueKey',
              title: 'Bill due ${_inDays(days)}',
              body: detail,
              type: NotificationType.general,
            );
          } else if (days < 0 && days >= -overdueLookbackDays) {
            await create(
              ref: 'bill-overdue-$id-$dueKey',
              title: 'Bill overdue',
              body: '$detail was due ${_label(due)}',
              type: NotificationType.general,
            );
          }
        }
      } catch (e) {
        debugPrint('Bill reminders failed: $e');
      }

      if (newRefs.isNotEmpty) {
        refs.addAll(newRefs);
        final trimmed = refs.length > _maxStoredRefs
            ? refs.sublist(refs.length - _maxStoredRefs)
            : refs;
        await prefs.setStringList(_prefsKey, trimmed);
      }
    } catch (e, st) {
      debugPrint('generateReminders failed: $e\n$st');
    } finally {
      _generating = false;
      await refreshUnread();
    }
  }

  // --- Helpers --------------------------------------------------------------

  int _minutesOfDay(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// Reads the date part (yyyy-MM-dd) of a stored date string.
  DateTime? _parseDay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final text = raw.trim();
    final parsed = DateTime.tryParse(text.length >= 10 ? text.substring(0, 10) : text);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String _inDays(int days) => days == 1 ? 'tomorrow' : 'in $days days';

  String _label(DateTime d) => '${_months[d.month - 1]} ${d.day}';
}
