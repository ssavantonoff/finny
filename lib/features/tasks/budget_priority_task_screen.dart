import 'dart:math';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/tasks/tasks_controller.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:flutter/material.dart';

class BudgetPriorityTaskScreen extends StatefulWidget {
  const BudgetPriorityTaskScreen({
    required this.task,
    required this.controller,
    this.random,
    super.key,
  });

  final FinancialTask task;
  final TasksController controller;
  final Random? random;

  @override
  State<BudgetPriorityTaskScreen> createState() =>
      _BudgetPriorityTaskScreenState();
}

class _BudgetPriorityTaskScreenState extends State<BudgetPriorityTaskScreen> {
  final Map<String, String> assignments = {};
  late final List<BudgetPriorityTaskItem> displayItems;
  String? selectedItemId;
  String? budgetError;
  TaskSubmissionResult? result;
  bool submitting = false;
  bool failed = false;

  BudgetPriorityTaskScenario get scenario => widget.task.budgetPriorityScenario;

  Set<String> get incorrectItemIds => switch (result) {
    TaskBudgetPriorityIncorrect(:final incorrectItemIds) => incorrectItemIds,
    _ => const {},
  };

  bool get completed => result is TaskAnswerCompleted;

  int get buyNowTotal => scenario.items
      .where(
        (item) =>
            assignments[item.id] == BudgetPriorityDecision.buyNow.wireValue,
      )
      .fold(0, (total, item) => total + item.price);

  int get remaining => max(0, scenario.budget - buyNowTotal);

  @override
  void initState() {
    super.initState();
    displayItems = List<BudgetPriorityTaskItem>.of(scenario.items)
      ..shuffle(widget.random ?? Random());
    if (displayItems.length > 1 &&
        List.generate(
          displayItems.length,
          (index) => displayItems[index].id == scenario.items[index].id,
        ).every((same) => same)) {
      displayItems.add(displayItems.removeAt(0));
    }
  }

  void _selectItem(String itemId) {
    if (submitting || completed) return;
    setState(() {
      selectedItemId = selectedItemId == itemId ? null : itemId;
      failed = false;
    });
  }

  bool _moveItem(String itemId, BudgetPriorityDecision decision) {
    if (submitting || completed) return false;
    final item = scenario.items.singleWhere((entry) => entry.id == itemId);
    if (decision == BudgetPriorityDecision.buyNow) {
      final totalWithoutItem = scenario.items
          .where(
            (entry) =>
                entry.id != itemId &&
                assignments[entry.id] ==
                    BudgetPriorityDecision.buyNow.wireValue,
          )
          .fold<int>(0, (total, entry) => total + entry.price);
      final attemptedTotal = totalWithoutItem + item.price;
      if (attemptedTotal > scenario.budget) {
        setState(() {
          budgetError =
              'Не хватает ${attemptedTotal - scenario.budget} монет. Попробуй изменить выбор.';
          failed = false;
        });
        return false;
      }
    }
    setState(() {
      assignments[itemId] = decision.wireValue;
      selectedItemId = null;
      budgetError = null;
      result = null;
      failed = false;
    });
    return true;
  }

  void _placeSelected(BudgetPriorityDecision decision) {
    final itemId = selectedItemId;
    if (itemId != null) _moveItem(itemId, decision);
  }

