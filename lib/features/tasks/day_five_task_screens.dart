import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/tasks/tasks_controller.dart';
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
      appBar: AppBar(title: Text(widget.task.title)),
      body: SafeArea(
        child: Column(
          children: [
            _DayFiveSummary(
              budget: scenario.budget,
              purchases: purchaseTotal,
              savings: savingsAmount,
              keyPrefix: 'independent-budget',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.medium),
                children: [
                  Text(
                    scenario.prompt,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  for (final item in scenario.items)
                    _BudgetItemCard(
                      item: item,
                      price: widget.shopItems[item.id]!.price,
                      selected: selectedIds.contains(item.id),
                      enabled: !submitting && result is! TaskAnswerCompleted,
                      onPressed: () => setState(() {
                        if (!selectedIds.add(item.id)) {
                          selectedIds.remove(item.id);
                        }
                        result = null;
                        failed = false;
                      }),
                    ),
                  const SizedBox(height: AppSpacing.medium),
                  _SavingsStepper(
                    amount: savingsAmount,
                    enabled: !submitting && result is! TaskAnswerCompleted,
                    onChanged: (value) => setState(() {
                      savingsAmount = value;
                      result = null;
                      failed = false;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  _DayFiveFeedback(result: result, failed: failed),
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
    appBar: AppBar(title: Text(widget.task.title)),
    body: SafeArea(
      child: Column(
        children: [
          _DayFiveSummary(
            budget: scenario.budget,
            purchases: purchaseTotal,
            savings: savingsAmount,
            keyPrefix: 'plan-repair',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: [
                Text(
                  scenario.prompt,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.small),
                Text(scenario.event),
                const SizedBox(height: AppSpacing.medium),
                for (final item in scenario.items)
                  _RepairItemCard(
                    item: item,
                    price: _price(item.id),
                    now: nowIds.contains(item.id),
                    enabled: !submitting && result is! TaskAnswerCompleted,
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
                const SizedBox(height: AppSpacing.medium),
                _SavingsStepper(
                  amount: savingsAmount,
                  enabled: !submitting && result is! TaskAnswerCompleted,
                  onChanged: (value) => setState(() {
                    savingsAmount = value;
                    result = null;
                    failed = false;
                  }),
                ),
                const SizedBox(height: AppSpacing.medium),
                _DayFiveFeedback(result: result, failed: failed),
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
    return Card(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.medium,
        AppSpacing.small,
        AppSpacing.medium,
        0,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.small,
              children: [
                Text('Бюджет: $budget'),
                Text(
                  '${purchases + savings} / $budget',
                  key: Key('$keyPrefix-total'),
                ),
                Text('Покупки: $purchases'),
                Text('На цель: $savings'),
                Text('Осталось: $remaining', key: Key('$keyPrefix-remaining')),
              ],
            ),
            if (remaining < 0)
              Text(
                'Не хватает ${-remaining} монет',
                key: Key('$keyPrefix-deficit'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}

class _BudgetItemCard extends StatelessWidget {
  const _BudgetItemCard({
    required this.item,
    required this.price,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });
  final DayFiveTaskItem item;
  final int price;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('independent-budget-item-${item.id}'),
    color: selected ? Theme.of(context).colorScheme.secondaryContainer : null,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${item.label} • $price 🪙',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(item.context),
          const SizedBox(height: AppSpacing.small),
          OutlinedButton(
            key: Key('independent-budget-toggle-${item.id}'),
            onPressed: enabled ? onPressed : null,
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(selected ? 'Убрать из плана' : 'Добавить в план'),
          ),
        ],
      ),
    ),
  );
}

class _RepairItemCard extends StatelessWidget {
  const _RepairItemCard({
    required this.item,
    required this.price,
    required this.now,
    required this.enabled,
    required this.onChanged,
  });
  final DayFiveTaskItem item;
  final int price;
  final bool now;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('plan-repair-item-${item.id}'),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${item.label} • $price 🪙',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(item.context),
          const SizedBox(height: AppSpacing.small),
          Wrap(
            spacing: AppSpacing.small,
            runSpacing: AppSpacing.small,
            children: [
              for (final choice in [true, false])
                choice == now
                    ? FilledButton(
                        key: Key(
                          'plan-repair-${choice ? 'now' : 'later'}-${item.id}',
                        ),
                        onPressed: enabled ? () => onChanged(choice) : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(96, 48),
                        ),
                        child: Text(choice ? 'Сейчас' : 'Потом'),
                      )
                    : OutlinedButton(
                        key: Key(
                          'plan-repair-${choice ? 'now' : 'later'}-${item.id}',
                        ),
                        onPressed: enabled ? () => onChanged(choice) : null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(96, 48),
                        ),
                        child: Text(choice ? 'Сейчас' : 'Потом'),
                      ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SavingsStepper extends StatelessWidget {
  const _SavingsStepper({
    required this.amount,
    required this.enabled,
    required this.onChanged,
  });
  final int amount;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('На цель', style: Theme.of(context).textTheme.titleMedium),
          Row(
            children: [
              IconButton(
                key: const Key('day5-savings-minus'),
                tooltip: 'Уменьшить на 10 монет',
                onPressed: enabled && amount >= 10
                    ? () => onChanged(amount - 10)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  '$amount 🪙',
                  key: const Key('day5-savings-amount'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                key: const Key('day5-savings-plus'),
                tooltip: 'Увеличить на 10 монет',
                onPressed: enabled ? () => onChanged(amount + 10) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
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
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Text(message, key: const Key('day5-task-feedback')),
        ),
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
    padding: const EdgeInsets.all(AppSpacing.medium),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: Key('$keyPrefix-check'),
        onPressed: submitting
            ? null
            : completed
            ? onReturn
            : onCheck,
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
        child: Text(
          completed
              ? 'К заданиям'
              : submitting
              ? 'Проверяем…'
              : 'Проверить план',
        ),
      ),
    ),
  );
}
