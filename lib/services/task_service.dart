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

  Future<TaskSubmissionResult> submitShoppingTrip({
    required int profileId,
    required int periodId,
    required String taskId,
    required Map<String, ShoppingTripSelection> selections,
  }) async {
    if (profileId <= 0 || periodId <= 0 || taskId.trim().isEmpty) {
      throw ArgumentError('Profile, period and task IDs are required.');
    }
    final tasks = await _contentRepository.loadTasks();
    validateTaskContent(tasks);
    final matches = tasks.where((task) => task.id == taskId);
    if (matches.length != 1) throw StateError('Task $taskId does not exist.');
    final task = matches.single;
    if (task.id != 'task_shopping_trip_04' ||
        task.type != 'shopping_trip' ||
        task.period != 4 ||
        task.reward != 50 ||
        !task.requiredForCheckpoint ||
        !task.shoppingTripScenario.isCanonicalDay4) {
      throw StateError('Task $taskId has invalid canonical Day 4 content.');
    }
    if (!task.shoppingTripScenario.isValidSubmission(selections)) {
      throw ArgumentError('Invalid shopping trip submission.');
    }
    final period = await _gameRepository.getPeriodById(profileId, periodId);
    if (period == null ||
        period.periodNumber != task.period ||
        !period.requiredCheckpoints.contains('financial_task')) {
      throw StateError('Task does not belong to this period.');
    }
    return _taskCompletionPort.submitFinancialTaskShoppingTrip(
      profileId: profileId,
      periodId: periodId,
      task: task,
      selections: Map.unmodifiable(selections),
    );
  }

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
    if (task.type != 'choice') {
      throw StateError('Task ${task.id} is not a choice task.');
    }
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
    if (task.requiredForCheckpoint &&
        !period.requiredCheckpoints.contains('financial_task')) {
      throw StateError('Period $periodId does not require a financial task.');
    }
    return _taskCompletionPort.submitFinancialTaskAnswer(
      profileId: profileId,
      periodId: periodId,
      task: task,
      answerId: answerId,
    );
  }

  Future<TaskSubmissionResult> submitCategorization({
    required int profileId,
    required int periodId,
    required String taskId,
    required Map<String, String> assignments,
  }) async {
    if (profileId <= 0 || periodId <= 0 || taskId.trim().isEmpty) {
      throw ArgumentError('Profile, period and task IDs are required.');
    }
    final tasks = await _contentRepository.loadTasks();
    validateTaskContent(tasks);
    final matches = tasks.where((task) => task.id == taskId).toList();
    if (matches.isEmpty) throw StateError('Task $taskId does not exist.');
    final task = matches.single;
    if (task.type != 'categorization') {
      throw StateError('Task ${task.id} is not a categorization task.');
    }
    _validateCategorizationSubmission(task.categorizationScenario, assignments);
    final period = await _gameRepository.getPeriodById(profileId, periodId);
    if (period == null) {
      throw StateError(
        'Period $periodId does not exist for profile $profileId.',
      );
    }
    if (task.period != period.periodNumber) {
      throw StateError('Task ${task.id} does not belong to this period.');
    }
    if (task.requiredForCheckpoint &&
        !period.requiredCheckpoints.contains('financial_task')) {
      throw StateError('Period $periodId does not require a financial task.');
    }
    return _taskCompletionPort.submitFinancialTaskCategorization(
      profileId: profileId,
      periodId: periodId,
      task: task,
      assignments: Map.unmodifiable(assignments),
    );
  }

  Future<TaskSubmissionResult> submitBudgetPriority({
    required int profileId,
    required int periodId,
    required String taskId,
    required Map<String, String> assignments,
  }) async {
    if (profileId <= 0 || periodId <= 0 || taskId.trim().isEmpty) {
      throw ArgumentError('Profile, period and task IDs are required.');
    }
    final tasks = await _contentRepository.loadTasks();
    validateTaskContent(tasks);
    final matches = tasks.where((task) => task.id == taskId).toList();
    if (matches.isEmpty) throw StateError('Task $taskId does not exist.');
    final task = matches.single;
    if (task.type != 'budget_priority') {
      throw StateError('Task ${task.id} is not a budget priority task.');
    }
    _validateBudgetPrioritySubmission(task.budgetPriorityScenario, assignments);
    final period = await _gameRepository.getPeriodById(profileId, periodId);
    if (period == null) {
      throw StateError(
        'Period $periodId does not exist for profile $profileId.',
      );
    }
    if (task.period != period.periodNumber) {
      throw StateError('Task ${task.id} does not belong to this period.');
    }
    if (task.requiredForCheckpoint &&
        !period.requiredCheckpoints.contains('financial_task')) {
      throw StateError('Period $periodId does not require a financial task.');
    }
    return _taskCompletionPort.submitFinancialTaskBudgetPriority(
      profileId: profileId,
      periodId: periodId,
      task: task,
      assignments: Map.unmodifiable(assignments),
    );
  }

  Future<TaskSubmissionResult> submitPlanAdaptation({
    required int profileId,
    required int periodId,
    required String taskId,
    required Map<String, String> assignments,
  }) async {
    if (profileId <= 0 || periodId <= 0 || taskId.trim().isEmpty) {
      throw ArgumentError('Profile, period and task IDs are required.');
    }
    final tasks = await _contentRepository.loadTasks();
    validateTaskContent(tasks);
    final matches = tasks.where((task) => task.id == taskId).toList();
    if (matches.isEmpty) throw StateError('Task $taskId does not exist.');
    final task = matches.single;
    if (task.type != 'plan_adaptation' || task.period != 3) {
      throw StateError('Task ${task.id} is not a plan adaptation task.');
    }
    if (!task.planAdaptationScenario.isCanonicalDay3) {
      throw StateError('Task ${task.id} has invalid canonical Day 3 content.');
    }
    _validatePlanAdaptationSubmission(task.planAdaptationScenario, assignments);
    final period = await _gameRepository.getPeriodById(profileId, periodId);
    if (period == null) {
      throw StateError(
        'Period $periodId does not exist for profile $profileId.',
      );
    }
    if (task.period != period.periodNumber) {
      throw StateError('Task ${task.id} does not belong to this period.');
    }
    if (task.requiredForCheckpoint &&
        !period.requiredCheckpoints.contains('financial_task')) {
      throw StateError('Period $periodId does not require a financial task.');
    }
    return _taskCompletionPort.submitFinancialTaskPlanAdaptation(
      profileId: profileId,
      periodId: periodId,
      task: task,
      assignments: Map.unmodifiable(assignments),
    );
  }
}

