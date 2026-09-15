import 'package:finny/models/financial_task.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/game_repository.dart';

class TaskService {
  TaskService(this._gameRepository);

  final GameRepository _gameRepository;

  Future<GameState> rewardCompletedTask({
    required int profileId,
    required int? periodId,
    required FinancialTask task,
  }) {
    if (task.reward <= 0) {
      throw ArgumentError.value(
        task.reward,
        'task.reward',
        'Must be positive.',
      );
    }
    return _gameRepository.applyWalletChange(
      GameTransaction(
        profileId: profileId,
        periodId: periodId,
        type: 'task_reward',
        amount: task.reward,
        source: 'task_reward_${task.id}',
        description: 'Награда за задание: ${task.title}',
        createdAt: DateTime.now().toUtc(),
        deduplicationKey: 'task_reward_${task.id}',
      ),
    );
  }
}
