import '../core/utilities/date_formatter.dart';
import '../models/transaction.dart';
import '../models/schedule.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/schedule_repository.dart';
import '../repositories/goal_repository.dart';
import '../repositories/goal_contribution_repository.dart';
import '../repositories/task_repository.dart';
import '../repositories/skill_repository.dart';
import '../repositories/skill_session_repository.dart';
import '../models/goal.dart';
import '../models/task.dart';

/// Business logic for Screen 8 — Analytics (Money / Time / Growth) plus
/// the Weekly Review and rule-based Smart Insights (Phase 6).
/// Reads across every other repository and aggregates — it doesn't own
/// any table itself.
class AnalyticsService {
  final TransactionRepository _transactionRepo;
  final ScheduleRepository _scheduleRepo;
  final GoalRepository _goalRepo;
  final GoalContributionRepository _contributionRepo;
  final TaskRepository _taskRepo;
  final SkillRepository _skillRepo;
  final SkillSessionRepository _skillSessionRepo;

  AnalyticsService({
    TransactionRepository? transactionRepo,
    ScheduleRepository? scheduleRepo,
    GoalRepository? goalRepo,
    GoalContributionRepository? contributionRepo,
    TaskRepository? taskRepo,
    SkillRepository? skillRepo,
    SkillSessionRepository? skillSessionRepo,
  })  : _transactionRepo = transactionRepo ?? TransactionRepository(),
        _scheduleRepo = scheduleRepo ?? ScheduleRepository(),
        _goalRepo = goalRepo ?? GoalRepository(),
        _contributionRepo = contributionRepo ?? GoalContributionRepository(),
        _taskRepo = taskRepo ?? TaskRepository(),
        _skillRepo = skillRepo ?? SkillRepository(),
        _skillSessionRepo = skillSessionRepo ?? SkillSessionRepository();

  // --- Money analytics (§10-11) ------------------------------------------------

