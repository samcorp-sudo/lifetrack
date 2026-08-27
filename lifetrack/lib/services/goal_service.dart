import '../core/utilities/date_formatter.dart';
import '../models/goal.dart';
import '../models/goal_contribution.dart';
import '../models/skill.dart';
import '../models/skill_session.dart';
import '../models/task.dart' show TaskPriority;
import '../repositories/goal_repository.dart';
import '../repositories/goal_contribution_repository.dart';
import '../repositories/skill_repository.dart';
import '../repositories/skill_session_repository.dart';

/// Business logic for the GROWTH system: goals, goal contributions, and skills.
///
/// Screens call this, never the repositories directly:
///   GoalsScreen -> GoalService -> *Repository -> SQLite
class GoalService {
  final GoalRepository _goalRepo;
  final GoalContributionRepository _contributionRepo;
  final SkillRepository _skillRepo;
  final SkillSessionRepository _skillSessionRepo;

  GoalService({
    GoalRepository? goalRepo,
    GoalContributionRepository? contributionRepo,
    SkillRepository? skillRepo,
    SkillSessionRepository? skillSessionRepo,
  })  : _goalRepo = goalRepo ?? GoalRepository(),
        _contributionRepo = contributionRepo ?? GoalContributionRepository(),
        _skillRepo = skillRepo ?? SkillRepository(),
        _skillSessionRepo = skillSessionRepo ?? SkillSessionRepository();

  // --- Goals -----------------------------------------------------------------

  Future<List<Goal>> getActiveGoals() async {
    final goals = await _goalRepo.getAll();
    return goals.where((g) => g.status == GoalStatus.active).toList();
  }

  Future<List<Goal>> getGoalsSortedByPriority() async {
    final active = await getActiveGoals();
    active.sort((a, b) => _priorityWeight(b.priority).compareTo(_priorityWeight(a.priority)));
    return active;
  }

  int _priorityWeight(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 3;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.low:
        return 1;
    }
  }

  Future<int> createGoal(Goal goal) => _goalRepo.create(goal);

  Future<void> updateGoal(Goal goal) => _goalRepo.update(goal);

  Future<void> deleteGoal(int id) => _goalRepo.delete(id);

  Future<void> addContribution(GoalContribution contribution) async {
    await _contributionRepo.create(contribution);

    final goal = await _goalRepo.getById(contribution.goalId);
    if (goal == null) return;

    final newAmount = goal.currentAmount + contribution.amount;
    final reachedTarget = newAmount >= goal.targetAmount;

    await _goalRepo.update(goal.copyWith(
      currentAmount: newAmount,
      status: reachedTarget ? GoalStatus.completed : goal.status,
    ));
  }

  Future<List<GoalContribution>> getContributionHistory(int goalId) =>
      _contributionRepo.getByGoal(goalId);

  double? suggestedWeeklyAmount(Goal goal, {DateTime? asOf}) {
    if (goal.deadline == null || goal.remaining <= 0) return null;

    DateTime deadlineDate;
    try {
      deadlineDate = DateFormatter.fromDbDate(goal.deadline!);
    } catch (_) {
      return null;
    }

    final now = asOf ?? DateTime.now();
    final daysRemaining = deadlineDate.difference(now).inDays;
    if (daysRemaining <= 0) return null;

    final weeksRemaining = (daysRemaining / 7).ceil().clamp(1, 1 << 30);
    return goal.remaining / weeksRemaining;
  }

  // --- Skills ------------------------------------------------------------------

  Future<List<Skill>> getSkills() => _skillRepo.getAll();

  Future<int> addSkill(Skill skill) => _skillRepo.create(skill);

  Future<void> updateSkillProgress(Skill skill, double newProgress) async {
    await _skillRepo.update(skill.copyWith(progress: newProgress));
  }

  /// Logs a practice session (Phase 6 §14: "Java practiced 8 sessions").
  /// Call this whenever the user completes a skill-related activity,
  /// e.g. finishing a Focus Timer block tagged with a skill.
  Future<void> logSkillSession(SkillSession session) => _skillSessionRepo.create(session);

  Future<List<SkillSession>> getSkillSessions(int skillId) =>
      _skillSessionRepo.getBySkill(skillId);

  /// Creates a new skill from just a name, starting at 0% progress.
  /// Convenience wrapper around [addSkill] for screens (e.g. the Skills
  /// screen "add skill" sheet) that only collect a name up front.
  ///
  /// NOTE: this was previously an empty stub (`async {}`) that never
  /// touched the repository at all — that's why newly "created" skills
  /// never showed up. Fixed by actually building a Skill and delegating
  /// to addSkill/_skillRepo.create.
  Future<int> createSkill(String name) {
    final skill = Skill(
      name: name,
      progress: 0,
    );
    return addSkill(skill);
  }
}