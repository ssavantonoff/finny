import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TasksLoad {
  loading,
  noProfile,
  noCurrentDay,
  planning,
  ready,
  contentFailure,
  runtimeFailure,
}

class TasksState {
  const TasksState({
    this.load = TasksLoad.loading,
    this.profileId,
    this.period,
    this.tasks = const [],
    this.completedTaskIds = const {},
    this.submittingTaskId,
  });

  final TasksLoad load;
  final int? profileId;
  final GamePeriod? period;
  final List<FinancialTask> tasks;
  final Set<String> completedTaskIds;
  final String? submittingTaskId;

  bool isCompleted(FinancialTask task) => completedTaskIds.contains(task.id);

  TasksState copyWith({
    String? submittingTaskId,
    bool clearSubmitting = false,
  }) => TasksState(
    load: load,
    profileId: profileId,
    period: period,
    tasks: tasks,
    completedTaskIds: completedTaskIds,
    submittingTaskId: clearSubmitting
        ? null
        : submittingTaskId ?? this.submittingTaskId,
  );
}

final tasksControllerProvider = NotifierProvider<TasksController, TasksState>(
  TasksController.new,
);

class TasksController extends Notifier<TasksState> {
  int _generation = 0;
  bool _submitting = false;

  @override
  TasksState build() {
    ref.listen<int?>(activeProfileIdProvider, (_, _) => unawaited(load()));
    return const TasksState();
  }

  bool _isCurrent(int generation, int? profileId) =>
      generation == _generation &&
      ref.read(activeProfileIdProvider) == profileId;

  Future<void> load() async {
    final generation = ++_generation;
    final profileId = ref.read(activeProfileIdProvider);
    state = TasksState(profileId: profileId);
    if (profileId == null) {
      state = const TasksState(load: TasksLoad.noProfile);
      return;
    }

    late List<FinancialTask> allTasks;
    try {
      allTasks = await ref.read(contentRepositoryProvider).loadTasks();
    } catch (_) {
      if (_isCurrent(generation, profileId)) {
        state = TasksState(
          load: TasksLoad.contentFailure,
          profileId: profileId,
        );
      }
      return;
    }

    try {
      final games = ref.read(gameRepositoryProvider);
      final period = await games.getCurrentPeriod(profileId);
      if (!_isCurrent(generation, profileId)) return;
      if (period == null) {
        state = TasksState(load: TasksLoad.noCurrentDay, profileId: profileId);
        return;
      }
      if (period.status == GamePeriodStatus.planning) {
        state = TasksState(
          load: TasksLoad.planning,
          profileId: profileId,
          period: period,
        );
        return;
      }
      final tasks = allTasks
          .where((task) => task.period == period.periodNumber)
          .toList(growable: false);
      final completed = <String>{};
      for (final task in tasks) {
        if (await games.getTaskProgress(profileId, task.id) != null) {
          completed.add(task.id);
        }
      }
      if (!_isCurrent(generation, profileId)) return;
      state = TasksState(
        load: TasksLoad.ready,
        profileId: profileId,
        period: period,
        tasks: List.unmodifiable(tasks),
        completedTaskIds: Set.unmodifiable(completed),
      );
    } catch (_) {
      if (_isCurrent(generation, profileId)) {
        state = TasksState(
          load: TasksLoad.runtimeFailure,
          profileId: profileId,
        );
      }
    }
  }

  Future<TaskSubmissionResult?> submit(
    FinancialTask task,
    String answerId,
  ) async {
    final current = state;
    final profileId = current.profileId;
    final periodId = current.period?.id;
    if (_submitting ||
        current.load != TasksLoad.ready ||
        profileId == null ||
        periodId == null ||
        current.isCompleted(task)) {
      return null;
    }
    _submitting = true;
    state = current.copyWith(submittingTaskId: task.id);
    try {
      final result = await ref
          .read(taskServiceProvider)
          .submitAnswer(
            profileId: profileId,
            periodId: periodId,
            taskId: task.id,
            answerId: answerId,
          );
      if (ref.read(activeProfileIdProvider) != profileId) return null;
      if (result is TaskAnswerCompleted) await load();
      return result;
    } catch (_) {
      if (ref.read(activeProfileIdProvider) == profileId) {
        state = current.copyWith(clearSubmitting: true);
      }
      rethrow;
    } finally {
      _submitting = false;
      if (state.submittingTaskId != null) {
        state = state.copyWith(clearSubmitting: true);
      }
    }
  }

  Future<TaskSubmissionResult?> submitCategorization(
    FinancialTask task,
    Map<String, String> assignments,
  ) async {
    final current = state;
    final profileId = current.profileId;
    final periodId = current.period?.id;
    if (_submitting ||
        current.load != TasksLoad.ready ||
        profileId == null ||
        periodId == null ||
        current.isCompleted(task)) {
      return null;
    }
    _submitting = true;
    state = current.copyWith(submittingTaskId: task.id);
    try {
      final result = await ref
          .read(taskServiceProvider)
          .submitCategorization(
            profileId: profileId,
            periodId: periodId,
            taskId: task.id,
            assignments: assignments,
          );
      if (ref.read(activeProfileIdProvider) != profileId) return null;
      if (result is TaskAnswerCompleted) await load();
      return result;
    } catch (_) {
      if (ref.read(activeProfileIdProvider) == profileId) {
        state = current.copyWith(clearSubmitting: true);
      }
      rethrow;
    } finally {
      _submitting = false;
      if (state.submittingTaskId != null) {
        state = state.copyWith(clearSubmitting: true);
      }
    }
  }
}
