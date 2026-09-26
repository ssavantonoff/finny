import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/tasks/tasks_controller.dart';
import 'package:finny/features/tasks/task_visual_components.dart';
import 'package:finny/models/day_five_task.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:flutter/material.dart';

class IndependentBudgetTaskScreen extends StatefulWidget {
  const IndependentBudgetTaskScreen({
    super.key,
    required this.task,
    required this.controller,
    required this.shopItems,
  });

  final FinancialTask task;
  final TasksController controller;
  final Map<String, ShopItem> shopItems;

  @override
  State<IndependentBudgetTaskScreen> createState() =>
      _IndependentBudgetTaskScreenState();
}

class _IndependentBudgetTaskScreenState
    extends State<IndependentBudgetTaskScreen> {
  final selectedIds = <String>{};
  int savingsAmount = 0;
  TaskSubmissionResult? result;
  bool submitting = false;
  bool failed = false;

  IndependentBudgetScenario get scenario =>
      widget.task.independentBudgetScenario;

  int get purchaseTotal => selectedIds.fold<int>(
    0,
    (total, id) => total + widget.shopItems[id]!.price,
  );

  Future<void> _check() async {
    if (submitting) return;
    setState(() {
      submitting = true;
      failed = false;
    });
    try {
      final submitted = await widget.controller.submitIndependentBudget(
        widget.task,
        Set.unmodifiable(selectedIds),
        savingsAmount,
      );
      if (mounted) setState(() => result = submitted);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('independent-budget-task-screen'),
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: TaskBackdrop()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      TaskScreenHeader(
                        day: widget.task.period,
                        title: widget.task.title,
                        description: scenario.prompt,
                        onClose: submitting
                            ? null
                            : () => Navigator.pop(context),
                      ),
                      const SizedBox(height: 16),
                      if (result case TaskAnswerCompleted(:final explanation))
                        TaskSuccessPanel(
                          reward: widget.task.reward,
                          explanation: explanation,
                          titleKey: const Key(
                            'independent-budget-success-title',
                          ),
                          rewardKey: const Key('independent-budget-reward'),
                        )
                      else ...[
                        _DayFiveSummary(
                          budget: scenario.budget,
                          purchases: purchaseTotal,
                          savings: savingsAmount,
                          keyPrefix: 'independent-budget',
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Выбери покупки',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final item in scenario.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _BudgetItemCard(
                              item: item,
                              price: widget.shopItems[item.id]!.price,
                              shopItems: widget.shopItems,
                              selected: selectedIds.contains(item.id),
                              enabled: !submitting,
                              onPressed: () => setState(() {
                                if (!selectedIds.add(item.id)) {
                                  selectedIds.remove(item.id);
                                }
                                result = null;
                                failed = false;
                              }),
                            ),
                          ),
                        const SizedBox(height: 8),
                        _SavingsStepper(
                          amount: savingsAmount,
                          minimum: scenario.minimumSavings,
                          enabled: !submitting,
                          onChanged: (value) => setState(() {
                            savingsAmount = value;
                            result = null;
                            failed = false;
                          }),
                        ),
                        const SizedBox(height: 12),
                        _DayFiveFeedback(result: result, failed: failed),
                      ],
                    ],
                  ),
                ),
                _CheckBar(
                  completed: result is TaskAnswerCompleted,
                  submitting: submitting,
                  onCheck: _check,
                  onReturn: () => Navigator.pop(context),
                  keyPrefix: 'independent-budget',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlanRepairTaskScreen extends StatefulWidget {
  const PlanRepairTaskScreen({
    super.key,
    required this.task,
    required this.controller,
    required this.shopItems,
  });

  final FinancialTask task;
  final TasksController controller;
  final Map<String, ShopItem> shopItems;

  @override
  State<PlanRepairTaskScreen> createState() => _PlanRepairTaskScreenState();
}

class _PlanRepairTaskScreenState extends State<PlanRepairTaskScreen> {
  late final Set<String> nowIds;
  late int savingsAmount;
  TaskSubmissionResult? result;
  bool submitting = false;
  bool failed = false;

  PlanRepairScenario get scenario => widget.task.planRepairScenario;

  @override
  void initState() {
    super.initState();
    nowIds = scenario.initialNowIds;
    savingsAmount = scenario.initialSavings;
  }

  int _price(String id) => id == scenario.scenarioExpenseId
      ? scenario.scenarioExpensePrice
      : widget.shopItems[id]!.price;

  int get purchaseTotal =>
      nowIds.fold<int>(0, (total, id) => total + _price(id));

  Future<void> _check() async {
    if (submitting) return;
    setState(() {
      submitting = true;
      failed = false;
    });
    try {
      final submitted = await widget.controller.submitPlanRepair(
        widget.task,
        Set.unmodifiable(nowIds),
        savingsAmount,
      );
      if (mounted) setState(() => result = submitted);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('plan-repair-task-screen'),
    backgroundColor: AppColors.background,
    body: Stack(
      children: [
        const Positioned.fill(child: TaskBackdrop()),
        SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    TaskScreenHeader(
                      day: widget.task.period,
                      title: widget.task.title,
                      description: scenario.prompt,
                      onClose: submitting ? null : () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 16),
                    if (result case TaskAnswerCompleted(:final explanation))
                      TaskSuccessPanel(
                        reward: widget.task.reward,
                        explanation: explanation,
                        titleKey: const Key('plan-repair-success-title'),
                        rewardKey: const Key('plan-repair-reward'),
                      )
                    else ...[
                      TaskSurface(
                        child: Row(
                          children: [
                            TaskItemArt(
                              taskItemId: scenario.scenarioExpenseId,
                              label: 'Новая поилка',
                              shopItems: widget.shopItems,
                              size: 76,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Неожиданная трата',
                                    style: TextStyle(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                                  ),
                                  Text(
                                    scenario.event,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TaskCoinAmount(
                                    text: '${scenario.scenarioExpensePrice}',
                                    coinSize: 19,
                                    fontSize: 16,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DayFiveSummary(
                        budget: scenario.budget,
                        purchases: purchaseTotal,
                        savings: savingsAmount,
                        keyPrefix: 'plan-repair',
                      ),
                      const SizedBox(height: 16),
                      for (final item in scenario.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _RepairItemCard(
                            item: item,
                            price: _price(item.id),
                            shopItems: widget.shopItems,
                            now: nowIds.contains(item.id),
                            enabled: !submitting,
                            onChanged: (now) => setState(() {
                              if (now) {
                                nowIds.add(item.id);
                              } else {
                                nowIds.remove(item.id);
                              }
                              result = null;
                              failed = false;
                            }),
                          ),
                        ),
                      const SizedBox(height: 8),
                      _SavingsStepper(
                        amount: savingsAmount,
                        minimum: scenario.minimumSavings,
                        enabled: !submitting,
                        onChanged: (value) => setState(() {
                          savingsAmount = value;
                          result = null;
                          failed = false;
                        }),
                      ),
                      const SizedBox(height: 12),
                      _DayFiveFeedback(result: result, failed: failed),
                    ],
                  ],
                ),
              ),
              _CheckBar(
                completed: result is TaskAnswerCompleted,
                submitting: submitting,
                onCheck: _check,
                onReturn: () => Navigator.pop(context),
                keyPrefix: 'plan-repair',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DayFiveSummary extends StatelessWidget {
  const _DayFiveSummary({
    required this.budget,
    required this.purchases,
    required this.savings,
    required this.keyPrefix,
  });

  final int budget;
  final int purchases;
  final int savings;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final remaining = budget - purchases - savings;
    return TaskSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Бюджет',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TaskCoinAmount(text: '$budget', fontSize: 19),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Всего',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${purchases + savings} / $budget',
                      key: Key('$keyPrefix-total'),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: AppSpacing.medium,
            runSpacing: AppSpacing.small,
            children: [
              Text('Покупки: $purchases'),
              Text('На цель: $savings'),
              Text('Осталось: $remaining', key: Key('$keyPrefix-remaining')),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ((purchases + savings) / budget).clamp(0, 1).toDouble(),
              minHeight: 9,
              backgroundColor: AppColors.primaryLight,
              color: remaining < 0 ? AppColors.error : AppColors.primary,
            ),
          ),
          if (remaining < 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Не хватает ${-remaining} монет',
                key: Key('$keyPrefix-deficit'),
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BudgetItemCard extends StatelessWidget {
  const _BudgetItemCard({
    required this.item,
    required this.price,
    required this.shopItems,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });
  final DayFiveTaskItem item;
  final int price;
  final Map<String, ShopItem> shopItems;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TaskSurface(
    key: Key('independent-budget-item-${item.id}'),
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TaskItemArt(
              taskItemId: item.id,
              label: item.label,
              shopItems: shopItems,
              size: 70,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TaskCoinAmount(text: '$price', coinSize: 18, fontSize: 16),
                  Text(
                    item.context,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppColors.success),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          key: Key('independent-budget-toggle-${item.id}'),
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: selected
                ? AppColors.primaryLight
                : AppColors.surfaceSecondary,
            foregroundColor: AppColors.primaryDark,
          ),
          child: Text(selected ? 'В плане ✓' : 'Добавить в план'),
        ),
      ],
    ),
  );
}

class _RepairItemCard extends StatelessWidget {
  const _RepairItemCard({
    required this.item,
    required this.price,
    required this.shopItems,
    required this.now,
    required this.enabled,
    required this.onChanged,
  });
  final DayFiveTaskItem item;
  final int price;
  final Map<String, ShopItem> shopItems;
  final bool now;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => TaskSurface(
    key: Key('plan-repair-item-${item.id}'),
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TaskItemArt(
              taskItemId: item.id,
              label: item.label,
              shopItems: shopItems,
              size: 70,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TaskCoinAmount(text: '$price', coinSize: 18, fontSize: 16),
                  Text(
                    item.context,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final choice in [true, false]) ...[
              if (!choice) const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  key: Key(
                    'plan-repair-${choice ? 'now' : 'later'}-${item.id}',
                  ),
                  onPressed: enabled ? () => onChanged(choice) : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: choice == now
                        ? (choice ? AppColors.need : AppColors.want)
                        : AppColors.surfaceSecondary,
                    foregroundColor: choice == now
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                  child: Text(choice ? 'Сейчас' : 'Потом'),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _SavingsStepper extends StatelessWidget {
  const _SavingsStepper({
    required this.amount,
    required this.minimum,
    required this.enabled,
    required this.onChanged,
  });
  final int amount;
  final int minimum;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => TaskSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'На финансовую цель',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          minimum == 10
              ? 'Сохрани минимум 10 монет на цель.'
              : 'Нужно отложить минимум $minimum монет',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TaskCoinAmount(
            key: const Key('day5-savings-amount'),
            text: '$amount',
            coinSize: 26,
            fontSize: 24,
          ),
        ),
        Center(
          child: TaskQuantityStepper(
            value: amount,
            decreaseKey: const Key('day5-savings-minus'),
            increaseKey: const Key('day5-savings-plus'),
            decreaseTooltip: 'Уменьшить на 10 монет',
            increaseTooltip: 'Увеличить на 10 монет',
            onDecrease: enabled && amount >= 10
                ? () => onChanged(amount - 10)
                : null,
            onIncrease: enabled ? () => onChanged(amount + 10) : null,
          ),
        ),
        Text(
          amount >= minimum
              ? 'Условие выполнено ✓'
              : 'Ещё нужно ${minimum - amount} монет',
          style: TextStyle(
            color: amount >= minimum ? AppColors.success : AppColors.warning,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _DayFiveFeedback extends StatelessWidget {
  const _DayFiveFeedback({required this.result, required this.failed});
  final TaskSubmissionResult? result;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final message = switch (result) {
      TaskDayFiveIncorrect(:final explanation) => explanation,
      TaskAnswerCompleted(:final explanation) => explanation,
      _ => failed ? 'Не удалось проверить план. Попробуй ещё раз.' : null,
    };
    if (message == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: TaskFeedbackPanel(
        title: result is TaskAnswerCompleted ? 'Отлично!' : 'Проверь план',
        children: [Text(message, key: const Key('day5-task-feedback'))],
      ),
    );
  }
}

class _CheckBar extends StatelessWidget {
  const _CheckBar({
    required this.completed,
    required this.submitting,
    required this.onCheck,
    required this.onReturn,
    required this.keyPrefix,
  });
  final bool completed;
  final bool submitting;
  final VoidCallback onCheck;
  final VoidCallback onReturn;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: TaskPrimaryButton(
      keyName: '$keyPrefix-check',
      onPressed: submitting
          ? null
          : completed
          ? onReturn
          : onCheck,
      label: completed
          ? 'Продолжить'
          : submitting
          ? 'Проверяем…'
          : 'Проверить план',
    ),
  );
}
