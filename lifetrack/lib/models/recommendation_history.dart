import '../core/database/tables/recommendation_history_table.dart';

enum RecommendationResultStatus { inProgress, completed, skipped }

extension RecommendationResultStatusX on RecommendationResultStatus {
  String get value {
    switch (this) {
      case RecommendationResultStatus.inProgress:
        return 'in_progress';
      case RecommendationResultStatus.completed:
        return 'completed';
      case RecommendationResultStatus.skipped:
        return 'skipped';
    }
  }

  static RecommendationResultStatus fromValue(String value) {
    return RecommendationResultStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RecommendationResultStatus.inProgress,
    );
  }
}

/// "Was this useful?" feedback (Phase 7 §11): 👍 / 😐 / 👎.
enum RecommendationFeedback { positive, neutral, negative }

extension RecommendationFeedbackX on RecommendationFeedback {
  String get value {
    switch (this) {
      case RecommendationFeedback.positive:
        return 'positive';
      case RecommendationFeedback.neutral:
        return 'neutral';
      case RecommendationFeedback.negative:
        return 'negative';
    }
  }

  static RecommendationFeedback? fromValue(String? value) {
    if (value == null) return null;
    for (final f in RecommendationFeedback.values) {
      if (f.value == value) return f;
    }
    return null;
  }
}

/// One logged "I'm Free" suggestion and what happened to it
/// (Phase 7 §12-13: "Recommended Java → Completed ✅").
class RecommendationHistory {
  final int? id;
  final int? taskId;
  final String activityTitle;
  final String? category;
  final int availableMinutes;
  final int estimatedMinutes;
  final String recommendedAt; // 'yyyy-MM-dd HH:mm'
  final RecommendationResultStatus result;
  final RecommendationFeedback? feedback;
  final String? completedAt; // 'yyyy-MM-dd HH:mm'

  const RecommendationHistory({
    this.id,
    this.taskId,
    required this.activityTitle,
    this.category,
    required this.availableMinutes,
    required this.estimatedMinutes,
    required this.recommendedAt,
    this.result = RecommendationResultStatus.inProgress,
    this.feedback,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      RecommendationHistoryTable.colId: id,
      RecommendationHistoryTable.colTaskId: taskId,
      RecommendationHistoryTable.colActivityTitle: activityTitle,
      RecommendationHistoryTable.colCategory: category,
      RecommendationHistoryTable.colAvailableMinutes: availableMinutes,
      RecommendationHistoryTable.colEstimatedMinutes: estimatedMinutes,
      RecommendationHistoryTable.colRecommendedAt: recommendedAt,
      RecommendationHistoryTable.colResult: result.value,
      RecommendationHistoryTable.colFeedback: feedback?.value,
      RecommendationHistoryTable.colCompletedAt: completedAt,
    };
  }

  factory RecommendationHistory.fromMap(Map<String, dynamic> map) {
    return RecommendationHistory(
      id: map[RecommendationHistoryTable.colId] as int?,
      taskId: map[RecommendationHistoryTable.colTaskId] as int?,
      activityTitle: map[RecommendationHistoryTable.colActivityTitle] as String,
      category: map[RecommendationHistoryTable.colCategory] as String?,
      availableMinutes: map[RecommendationHistoryTable.colAvailableMinutes] as int,
      estimatedMinutes: map[RecommendationHistoryTable.colEstimatedMinutes] as int,
      recommendedAt: map[RecommendationHistoryTable.colRecommendedAt] as String,
      result: RecommendationResultStatusX.fromValue(
        map[RecommendationHistoryTable.colResult] as String,
      ),
      feedback: RecommendationFeedbackX.fromValue(
        map[RecommendationHistoryTable.colFeedback] as String?,
      ),
      completedAt: map[RecommendationHistoryTable.colCompletedAt] as String?,
    );
  }

  RecommendationHistory copyWith({
    RecommendationResultStatus? result,
    RecommendationFeedback? feedback,
    String? completedAt,
  }) {
    return RecommendationHistory(
      id: id,
      taskId: taskId,
      activityTitle: activityTitle,
      category: category,
      availableMinutes: availableMinutes,
      estimatedMinutes: estimatedMinutes,
      recommendedAt: recommendedAt,
      result: result ?? this.result,
      feedback: feedback ?? this.feedback,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}