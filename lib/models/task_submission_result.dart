import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';

sealed class TaskSubmissionResult {
  const TaskSubmissionResult({required this.explanation});

  final String explanation;
}

final class TaskAnswerIncorrect extends TaskSubmissionResult {
  const TaskAnswerIncorrect({required super.explanation});

  bool get rewardAppliedNow => false;
}

final class TaskCategorizationIncorrect extends TaskSubmissionResult {
  const TaskCategorizationIncorrect({
    required super.explanation,
    required this.incorrectItemIds,
  });

  final Set<String> incorrectItemIds;

  bool get rewardAppliedNow => false;
}

final class TaskBudgetPriorityIncorrect extends TaskSubmissionResult {
  const TaskBudgetPriorityIncorrect({
    required super.explanation,
    required this.incorrectItemIds,
    this.overBudgetBy = 0,
  });

  final Set<String> incorrectItemIds;
  final int overBudgetBy;

  bool get rewardAppliedNow => false;
}

final class TaskPlanAdaptationIncorrect extends TaskSubmissionResult {
  const TaskPlanAdaptationIncorrect({
    required super.explanation,
    required this.incorrectItemIds,
    this.overBudgetBy = 0,
  });

  final Set<String> incorrectItemIds;
  final int overBudgetBy;

  bool get rewardAppliedNow => false;
}

final class TaskShoppingTripIncorrect extends TaskSubmissionResult {
  const TaskShoppingTripIncorrect({
    required super.explanation,
    required this.insufficientItemIds,
    required this.purchasedAmounts,
    required this.totalCost,
    required this.overBudgetBy,
  });

  final Set<String> insufficientItemIds;
  final Map<String, int> purchasedAmounts;
  final int totalCost;
  final int overBudgetBy;

  bool get rewardAppliedNow => false;
}

final class TaskDayFiveIncorrect extends TaskSubmissionResult {
  const TaskDayFiveIncorrect({
    required super.explanation,
    required this.missingRequiredIds,
    required this.savingsShortfall,
    required this.overBudgetBy,
    required this.total,
  });

  final Set<String> missingRequiredIds;
  final int savingsShortfall;
  final int overBudgetBy;
  final int total;
}

final class TaskAnswerCompleted extends TaskSubmissionResult {
  const TaskAnswerCompleted({
    required super.explanation,
    required this.canonicalReward,
    required this.rewardAppliedNow,
    required this.wasAlreadyCompleted,
    required this.gameState,
    required this.period,
  });

  final int canonicalReward;
  final bool rewardAppliedNow;
  final bool wasAlreadyCompleted;
  final GameState gameState;
  final GamePeriod period;
}

class TaskIntegrityException implements Exception {
  const TaskIntegrityException(this.message);

  final String message;

  @override
  String toString() => 'TaskIntegrityException: $message';
}
