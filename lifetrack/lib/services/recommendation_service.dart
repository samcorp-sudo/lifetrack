
import '../core/utilities/date_formatter.dart';
import '../models/task.dart';
import '../models/goal.dart';
import '../models/skill.dart';
import '../models/recommendation_history.dart';
import '../repositories/task_repository.dart';
import '../repositories/goal_repository.dart';
import '../repositories/skill_repository.dart';
import '../repositories/recommendation_repository.dart';
import 'schedule_service.dart';

/// Business logic for Screen 3 — "I'm Free" (Phase 7). Scores unfinished
/// tasks (and rest) against urgency, goal importance, deadline pressure,
/// and skill need, then either returns one best pick + alternatives (§5,
/// §17) or a packed multi-activity plan (§6), while staying aware of
/// what's already on the schedule (§8 farming awareness) and offering
/// rest as a legitimate option (§9).
///
/// NOTE on task↔goal / task↔skill linking: the schema has no foreign key
/// between `tasks` and `goals`/`skills`. This matches them by comparing
/// `task.category` against `goal.category` / `skill.name` as a loose
/// proxy. If you want a real link, add `goal_id`/`skill_id` to `tasks`.
class RecommendationService {
  final TaskRepository _taskRepo;
  final GoalRepository _goalRepo;
  final SkillRepository _skillRepo;
  final RecommendationRepository _historyRepo;
  final ScheduleService _scheduleService;

  RecommendationService({
    TaskRepository? taskRepo,
    GoalRepository? goalRepo,
    SkillRepository? skillRepo,
    RecommendationRepository? historyRepo,
    ScheduleService? scheduleService,
  })  : _taskRepo = taskRepo ?? TaskRepository(),
        _goalRepo = goalRepo ?? GoalRepository(),
        _skillRepo = skillRepo ?? SkillRepository(),
        _historyRepo = historyRepo ?? RecommendationRepository(),
        _scheduleService = scheduleService ?? ScheduleService();

  static const int minBlockMinutes = 10;
  static const int maxAlternatives = 4;

  /// A demanding day, for the Rest rule (§9) — 5+ hours already scheduled.
  static const int restThresholdMinutes = 5 * 60;

  // --- Main entry point (§3-5, §8, §17) ---------------------------------------

  /// The full "I'm Free" result: either a "you're busy right now" state
  /// (§8), or a top recommendation + alternatives (§5, §17).
  Future<RecommendationResult> getRecommendation(
    int availableMinutes, {
    String? date,
    String? currentTime,
  }) async {
    final today = date ?? DateFormatter.todayAsDbDate();
    final now = currentTime ?? DateFormatter.nowAsDbTime();

    // Farming / busy-block awareness (§8): if right now overlaps an
    // existing schedule item, don't recommend anything — say what's
    // occupying the time and when the user is next free.
    final busyItems = await _scheduleService.getScheduleForDate(today);
    final currentBusyItem = busyItems.where(
      (i) => now.compareTo(i.startTime) >= 0 && now.compareTo(i.endTime) < 0,
    );
    if (currentBusyItem.isNotEmpty) {
      final busy = currentBusyItem.first;
      final freeBlocks = await _scheduleService.getFreeTimeBlocks(today);
      final nextBlock = freeBlocks.where((b) => b.start.compareTo(busy.endTime) >= 0);
      return RecommendationResult.busy(
        busyActivityTitle: busy.title,
        busyUntil: busy.endTime,
        nextAvailableTime: nextBlock.isEmpty ? null : nextBlock.first.start,
      );
    }

    final candidates = await _buildScoredCandidates(today, availableMinutes);

    if (candidates.isEmpty) {
      final rest = ScoredCandidate(
        label: 'Rest',
        category: 'Rest',
        tag: UrgencyTag.rest,
        reason: 'Nothing pending right now',
        estimatedMinutes: availableMinutes,
        score: 1,
      );
      return RecommendationResult.recommendation(recommended: rest, alternatives: const []);
    }

    final recommended = candidates.first;
    final alternatives = candidates.skip(1).take(maxAlternatives).toList();

    return RecommendationResult.recommendation(recommended: recommended, alternatives: alternatives);
  }

  /// A packed multi-activity plan like "YOUR 2-HOUR PLAN" (§6), built from
  /// the same scored candidates, proportioned to fill [availableMinutes].
  Future<List<PlanBlock>> buildPlan(int availableMinutes, {String? date}) async {
    final today = date ?? DateFormatter.todayAsDbDate();
    final candidates = await _buildScoredCandidates(today, availableMinutes);

    if (candidates.isEmpty) {
      return [PlanBlock(label: 'Rest', category: 'Rest', minutes: availableMinutes)];
    }

    final totalScore = candidates.fold<double>(0, (sum, c) => sum + c.score);
    final workableMinutes = (availableMinutes * 0.85).round();
    final plan = <PlanBlock>[];
    int remaining = availableMinutes;

    for (final candidate in candidates) {
      if (remaining < minBlockMinutes) break;
      final share = (workableMinutes * (candidate.score / totalScore)).round();
      final minutes = share.clamp(minBlockMinutes, remaining);
      plan.add(PlanBlock(label: candidate.label, category: candidate.category, minutes: minutes));
      remaining -= minutes;
    }

    if (remaining >= minBlockMinutes) {
      plan.add(PlanBlock(label: 'Break', category: 'Rest', minutes: remaining));
    }

    return plan;
  }

