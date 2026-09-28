import 'package:finny/app/providers.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/period_summary.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CompletedFinancialTask {
  const CompletedFinancialTask({required this.day, required this.title});

  final int day;
  final String title;
}

class ProgressOverviewSnapshot {
  const ProgressOverviewSnapshot({
    required this.activeGoal,
    required this.savedAmount,
    required this.completedTasks,
    required this.lastCompletedPeriod,
    required this.lastSummary,
  });

  final SavingsGoal? activeGoal;
  final int savedAmount;
  final List<CompletedFinancialTask> completedTasks;
  final GamePeriod? lastCompletedPeriod;
  final PeriodSummary? lastSummary;
}

final progressOverviewProvider = FutureProvider<ProgressOverviewSnapshot>((
  ref,
) async {
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    return const ProgressOverviewSnapshot(
      activeGoal: null,
      savedAmount: 0,
      completedTasks: [],
      lastCompletedPeriod: null,
      lastSummary: null,
    );
  }

  final games = ref.read(gameRepositoryProvider);
  final savings = await ref
      .read(savingsServiceProvider)
      .loadSnapshot(profileId);
  final tasks = await ref.read(contentRepositoryProvider).loadTasks();
  final periods = await games.getPeriods(profileId);
  final completed = <CompletedFinancialTask>[];
  final dayFivePeriod = periods
      .where((period) => period.periodNumber == 5)
      .firstOrNull;
  final dayFive = dayFivePeriod?.id == null
      ? null
      : await ref
            .read(taskServiceProvider)
            .loadDayFiveCompletion(
              profileId: profileId,
              periodId: dayFivePeriod!.id!,
            );

  for (final task in tasks) {
    if (task.period == 5) {
      if (dayFive?.completedTaskIds.contains(task.id) ?? false) {
        completed.add(
          CompletedFinancialTask(day: task.period, title: task.title),
        );
      }
    } else if (await games.getTaskProgress(profileId, task.id) != null) {
      completed.add(
        CompletedFinancialTask(day: task.period, title: task.title),
      );
    }
  }
  if (dayFive?.legacyCompleted ?? false) {
    completed.add(
      const CompletedFinancialTask(day: 5, title: 'Самостоятельный выбор'),
    );
  }

  final completedPeriods = periods.where(
    (period) => period.status == GamePeriodStatus.completed,
  );
  final lastPeriod = completedPeriods.isEmpty ? null : completedPeriods.last;
  final summary = lastPeriod?.id == null
      ? null
      : await ref
            .read(periodServiceProvider)
            .getSummary(profileId: profileId, periodId: lastPeriod!.id!);
  final activeGoalId = savings.state.activeGoalId;
  final activeGoal = activeGoalId == null
      ? null
      : savings.goals.where((goal) => goal.id == activeGoalId).single;

  return ProgressOverviewSnapshot(
    activeGoal: activeGoal,
    savedAmount: savings.state.savedAmount,
    completedTasks: List.unmodifiable(completed),
    lastCompletedPeriod: lastPeriod,
    lastSummary: summary,
  );
});