  Future<Map<String, double>> getMoneyReport(List<Transaction> transactions) async {
    double income = 0;
    double expenses = 0;
    for (final t in transactions) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expenses += t.amount;
      }
    }
    return {'income': income, 'expenses': expenses, 'saved': income - expenses};
  }

  /// "Spending Breakdown" (§10): expense total per category for one month.
  Future<Map<String, double>> getSpendingBreakdown(int year, int month) async {
    final all = await _transactionRepo.getAll();
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final expenses = all.where(
          (t) => t.date.startsWith(prefix) && t.type == TransactionType.expense,
    );

    final Map<String, double> byCategory = {};
    for (final t in expenses) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
    }
    return byCategory;
  }

  /// "Income vs Expenses" bar-chart data (§11): the last [monthsBack]
  /// months ending at [year]-[month], oldest first.
  Future<List<MonthlyMoneyPoint>> getIncomeVsExpensesByMonth(
      int year,
      int month, {
        int monthsBack = 6,
      }) async {
    final all = await _transactionRepo.getAll();
    final points = <MonthlyMoneyPoint>[];

    for (int i = monthsBack - 1; i >= 0; i--) {
      final target = DateTime(year, month - i, 1);
      final prefix = '${target.year}-${target.month.toString().padLeft(2, '0')}';
      final inMonth = all.where((t) => t.date.startsWith(prefix));

      double income = 0;
      double expenses = 0;
      for (final t in inMonth) {
        if (t.type == TransactionType.income) {
          income += t.amount;
        } else {
          expenses += t.amount;
        }
      }
      points.add(MonthlyMoneyPoint(year: target.year, month: target.month, income: income, expenses: expenses));
    }

    return points;
  }

  /// Daily income/expense totals for the last [daysBack] days, oldest
  /// first, today included. Powers the Analytics screen's weekly trend
  /// card — shape matches what `AnalyticsScreen._load()` expects:
  /// `{ 'date': DateTime, 'income': double, 'expenses': double }`.
  Future<List<Map<String, dynamic>>> getDailyTotals(int daysBack) async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final start = startOfToday.subtract(Duration(days: daysBack - 1));
    return getDailyTotalsForRange(start, startOfToday);
  }

  /// Daily income/expense totals for each day in [start, end] inclusive,
  /// oldest first. Same per-day aggregation as [getDailyTotals] used to do
  /// directly, but over an explicit range instead of "last N days ending
  /// today" — powers the Analytics screen's week-by-week navigation.
  /// Shape matches `AnalyticsScreen`'s daily trend card:
  /// `{ 'date': DateTime, 'income': double, 'expenses': double }`.
  Future<List<Map<String, dynamic>>> getDailyTotalsForRange(
      DateTime start, DateTime end) async {
    final all = await _transactionRepo.getAll();
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    final result = <Map<String, dynamic>>[];

    for (var day = startDate;
        !day.isAfter(endDate);
        day = day.add(const Duration(days: 1))) {
      final dayStr = DateFormatter.toDbDate(day);
      final inDay = all.where((t) => t.date.startsWith(dayStr));

      double income = 0;
      double expenses = 0;
      for (final t in inDay) {
        if (t.type == TransactionType.income) {
          income += t.amount;
        } else {
          expenses += t.amount;
        }
      }

      result.add({'date': day, 'income': income, 'expenses': expenses});
    }

    return result;
  }

  /// Monthly income/expense/saved totals for the last [monthsBack] months,
  /// oldest first, current month included. Reuses the existing
  /// [getIncomeVsExpensesByMonth] aggregation instead of duplicating it.
  /// Shape matches what `AnalyticsScreen._load()` expects:
  /// `{ 'month': DateTime, 'income': double, 'expenses': double, 'saved': double }`.
  Future<List<Map<String, dynamic>>> getMonthlyTotals(int monthsBack) async {
    final now = DateTime.now();
    final points = await getIncomeVsExpensesByMonth(
      now.year,
      now.month,
      monthsBack: monthsBack,
    );

    return points
        .map((p) => {
              'month': DateTime(p.year, p.month, 1),
              'income': p.income,
              'expenses': p.expenses,
              'saved': p.income - p.expenses,
            })
        .toList();
  }

  // --- Time analytics (§12-13) -------------------------------------------------

  Map<String, double> getTimeReportByCategory(List<Schedule> items) {
    final Map<String, double> hoursByCategory = {};
    for (final item in items) {
      final hours = (_toMinutes(item.endTime) - _toMinutes(item.startTime)) / 60.0;
      hoursByCategory[item.category] = (hoursByCategory[item.category] ?? 0) + hours;
    }
    return hoursByCategory;
  }

  Future<Map<String, double>> getWeeklyTimeReport(String weekStart) async {
    final start = DateFormatter.fromDbDate(weekStart);
    final end = start.add(const Duration(days: 6));
    final items = await _scheduleRepo.getByDateRange(weekStart, DateFormatter.toDbDate(end));
    return getTimeReportByCategory(items);
  }

  // --- Growth analytics (§14) --------------------------------------------------

  /// { tasksCompleted, tasksTotal, goalsProgressing }, plus per-skill
  /// session counts, e.g. "Java 8 sessions" (§14).
  Future<GrowthReport> getGrowthReport() async {
    final goals = await _goalRepo.getAll();
    final tasks = await _taskRepo.getAll();
    final skills = await _skillRepo.getAll();
    final sessions = await _skillSessionRepo.getAll();

    final sessionCountBySkillId = <int, int>{};
    for (final s in sessions) {
      sessionCountBySkillId[s.skillId] = (sessionCountBySkillId[s.skillId] ?? 0) + 1;
    }

    final skillSessionCounts = {
      for (final skill in skills)
        if (skill.id != null) skill.name: sessionCountBySkillId[skill.id] ?? 0,
    };

    return GrowthReport(
      tasksCompleted: tasks.where((t) => t.status.value == 'Done').length,
      tasksTotal: tasks.length,
      goalsProgressing: goals.where((g) => g.status.value == 'Active' && g.currentAmount > 0).length,
      skillSessionCounts: skillSessionCounts,
    );
  }

  // --- Weekly Review (§15) -------------------------------------------------------

  /// Combines Money, Time, Goals, Tasks, and Skills for one 7-day window
  /// starting [weekStart] ('yyyy-MM-dd').
  Future<WeeklyReview> getWeeklyReview(String weekStart) async {
    final start = DateFormatter.fromDbDate(weekStart);
    final endDate = start.add(const Duration(days: 6));
    final weekEnd = DateFormatter.toDbDate(endDate);

    final transactions = await _transactionRepo.getByDateRange(weekStart, weekEnd);
    final money = await getMoneyReport(transactions);

    final scheduleItems = await _scheduleRepo.getByDateRange(weekStart, weekEnd);
    final time = getTimeReportByCategory(scheduleItems);

    final contributions = await _contributionRepo.getByDateRange(weekStart, weekEnd);
    final goalsImproved = contributions.map((c) => c.goalId).toSet().length;

    // NOTE: tasks have no "completed_at" field, only due_date — this counts
    // tasks marked Done whose due_date falls in the week, which is an
    // approximation, not a true "completed this week" count.
    final tasks = await _taskRepo.getAll();
    final tasksCompleted = tasks.where((t) {
      if (t.status.value != 'Done' || t.dueDate == null) return false;
      return t.dueDate!.compareTo(weekStart) >= 0 && t.dueDate!.compareTo(weekEnd) <= 0;
    }).length;

    final sessions = await _skillSessionRepo.getByDateRange(weekStart, weekEnd);
    final skills = await _skillRepo.getAll();
    final skillNameById = {for (final s in skills) if (s.id != null) s.id!: s.name};
    final skillSessionCounts = <String, int>{};
    for (final s in sessions) {
      final name = skillNameById[s.skillId] ?? 'Unknown';
      skillSessionCounts[name] = (skillSessionCounts[name] ?? 0) + 1;
    }

    return WeeklyReview(
      weekStart: weekStart,
      weekEnd: weekEnd,
      income: money['income'] ?? 0,
      expenses: money['expenses'] ?? 0,
      saved: money['saved'] ?? 0,
      hoursByCategory: time,
      goalsImproved: goalsImproved,
      tasksCompleted: tasksCompleted,
      skillSessionCounts: skillSessionCounts,
    );
  }

  // --- Smart Insights (§16) — rule-based, no AI ---------------------------------

  /// Simple offline, rule-based observations. Each check is independent;
  /// any subset may fire.
  Future<List<Insight>> getSmartInsights({DateTime? asOf}) async {
    final now = asOf ?? DateTime.now();
    final insights = <Insight>[];

    final thisMonth = await getMoneyReportForMonth(now.year, now.month);
    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    final prevMonth = await getMoneyReportForMonth(prevMonthDate.year, prevMonthDate.month);

    if (thisMonth['expenses']! > prevMonth['expenses']!) {
      insights.add(const Insight(
        icon: '⚠️',
        message: 'Your expenses increased compared with last month.',
        type: InsightType.warning,
      ));
    }

    if (thisMonth['saved']! > prevMonth['saved']!) {
      insights.add(const Insight(
        icon: '📈',
        message: 'You saved more this month.',
        type: InsightType.positive,
      ));
    }

    // Approximation: "repeatedly missed" would need a history of due-date
    // changes, which isn't tracked. This flags tasks overdue instead.
    final tasks = await _taskRepo.getAll();
    final today = DateFormatter.toDbDate(now);
    final overdue = tasks.where(
          (t) => t.status.value != 'Done' && t.dueDate != null && t.dueDate!.compareTo(today) < 0,
    );
    if (overdue.isNotEmpty) {
      insights.add(Insight(
        icon: '📝',
        message: overdue.length == 1
            ? 'You have an overdue task: "${overdue.first.title}".'
            : 'You have ${overdue.length} overdue tasks.',
        type: InsightType.warning,
      ));
    }

    final todayDate = DateFormatter.toDbDate(now);
    final scheduleToday = await _scheduleRepo.getByDate(todayDate);
    final busyMinutes = scheduleToday.fold<int>(
      0,
          (sum, item) => sum + (_toMinutes(item.endTime) - _toMinutes(item.startTime)),
    );
    const wakingMinutes = 16 * 60; // rough waking-hours estimate
    final freeMinutes = (wakingMinutes - busyMinutes).clamp(0, wakingMinutes);
    if (freeMinutes >= 60) {
      insights.add(Insight(
        icon: '⚡',
        message: 'You have ${(freeMinutes / 60).toStringAsFixed(freeMinutes % 60 == 0 ? 0 : 1)} hours available today.',
        type: InsightType.info,
      ));
    }

    return insights;
  }

  Future<Map<String, double>> getMoneyReportForMonth(int year, int month) async {
    final all = await _transactionRepo.getAll();
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final inMonth = all.where((t) => t.date.startsWith(prefix)).toList();
    return getMoneyReport(inMonth);
  }

  int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return h * 60 + m;
  }
}