  // --- Scoring (§3-4, §9) -------------------------------------------------------

  Future<List<ScoredCandidate>> _buildScoredCandidates(String today, int availableMinutes) async {
    final tasks = (await _taskRepo.getAll()).where((t) => t.status != TaskStatus.done).toList();
    final goals = await _goalRepo.getAll();
    final activeGoals = goals.where((g) => g.status == GoalStatus.active).toList();
    final skills = await _skillRepo.getAll();

    final candidates = <ScoredCandidate>[];

    for (final task in tasks) {
      candidates.add(_scoreTask(task, activeGoals, skills, availableMinutes));
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    // Rest rule (§9): if today's already demanding, surface Rest near the
    // top even if there's unfinished work, rather than only as a fallback.
    final busyMinutesToday = (await _scheduleService.getScheduleForDate(today)).fold<int>(
      0,
      (sum, item) => sum + (_toMinutes(item.endTime) - _toMinutes(item.startTime)),
    );
    if (busyMinutesToday >= restThresholdMinutes) {
      final restIndex = candidates.length >= 2 ? 1 : 0; // still let the most urgent thing lead if any
      candidates.insert(
        restIndex,
        ScoredCandidate(
          label: 'Rest',
          category: 'Rest',
          tag: UrgencyTag.rest,
          reason: "You've had a demanding day",
          estimatedMinutes: availableMinutes >= 30 ? 30 : availableMinutes,
          score: 4.5, // deliberately competitive, not automatic top pick
        ),
      );
    }

    return candidates;
  }

  ScoredCandidate _scoreTask(
    Task task,
    List<Goal> activeGoals,
    List<Skill> skills,
    int availableMinutes,
  ) {
    // Urgency: the task's own priority flag (🔴🟡🟢).
    final urgencyWeight = _priorityWeight(task.priority);

    // Deadline: how soon it's due (Phase 7 §4 treats this separately from
    // the task's set priority).
    int deadlineScore = 0;
    String? deadlineReason;
    if (task.dueDate != null) {
      final daysUntilDue = DateFormatter.fromDbDate(task.dueDate!)
          .difference(DateFormatter.fromDbDate(DateFormatter.todayAsDbDate()))
          .inDays;
      if (daysUntilDue <= 0) {
        deadlineScore = 5;
        deadlineReason = daysUntilDue == 0 ? 'Due today' : 'Overdue';
      } else if (daysUntilDue <= 3) {
        deadlineScore = 3;
        deadlineReason = 'Due in $daysUntilDue day${daysUntilDue == 1 ? '' : 's'}';
      } else if (daysUntilDue <= 7) {
        deadlineScore = 1;
        deadlineReason = 'Due in $daysUntilDue days';
      }
    }

    // Goal importance: task.category matched against an active goal's
    // category (see class-level NOTE on this being a proxy link).
    double goalBonus = 0;
    Goal? linkedGoal;
    for (final goal in activeGoals) {
      if (goal.category != null &&
          task.category != null &&
          goal.category!.toLowerCase() == task.category!.toLowerCase()) {
        final weight = _priorityWeight(goal.priority).toDouble();
        if (weight > goalBonus) {
          goalBonus = weight;
          linkedGoal = goal;
        }
      }
    }

    // Skill importance: task.category matched against a skill name;
    // favor skills furthest from their target.
    double skillBonus = 0;
    Skill? linkedSkill;
    for (final skill in skills) {
      if (task.category != null &&
          skill.name.toLowerCase().contains(task.category!.toLowerCase()) &&
          skill.percent < 1.0) {
        final bonus = (1 - skill.percent) * 3;
        if (bonus > skillBonus) {
          skillBonus = bonus;
          linkedSkill = skill;
        }
      }
    }

    // Available-time fit: small bonus if a reasonable estimate for this
    // task actually fits inside what the user has right now.
    final estimatedMinutes = _estimateMinutes(task, availableMinutes);
    final fitBonus = estimatedMinutes <= availableMinutes ? 1.0 : 0.0;

    final score = urgencyWeight + deadlineScore + goalBonus + skillBonus + fitBonus;

    final tag = deadlineScore >= 5
        ? UrgencyTag.urgent
        : (goalBonus > 0 || deadlineScore >= 3)
            ? UrgencyTag.important
            : skillBonus > 0
                ? UrgencyTag.useful
                : UrgencyTag.optional;

    final reason = deadlineReason ??
        (linkedGoal != null ? 'Connected to "${linkedGoal.name}" goal' : null) ??
        (linkedSkill != null ? '${linkedSkill.name} needs practice' : null) ??
        'Pending task';

    return ScoredCandidate(
      label: task.title,
      category: task.category ?? 'Task',
      taskId: task.id,
      tag: tag,
      reason: reason,
      estimatedMinutes: estimatedMinutes,
      score: score,
    );
  }

  int _estimateMinutes(Task task, int availableMinutes) {
    // No stored duration for tasks yet — a simple, honest default rather
    // than a fabricated precise number.
    final defaultEstimate = task.priority == TaskPriority.high ? 45 : 30;
    return defaultEstimate.clamp(minBlockMinutes, availableMinutes);
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

  int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  // --- Lifecycle: start -> complete/skip (§10-13) -------------------------------

  /// Logs the moment a suggestion is actually started (Timer begins).
  Future<int> startActivity({
    required ScoredCandidate candidate,
    required int availableMinutes,
  }) {
    return _historyRepo.create(RecommendationHistory(
      taskId: candidate.taskId,
      activityTitle: candidate.label,
      category: candidate.category,
      availableMinutes: availableMinutes,
      estimatedMinutes: candidate.estimatedMinutes,
      recommendedAt: DateFormatter.nowAsDbDateTime(),
      result: RecommendationResultStatus.inProgress,
    ));
  }

  /// "🎉 ACTIVITY COMPLETE" + feedback (§11).
  Future<void> completeActivity(int historyId, {RecommendationFeedback? feedback}) async {
    final entry = await _historyRepo.getById(historyId);
    if (entry == null) return;
    await _historyRepo.update(entry.copyWith(
      result: RecommendationResultStatus.completed,
      feedback: feedback,
      completedAt: DateFormatter.nowAsDbDateTime(),
    ));
  }

  /// The user picked something else, or dismissed the timer without finishing.
  Future<void> skipActivity(int historyId) async {
    final entry = await _historyRepo.getById(historyId);
    if (entry == null) return;
    await _historyRepo.update(entry.copyWith(result: RecommendationResultStatus.skipped));
  }

  Future<List<RecommendationHistory>> getHistory() => _historyRepo.getAll();

  /// Basic "learn from behavior" starting point (§12): completion rate per
  /// category. Pattern-detection beyond this (e.g. "usually codes in the
  /// afternoon") is intentionally left for a later phase.
  Future<Map<String, double>> getCompletionRateByCategory() async {
    final all = await _historyRepo.getAll();
    final Map<String, List<RecommendationHistory>> byCategory = {};
    for (final entry in all) {
      final key = entry.category ?? 'Uncategorized';
      byCategory.putIfAbsent(key, () => []).add(entry);
    }

    return {
      for (final entry in byCategory.entries)
        entry.key: entry.value.where((e) => e.result == RecommendationResultStatus.completed).length /
            entry.value.length,
    };
  }
}

/// Tags shown as 🔴🟠🟡🟢🔵 in the UI (§3).
enum UrgencyTag { urgent, important, useful, optional, rest }

/// One scored candidate activity.
class ScoredCandidate {
  final String label;
  final String category;
  final int? taskId;
  final UrgencyTag tag;
  final String reason;
  final int estimatedMinutes;
  final double score;

  const ScoredCandidate({
    required this.label,
    required this.category,
    this.taskId,
    required this.tag,
    required this.reason,
    required this.estimatedMinutes,
    required this.score,
  });
}

/// One block in a packed multi-activity plan (§6).
class PlanBlock {
  final String label;
  final String category;
  final int minutes;

  const PlanBlock({required this.label, required this.category, required this.minutes});
}

/// What `getRecommendation` returns: either "you're busy" (§8) or a
/// top pick + alternatives (§5, §17).
class RecommendationResult {
  final bool isBusy;
  final String? busyActivityTitle;
  final String? busyUntil;
  final String? nextAvailableTime;
  final ScoredCandidate? recommended;
  final List<ScoredCandidate> alternatives;

  const RecommendationResult._({
    required this.isBusy,
    this.busyActivityTitle,
    this.busyUntil,
    this.nextAvailableTime,
    this.recommended,
    this.alternatives = const [],
  });

  factory RecommendationResult.busy({
    required String busyActivityTitle,
    required String busyUntil,
    String? nextAvailableTime,
  }) {
    return RecommendationResult._(
      isBusy: true,
      busyActivityTitle: busyActivityTitle,
      busyUntil: busyUntil,
      nextAvailableTime: nextAvailableTime,
    );
  }

  factory RecommendationResult.recommendation({
    required ScoredCandidate recommended,
    required List<ScoredCandidate> alternatives,
  }) {
    return RecommendationResult._(
      isBusy: false,
      recommended: recommended,
      alternatives: alternatives,
    );
  }
}