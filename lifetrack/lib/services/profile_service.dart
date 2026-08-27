import '../models/user_profile.dart';
import 'money_service.dart';
import 'goal_service.dart';
import 'analytics_service.dart';

/// Business logic for the Profile screen: the local display profile plus
/// a few lifetime stats pulled from services that already exist —
/// no new table, since none of this is itself trackable data.
class ProfileService {
  final MoneyService _moneyService;
  final GoalService _goalService;
  final AnalyticsService _analyticsService;

  ProfileService({
    MoneyService? moneyService,
    GoalService? goalService,
    AnalyticsService? analyticsService,
  })  : _moneyService = moneyService ?? MoneyService(),
        _goalService = goalService ?? GoalService(),
        _analyticsService = analyticsService ?? AnalyticsService();

  Future<UserProfile> getProfile() => UserProfile.load();

  Future<void> updateProfile({required String displayName, String? avatarEmoji}) {
    return UserProfile(displayName: displayName, avatarEmoji: avatarEmoji).save();
  }

  Future<ProfileStats> getStats() async {
    final netWorth = await _moneyService.getNetWorth();
    final goals = await _goalService.getActiveGoals();
    final growth = await _analyticsService.getGrowthReport();

    return ProfileStats(
      netWorth: netWorth,
      activeGoalsCount: goals.length,
      tasksCompleted: growth.tasksCompleted,
      tasksTotal: growth.tasksTotal,
    );
  }
}

class ProfileStats {
  final double netWorth;
  final int activeGoalsCount;
  final int tasksCompleted;
  final int tasksTotal;

  const ProfileStats({
    required this.netWorth,
    required this.activeGoalsCount,
    required this.tasksCompleted,
    required this.tasksTotal,
  });
}