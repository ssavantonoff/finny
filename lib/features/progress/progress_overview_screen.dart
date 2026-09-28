import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_flow_visuals.dart';
import 'package:finny/features/progress/progress_overview_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProgressOverviewScreen extends ConsumerWidget {
  const ProgressOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(progressOverviewProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('progress-overview-back'),
          tooltip: 'Назад',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Прогресс'),
      ),
      body: FinnyFlowBackdrop(
        child: SafeArea(
          child: overview.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Не получилось открыть прогресс.'),
                    const SizedBox(height: AppSpacing.medium),
                    FinnyFlowButton(
                      label: 'Попробовать снова',
                      onPressed: () => ref.invalidate(progressOverviewProvider),
                    ),
                  ],
                ),
              ),
            ),
            data: (snapshot) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  key: const Key('progress-overview-list'),
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  children: [
                    _Section(
                      icon: Icons.savings_rounded,
                      title: 'Текущая цель',
                      child: snapshot.activeGoal == null
                          ? const Text('Цель пока не выбрана.')
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  snapshot.activeGoal!.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.small),
                                Text(
                                  'Накоплено: ${snapshot.savedAmount} из ${snapshot.activeGoal!.price} монет',
                                ),
                                const SizedBox(height: AppSpacing.tiny),
                                Text(
                                  'Осталось: ${(snapshot.activeGoal!.price - snapshot.savedAmount).clamp(0, snapshot.activeGoal!.price)} монет',
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: AppSpacing.compact),
                    _Section(
                      icon: Icons.task_alt_rounded,
                      title: 'Завершённые задания',
                      child: snapshot.completedTasks.isEmpty
                          ? const Text('Ты ещё не выполнил финансовые задания.')
                          : Column(
                              children: [
                                for (final task in snapshot.completedTasks)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.small,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.success,
                                          size: 24,
                                        ),
                                        const SizedBox(width: AppSpacing.small),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'День ${task.day} — ${task.title}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const Text(
                                                'Выполнено ✓',
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: AppSpacing.compact),
                    _Section(
                      icon: Icons.auto_graph_rounded,
                      title: 'Последний день',
                      child:
                          snapshot.lastCompletedPeriod == null ||
                              snapshot.lastSummary == null
                          ? const Text(
                              'Итоги появятся после первого завершённого дня.',
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'День ${snapshot.lastCompletedPeriod!.periodNumber}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.medium),
                                const _PlanFactRow(
                                  label: '',
                                  plan: 'План',
                                  fact: 'Факт',
                                  isHeader: true,
                                ),
                                _PlanFactRow(
                                  label: 'Нужно',
                                  plan: '${snapshot.lastSummary!.plannedNeed}',
                                  fact: '${snapshot.lastSummary!.factNeed}',
                                ),
                                _PlanFactRow(
                                  label: 'Хочу',
                                  plan: '${snapshot.lastSummary!.plannedWant}',
                                  fact: '${snapshot.lastSummary!.factWant}',
                                ),
                                _PlanFactRow(
                                  label: 'Копилка',
                                  plan:
                                      '${snapshot.lastSummary!.plannedSavings}',
                                  fact: '${snapshot.lastSummary!.factSavings}',
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white.withValues(alpha: 0.94),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadii.smallCard),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            child: child,
          ),
        ],
      ),
    ),
  );
}

class _PlanFactRow extends StatelessWidget {
  const _PlanFactRow({
    required this.label,
    required this.plan,
    required this.fact,
    this.isHeader = false,
  });

  final String label;
  final String plan;
  final String fact;
  final bool isHeader;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isHeader ? FontWeight.w500 : FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            plan,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            fact,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
