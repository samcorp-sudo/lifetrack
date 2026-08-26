import '../core/utilities/date_formatter.dart';
import '../models/goal.dart';
import '../models/schedule.dart';
import '../models/task.dart';
import 'money_service.dart';
import 'schedule_service.dart';
import 'goal_service.dart';

/// Business logic for Screen 1 — Main Dashboard. Composes MoneyService,
/// ScheduleService, and GoalService rather than owning any data itself;
/// this is where "10 seconds to understand your life" is assembled.
class DashboardService {
  final MoneyService _moneyService;
  final ScheduleService _scheduleService;
  final GoalService _goalService;

  DashboardService({
    MoneyService? moneyService,
    ScheduleService? scheduleService,
    GoalService? goalService,
  })  : _moneyService = moneyService ?? MoneyService(),
        _scheduleService = scheduleService ?? ScheduleService(),
        _goalService = goalService ?? GoalService();

  // --- Greeting (§2) -----------------------------------------------------------

  String getGreeting({DateTime? asOf}) {
    final hour = (asOf ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// A contextual line under the greeting: farming today takes priority
  /// over a generic free-time callout, since it's the more specific,
  /// more actionable piece of information (§2).
  Future<String?> getGreetingContext(String date) async {
    final scheduleToday = await _scheduleService.getScheduleForDate(date);
    final isFarmingDay = scheduleToday.any((s) => s.category.toLowerCase() == 'farming');
    if (isFarmingDay) return 'You have farming scheduled today.';

    final freeBlocks = await _scheduleService.getFreeTimeBlocks(date);
    final totalFreeMinutes = freeBlocks.fold<int>(0, (sum, b) => sum + b.minutes);
    if (totalFreeMinutes >= 60) {
      final hours = totalFreeMinutes / 60;
      return 'You have ${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)} hours of free time today.';
    }

    return null;
  }

  // --- Next activity (§3) -------------------------------------------------------

  Future<Schedule?> getNextActivity(String date, String currentTime) =>
      _scheduleService.getNextItem(date, currentTime);

  // --- Today's tasks (§4) --------------------------------------------------------

  Future<List<Task>> getTodayTasks(String date) => _scheduleService.getTasksForDate(date);

  Future<String> getTodayTaskProgress(String date) =>
      _scheduleService.getTodayProgressLabel(date);

  // --- Financial snapshot (§5) ----------------------------------------------------

  Future<FinancialSnapshot> getFinancialSnapshot({DateTime? asOf}) async {
    final now = asOf ?? DateTime.now();
    final balance = await _moneyService.getTotalBalance();
    final monthly = await _moneyService.getMonthlySummary(now.year, now.month);

    return FinancialSnapshot(
      balance: balance,
      income: monthly['income'] ?? 0,
      expenses: monthly['expenses'] ?? 0,
      savings: monthly['saved'] ?? 0,
    );
  }

  // --- Net worth snapshot (§6) ----------------------------------------------------

  Future<NetWorthDashboardSnapshot> getNetWorthSnapshot({DateTime? asOf}) async {
    final now = asOf ?? DateTime.now();
    final assets = await _moneyService.getTotalAssets();
    final liabilities = await _moneyService.getTotalLiabilities();
    final netWorth = assets - liabilities;

    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    final previousMonthNetWorth = await _moneyService.getNetWorthAtEndOfMonth(
      prevMonthDate.year,
      prevMonthDate.month,
    );

    return NetWorthDashboardSnapshot(
      totalAssets: assets,
      totalLiabilities: liabilities,
      netWorth: netWorth,
      previousMonthNetWorth: previousMonthNetWorth,
    );
  }

  // --- Top goal (§7) --------------------------------------------------------------

  Future<Goal?> getTopGoal() async {
    final sorted = await _goalService.getGoalsSortedByPriority();
    return sorted.isEmpty ? null : sorted.first;
  }

  // --- One-shot fetch for the whole dashboard --------------------------------------

  /// Gathers everything the Dashboard screen needs in one call, so the
  /// UI isn't juggling five separate futures.
  Future<DashboardSnapshot> getDashboardSnapshot({DateTime? asOf}) async {
    final now = asOf ?? DateTime.now();
    final date = DateFormatter.toDbDate(now);
    final time = DateFormatter.nowAsDbTime();

    return DashboardSnapshot(
      greeting: getGreeting(asOf: now),
      greetingContext: await getGreetingContext(date),
      nextActivity: await getNextActivity(date, time),
      todayTasks: await getTodayTasks(date),
      todayTaskProgress: await getTodayTaskProgress(date),
      financial: await getFinancialSnapshot(asOf: now),
      netWorth: await getNetWorthSnapshot(asOf: now),
      topGoal: await getTopGoal(),
    );
  }
}

class FinancialSnapshot {
  final double balance;
  final double income;
  final double expenses;
  final double savings;

  const FinancialSnapshot({
    required this.balance,
    required this.income,
    required this.expenses,
    required this.savings,
  });
}

class NetWorthDashboardSnapshot {
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final double? previousMonthNetWorth;

  const NetWorthDashboardSnapshot({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    this.previousMonthNetWorth,
  });

  double? get changeFromPreviousMonth =>
      previousMonthNetWorth == null ? null : netWorth - previousMonthNetWorth!;
}

/// Everything Screen 1 needs, gathered in one call.
class DashboardSnapshot {
  final String greeting;
  final String? greetingContext;
  final Schedule? nextActivity;
  final List<Task> todayTasks;
  final String todayTaskProgress;
  final FinancialSnapshot financial;
  final NetWorthDashboardSnapshot netWorth;
  final Goal? topGoal;

  const DashboardSnapshot({
    required this.greeting,
    this.greetingContext,
    this.nextActivity,
    required this.todayTasks,
    required this.todayTaskProgress,
    required this.financial,
    required this.netWorth,
    this.topGoal,
  });
}