/// One bar in the "Income vs Expenses" chart (§11).
class MonthlyMoneyPoint {
  final int year;
  final int month;
  final double income;
  final double expenses;

  const MonthlyMoneyPoint({
    required this.year,
    required this.month,
    required this.income,
    required this.expenses,
  });
}

/// Growth Analytics screen data (§14).
class GrowthReport {
  final int tasksCompleted;
  final int tasksTotal;
  final int goalsProgressing;
  final Map<String, int> skillSessionCounts;

  const GrowthReport({
    required this.tasksCompleted,
    required this.tasksTotal,
    required this.goalsProgressing,
    required this.skillSessionCounts,
  });
}

/// Weekly Review data (§15).
class WeeklyReview {
  final String weekStart;
  final String weekEnd;
  final double income;
  final double expenses;
  final double saved;
  final Map<String, double> hoursByCategory;
  final int goalsImproved;
  final int tasksCompleted;
  final Map<String, int> skillSessionCounts;

  const WeeklyReview({
    required this.weekStart,
    required this.weekEnd,
    required this.income,
    required this.expenses,
    required this.saved,
    required this.hoursByCategory,
    required this.goalsImproved,
    required this.tasksCompleted,
    required this.skillSessionCounts,
  });
}

enum InsightType { warning, positive, info }

/// One rule-based observation (§16), e.g. "⚠️ Your expenses increased...".
class Insight {
  final String icon;
  final String message;
  final InsightType type;

  const Insight({required this.icon, required this.message, required this.type});
}