import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/campaign_lifecycle.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TasksLoad {
  loading,
  noProfile,
  noCurrentDay,
  freePlayCompleted,
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
    this.shopItems = const {},
    this.legacyDayFiveCompleted = false,
    this.submittingTaskId,
  });

  final TasksLoad load;
  final int? profileId;
  final GamePeriod? period;
  final List<FinancialTask> tasks;
  final Set<String> completedTaskIds;
  final Map<String, ShopItem> shopItems;
  final bool legacyDayFiveCompleted;
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
    shopItems: shopItems,
    legacyDayFiveCompleted: legacyDayFiveCompleted,
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

  Future<TaskSubmissionResult?> submitShoppingTrip(
    FinancialTask task,
    Map<String, ShoppingTripSelection> selections,
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
          .submitShoppingTrip(
            profileId: profileId,
            periodId: periodId,
            taskId: task.id,
            selections: selections,
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
        final mode =
            (await ref.read(campaignLifecycleServiceProvider).load(profileId))
                .mode;
        if (_isCurrent(generation, profileId)) {
          state = TasksState(
            load: mode == CampaignMode.freePlay
                ? TasksLoad.freePlayCompleted
                : TasksLoad.noCurrentDay,
            profileId: profileId,
          );
        }
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
      var legacyDayFiveCompleted = false;
      var shopItems = const <String, ShopItem>{};
      if (period.periodNumber == 5) {
        final status = await ref
            .read(taskServiceProvider)
            .loadDayFiveCompletion(profileId: profileId, periodId: period.id!);
        legacyDayFiveCompleted = status.legacyCompleted;
        completed.addAll(status.completedTaskIds);
      } else {
        for (final task in tasks) {
          if (await games.getTaskProgress(profileId, task.id) != null) {
            completed.add(task.id);
          }
        }
      }
      if (period.periodNumber == 1 ||
          period.periodNumber == 2 ||
          period.periodNumber == 5) {
        final catalog = await ref
            .read(contentRepositoryProvider)
            .loadShopItems();
        shopItems = Map.unmodifiable({
          for (final item in catalog) item.id: item,
        });
      }
      if (!_isCurrent(generation, profileId)) return;
      state = TasksState(
        load: TasksLoad.ready,
        profileId: profileId,
        period: period,
        tasks: List.unmodifiable(tasks),
        completedTaskIds: Set.unmodifiable(completed),
        shopItems: shopItems,
        legacyDayFiveCompleted: legacyDayFiveCompleted,
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

  Future<TaskSubmissionResult?> submitBudgetPriority(
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
          .submitBudgetPriority(
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

  Future<TaskSubmissionResult?> submitPlanAdaptation(
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
          .submitPlanAdaptation(
            profileId: profileId,
            periodId: periodId,
            taskId: task.id,
            assignments: assignments,
          );
      if (ref.read(activeProfileIdProvider) != profileId) return null;
      if (result is TaskAnswerCompleted) {
        try {
          await ref
              .read(storyEventServiceProvider)
              .armOrLoadDay3Bowl(profileId: profileId);
        } catch (_) {
          // The task is already committed. Home repairs missing event state.
        }
        await load();
      }
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

  Future<TaskSubmissionResult?> submitIndependentBudget(
    FinancialTask task,
    Set<String> selectedItemIds,
    int savingsAmount,
  ) => _submitDayFive(
    task,
    (profileId, periodId) => ref
        .read(taskServiceProvider)
        .submitIndependentBudget(
          profileId: profileId,
          periodId: periodId,
          taskId: task.id,
          selectedItemIds: selectedItemIds,
          savingsAmount: savingsAmount,
        ),
  );

  Future<TaskSubmissionResult?> submitPlanRepair(
    FinancialTask task,
    Set<String> nowItemIds,
    int savingsAmount,
  ) => _submitDayFive(
    task,
    (profileId, periodId) => ref
        .read(taskServiceProvider)
        .submitPlanRepair(
          profileId: profileId,
          periodId: periodId,
          taskId: task.id,
          nowItemIds: nowItemIds,
          savingsAmount: savingsAmount,
        ),
  );

  Future<TaskSubmissionResult?> _submitDayFive(
    FinancialTask task,
    Future<TaskSubmissionResult> Function(int profileId, int periodId) action,
  ) async {
    final current = state;
    final profileId = current.profileId;
    final periodId = current.period?.id;
    if (_submitting ||
        current.load != TasksLoad.ready ||
        current.legacyDayFiveCompleted ||
        profileId == null ||
        periodId == null ||
        current.isCompleted(task)) {
      return null;
    }
    _submitting = true;
    state = current.copyWith(submittingTaskId: task.id);
    try {
      final result = await action(profileId, periodId);
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