  Future<void> _check() async {
    if (assignments.length != scenario.items.length || submitting) return;
    setState(() {
      submitting = true;
      failed = false;
    });
    try {
      final submitted = await widget.controller.submitBudgetPriority(
        widget.task,
        Map.unmodifiable(assignments),
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
    key: const Key('budget-priority-task-screen'),
    appBar: AppBar(
      title: Text(widget.task.title),
      leading: IconButton(
        tooltip: 'Закрыть',
        onPressed: submitting ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.close),
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.medium,
              AppSpacing.small,
              AppSpacing.medium,
              AppSpacing.small,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Бюджет задания: ${scenario.budget} монет',
                  key: const Key('budget-priority-budget'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Осталось: $remaining монет',
                  key: const Key('budget-priority-remaining'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Это бюджет только для задания.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: [
                Text(
                  scenario.prompt,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  'Перетащи покупку или нажми на неё, а затем выбери решение.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.medium),
                if (assignments.length < scenario.items.length) ...[
                  Text(
                    'Покупки',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Wrap(
                    spacing: AppSpacing.small,
                    runSpacing: AppSpacing.small,
                    children: [
                      for (final item in displayItems)
                        if (!assignments.containsKey(item.id))
                          _buildDraggableItem(context, item),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
                _buildDecisionZone(
                  context,
                  BudgetPriorityDecision.buyNow,
                  scenario.buyNowLabel,
                  scenario.buyNowDescription,
                ),
                const SizedBox(height: AppSpacing.medium),
                _buildDecisionZone(
                  context,
                  BudgetPriorityDecision.later,
                  scenario.laterLabel,
                  scenario.laterDescription,
                ),
                if (budgetError case final message?) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: AppSpacing.small),
                        Expanded(
                          child: Text(
                            message,
                            key: const Key('budget-priority-budget-error'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (result case TaskBudgetPriorityIncorrect(
                  :final explanation,
                )) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Почти получилось!',
                      key: const Key('budget-priority-incorrect-title'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(explanation),
                  const SizedBox(height: AppSpacing.small),
                  for (final item in displayItems)
                    if (incorrectItemIds.contains(item.id))
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.small,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline),
                            const SizedBox(width: AppSpacing.small),
                            Expanded(
                              child: Text(
                                '${item.label}: ${item.feedback}',
                                key: Key('budget-priority-feedback-${item.id}'),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
                if (result case TaskAnswerCompleted(:final explanation)) ...[
                  const SizedBox(height: AppSpacing.medium),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Отлично!',
                      key: const Key('budget-priority-success-title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    '+${widget.task.reward} монет',
                    key: const Key('budget-priority-reward'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(explanation),
                ],
                if (failed) ...[
                  const SizedBox(height: AppSpacing.small),
                  const Text(
                    'Не получилось выполнить действие. Попробуй ещё раз.',
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.medium,
              AppSpacing.small,
              AppSpacing.medium,
              AppSpacing.medium,
            ),
            child: SizedBox(
              width: double.infinity,
              child: completed
                  ? FilledButton(
                      key: const Key('budget-priority-continue'),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Продолжить'),
                    )
                  : FilledButton(
                      key: const Key('budget-priority-check'),
                      onPressed:
                          assignments.length == scenario.items.length &&
                              !submitting
                          ? _check
                          : null,
                      child: Text(
                        submitting ? 'Проверяем…' : 'Проверить решение',
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildDecisionZone(
    BuildContext context,
    BudgetPriorityDecision decision,
    String label,
    String description,
  ) => DragTarget<String>(
    onWillAcceptWithDetails: (_) => !submitting && !completed,
    onAcceptWithDetails: (details) => _moveItem(details.data, decision),
    builder: (context, candidates, rejected) {
      final highlighted = candidates.isNotEmpty || selectedItemId != null;
      return InkWell(
        key: Key('budget-priority-zone-${decision.wireValue}'),
        onTap: submitting || completed ? null : () => _placeSelected(decision),
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(AppSpacing.medium),
          decoration: BoxDecoration(
            color: highlighted
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              width: candidates.isNotEmpty ? 3 : 1,
              color: candidates.isNotEmpty
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(description),
              const SizedBox(height: AppSpacing.small),
              Wrap(
                spacing: AppSpacing.small,
                runSpacing: AppSpacing.small,
                children: [
                  for (final item in displayItems)
                    if (assignments[item.id] == decision.wireValue)
                      _buildDraggableItem(context, item),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _buildDraggableItem(
    BuildContext context,
    BudgetPriorityTaskItem item,
  ) => Draggable<String>(
    data: item.id,
    maxSimultaneousDrags: submitting || completed ? 0 : 1,
    feedback: Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: _buildItemCard(context, item, dragging: true),
      ),
    ),
    childWhenDragging: Opacity(
      opacity: 0.35,
      child: _buildItemCard(context, item),
    ),
    child: _buildItemCard(context, item),
  );

  Widget _buildItemCard(
    BuildContext context,
    BudgetPriorityTaskItem item, {
    bool dragging = false,
  }) {
    final selected = selectedItemId == item.id;
    final incorrect = incorrectItemIds.contains(item.id);
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${item.label}, ${item.price} монет${incorrect ? ', ошибка в решении' : ''}',
      child: InkWell(
        key: dragging ? null : Key('budget-priority-item-${item.id}'),
        onTap: dragging || submitting || completed
            ? null
            : () => _selectItem(item.id),
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.medium,
            vertical: AppSpacing.small,
          ),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.secondaryContainer
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(
              width: selected || incorrect ? 2 : 1,
              color: incorrect
                  ? Theme.of(context).colorScheme.error
                  : selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (incorrect) ...[
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 4),
              ] else if (selected) ...[
                const Icon(Icons.check_circle_outline, size: 18),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label),
                    Text(
                      '${item.price} монет',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