void _validateCategorizationSubmission(
  CategorizationTaskScenario scenario,
  Map<String, String> assignments,
) {
  final expectedItemIds = scenario.items.map((item) => item.id).toSet();
  final submittedItemIds = assignments.keys.toSet();
  if (assignments.keys.any((id) => id.trim().isEmpty) ||
      assignments.values.any((id) => id.trim().isEmpty) ||
      submittedItemIds.length != expectedItemIds.length ||
      !submittedItemIds.containsAll(expectedItemIds) ||
      !expectedItemIds.containsAll(submittedItemIds)) {
    throw ArgumentError('Assignments must contain every canonical item once.');
  }
  final categoryIds = scenario.categories
      .map((category) => category.id)
      .toSet();
  if (assignments.values.any(
    (categoryId) => !categoryIds.contains(categoryId),
  )) {
    throw ArgumentError('Assignment contains an unknown category ID.');
  }
}

void _validateBudgetPrioritySubmission(
  BudgetPriorityTaskScenario scenario,
  Map<String, String> assignments,
) {
  final expectedItemIds = scenario.items.map((item) => item.id).toSet();
  final submittedItemIds = assignments.keys.toSet();
  if (assignments.keys.any((id) => id.trim().isEmpty) ||
      assignments.values.any((decision) => decision.trim().isEmpty) ||
      assignments.length != expectedItemIds.length ||
      submittedItemIds.length != expectedItemIds.length ||
      !submittedItemIds.containsAll(expectedItemIds) ||
      !expectedItemIds.containsAll(submittedItemIds)) {
    throw ArgumentError('Assignments must contain every canonical item once.');
  }
  final decisions = BudgetPriorityDecision.values
      .map((decision) => decision.wireValue)
      .toSet();
  if (assignments.values.any((decision) => !decisions.contains(decision))) {
    throw ArgumentError('Assignment contains an unknown decision.');
  }
}

void _validatePlanAdaptationSubmission(
  PlanAdaptationTaskScenario scenario,
  Map<String, String> assignments,
) {
  final expectedItemIds = scenario.items.map((item) => item.id).toSet();
  final submittedItemIds = assignments.keys.toSet();
  if (assignments.keys.any((id) => id.trim().isEmpty) ||
      assignments.values.any((decision) => decision.trim().isEmpty) ||
      assignments.length != expectedItemIds.length ||
      submittedItemIds.length != expectedItemIds.length ||
      !submittedItemIds.containsAll(expectedItemIds) ||
      !expectedItemIds.containsAll(submittedItemIds)) {
    throw ArgumentError('Assignments must contain every canonical item once.');
  }
  final decisions = PlanAdaptationDecision.values
      .map((decision) => decision.wireValue)
      .toSet();
  if (assignments.values.any((decision) => !decisions.contains(decision))) {
    throw ArgumentError('Assignment contains an unknown decision.');
  }
}
