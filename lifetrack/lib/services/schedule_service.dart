import '../core/constants/app_constants.dart';
import '../core/utilities/date_formatter.dart';
import '../models/schedule.dart';
import '../models/task.dart';
import '../repositories/schedule_repository.dart';
import '../repositories/task_repository.dart';

/// Business logic for the TIME SYSTEM: the calendar (schedule) and tasks.
///
/// Screens call this, never the repositories directly:
///   ScheduleScreen -> ScheduleService -> *Repository -> SQLite
class ScheduleService {
  final ScheduleRepository _scheduleRepo;
  final TaskRepository _taskRepo;

  ScheduleService({
    ScheduleRepository? scheduleRepo,
    TaskRepository? taskRepo,
  })  : _scheduleRepo = scheduleRepo ?? ScheduleRepository(),
        _taskRepo = taskRepo ?? TaskRepository();

  // --- Schedule / Calendar views (Phase 4 §1-2) ------------------------------

  Future<List<Schedule>> getScheduleForDate(String date) =>
      _scheduleRepo.getByDate(date);

  /// 7 days starting from [weekStart] ('yyyy-MM-dd').
  Future<List<Schedule>> getScheduleForWeek(String weekStart) async {
    final start = DateFormatter.fromDbDate(weekStart);
    final end = start.add(const Duration(days: 6));
    return _scheduleRepo.getByDateRange(weekStart, DateFormatter.toDbDate(end));
  }

  Future<List<Schedule>> getScheduleForMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0); // last day of month
    return _scheduleRepo.getByDateRange(
      DateFormatter.toDbDate(start),
      DateFormatter.toDbDate(end),
    );
  }

  Future<int> addScheduleItem(Schedule item) => _scheduleRepo.create(item);

  Future<void> updateScheduleItem(Schedule item) => _scheduleRepo.update(item);

  Future<void> deleteScheduleItem(int id) => _scheduleRepo.delete(id);

  /// The next upcoming block on today's schedule, given the current time
  /// as 'HH:mm' (e.g. Dashboard "⏰ Next: Coding — 2:00 PM").
  Future<Schedule?> getNextItem(String date, String currentTime) async {
    final items = await _scheduleRepo.getAll();
    final currentKey = '$date $currentTime';

    for (final item in items) {
      if ('${item.date} ${item.startTime}'.compareTo(currentKey) >= 0) {
        return item;
      }
    }
    return null;
  }

  // --- Free-time-block detection (Phase 4 §7-8) -------------------------------

  /// Gaps in [date]'s schedule, inside the waking-hours window
  /// (AppConstants.dayStartTime..dayEndTime). This is what makes the app
  /// aware that e.g. Saturday farming (8AM-4PM) is already occupied, so
  /// it won't suggest coding during that block.
  Future<List<FreeTimeBlock>> getFreeTimeBlocks(String date) async {
    final items =
        await _scheduleRepo.getByDate(date); // already sorted by start_time
    final blocks = <FreeTimeBlock>[];

    String cursor = AppConstants.dayStartTime;
    for (final item in items) {
      if (item.startTime.compareTo(cursor) > 0) {
        blocks
            .add(FreeTimeBlock(date: date, start: cursor, end: item.startTime));
      }
      if (item.endTime.compareTo(cursor) > 0) {
        cursor = item.endTime;
      }
    }
    if (cursor.compareTo(AppConstants.dayEndTime) < 0) {
      blocks.add(FreeTimeBlock(
          date: date, start: cursor, end: AppConstants.dayEndTime));
    }

    return blocks.where((b) => b.minutes >= 10).toList();
  }

  /// True if [time] ('HH:mm') on [date] falls inside an existing schedule
  /// block — used to avoid recommending an activity during, say, farming time.
  Future<bool> isBusyAt(String date, String time) async {
    final items = await _scheduleRepo.getByDate(date);
    return items.any((i) =>
        time.compareTo(i.startTime) >= 0 && time.compareTo(i.endTime) < 0);
  }

  // --- Tasks (Phase 4 §4) ------------------------------------------------------

  Future<List<Task>> getTasksForDate(String date) => _taskRepo.getByDate(date);

  Future<List<Task>> getAllTasks() => _taskRepo.getAll();

  Future<int> addTask(Task task) => _taskRepo.create(task);

  Future<void> markTaskInProgress(Task task) async {
    await _taskRepo.update(task.copyWith(status: TaskStatus.inProgress));
  }

  Future<void> markTaskDone(Task task) async {
    await _taskRepo.update(task.copyWith(status: TaskStatus.done));
  }

  /// e.g. Dashboard "🎯 Today's progress: 3/5 tasks".
  Future<String> getTodayProgressLabel(String date) async {
    final tasks = await _taskRepo.getByDate(date);
    final done = tasks.where((t) => t.status == TaskStatus.done).length;
    return '$done/${tasks.length}';
  }
}

/// A gap of unscheduled time on a given day (Phase 4 §8).
class FreeTimeBlock {
  final String date;
  final String start;
  final String end;

  const FreeTimeBlock(
      {required this.date, required this.start, required this.end});

  int get minutes {
    int toMinutes(String hhmm) {
      final parts = hhmm.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    return toMinutes(end) - toMinutes(start);
  }
}
