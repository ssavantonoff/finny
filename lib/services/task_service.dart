import 'package:finny/models/financial_task.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/game_repository.dart';

class TaskService {
  TaskService(this._gameRepository);

  final GameRepository _gameRepository;

  Future<GameState> rewardCompletedTask({
    required int profileId,
    required int periodId,
    required FinancialTask task,
  }) async {
    if (task.reward <= 0) {
      throw ArgumentError.value(
        task.reward,
        'task.reward',
        'Must be positive.',
      );
    }
    final period = await _gameRepository.getPeriodById(profileId, periodId);
    if (period == null) {
      throw StateError(
        'Period $periodId does not exist for profile $profileId.',
      );
    }
    if (task.period != period.periodNumber) {
      throw StateError('Task ${task.id} does not belong to this period.');
    }
    return _gameRepository.applyWalletChange(
      GameTransaction(
        profileId: profileId,
        periodId: periodId,
        type: GameTransactionType.taskReward,
        amount: task.reward,
        source: 'task_reward_${task.id}',
        description: 'Награда за задание: ${task.title}',
        createdAt: DateTime.now().toUtc(),
        deduplicationKey: 'task_reward_${period.id}_${task.id}',
      ),
    );
  }
}
