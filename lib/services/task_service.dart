import 'package:finny/models/financial_task.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';

class TaskService {
  TaskService(
    this._gameRepository,
    this._taskCompletionPort,
    this._contentRepository,
  );

  final GameRepository _gameRepository;
  final TaskCompletionPort _taskCompletionPort;
  final ContentRepository _contentRepository;

  Future<TaskSubmissionResult> submitAnswer({
    required int profileId,
    required int periodId,
    required String taskId,
    required String answerId,
  }) async {
    if (profileId <= 0 ||
        periodId <= 0 ||
        taskId.trim().isEmpty ||
        answerId.trim().isEmpty) {
      throw ArgumentError('Profile, period, task and answer IDs are required.');
    }
    final tasks = await _contentRepository.loadTasks();
    validateTaskContent(tasks);
    final matches = tasks.where((task) => task.id == taskId).toList();
    if (matches.isEmpty) throw StateError('Task $taskId does not exist.');
    final task = matches.single;
    if (!task.choiceScenario.options.any((option) => option.id == answerId)) {
      throw ArgumentError.value(answerId, 'answerId', 'Unknown answer ID.');
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
    if (!period.requiredCheckpoints.contains('financial_task')) {
      throw StateError('Period $periodId does not require a financial task.');
    }
    return _taskCompletionPort.submitFinancialTaskAnswer(
      profileId: profileId,
      periodId: periodId,
      task: task,
      answerId: answerId,
    );
  }
}
