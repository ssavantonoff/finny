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
