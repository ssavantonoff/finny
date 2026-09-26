import 'dart:math';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/tasks/tasks_controller.dart';
import 'package:finny/features/tasks/task_visual_components.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:flutter/material.dart';

class BudgetPriorityTaskScreen extends StatefulWidget {
  const BudgetPriorityTaskScreen({
    required this.task,
    required this.controller,
    required this.shopItems,
    this.random,
    super.key,
  });

  final FinancialTask task;
  final TasksController controller;
  final Map<String, ShopItem> shopItems;
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
          budgetError = 'Не хватает ${attemptedTotal - scenario.budget} монет';
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

  void _removeItem(String itemId) {
    if (submitting || completed) return;
    setState(() {
      assignments.remove(itemId);
      selectedItemId = null;
      budgetError = null;
      result = null;
      failed = false;
    });
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
    backgroundColor: AppColors.background,
    body: Stack(
      children: [
        const Positioned.fill(child: TaskBackdrop()),
        SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    TaskScreenHeader(
                      day: widget.task.period,
                      title: widget.task.title,
                      description:
                          'У Финни ${scenario.budget} монет. Выбери самое важное и уложись в бюджет.',
                      onClose: submitting ? null : () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 16),
                    if (result case TaskAnswerCompleted(:final explanation))
                      TaskSuccessPanel(
                        reward: widget.task.reward,
                        explanation: explanation,
                        titleKey: const Key('budget-priority-success-title'),
                        rewardKey: const Key('budget-priority-reward'),
                      )
                    else ...[
                      TaskBudgetPanel(
                        budget: scenario.budget,
                        remaining: remaining,
                        spent: buyNowTotal,
                        error: budgetError,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Это бюджет только для задания.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        scenario.prompt,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Перетащи покупку или нажми на неё, а затем выбери решение.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (assignments.length < scenario.items.length) ...[
                        const SizedBox(height: 16),
                        TaskUnresolvedSection(
                          title: 'Осталось решить',
                          children: [
                            for (final item in displayItems)
                              if (!assignments.containsKey(item.id))
                                _buildDraggableItem(item, compact: false),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildDecisionZone(
                              BudgetPriorityDecision.buyNow,
                              scenario.buyNowLabel,
                              'То, что Финни нужно сейчас.',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDecisionZone(
                              BudgetPriorityDecision.later,
                              scenario.laterLabel,
                              'То, что можно купить позже.',
                            ),
                          ),
                        ],
                      ),
                      if (result case TaskBudgetPriorityIncorrect(
                        :final explanation,
                      )) ...[
                        const SizedBox(height: 16),
                        TaskFeedbackPanel(
                          title: 'Почти получилось!',
                          titleKey: const Key(
                            'budget-priority-incorrect-title',
                          ),
                          children: [
                            Text(explanation),
                            for (final item in displayItems)
                              if (incorrectItemIds.contains(item.id))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${item.label}: ${item.feedback}',
                                    key: Key(
                                      'budget-priority-feedback-${item.id}',
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ],
                      if (failed) ...[
                        const SizedBox(height: 16),
                        const TaskFeedbackPanel(
                          title: 'Не получилось выполнить действие.',
                          children: [Text('Попробуй ещё раз.')],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TaskPrimaryButton(
                  keyName: completed
                      ? 'budget-priority-continue'
                      : 'budget-priority-check',
                  label: completed
                      ? 'Продолжить'
                      : submitting
                      ? 'Проверяем…'
                      : 'Проверить решение',
                  onPressed: completed
                      ? () => Navigator.pop(context)
                      : assignments.length == scenario.items.length &&
                            !submitting
                      ? _check
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildDecisionZone(
    BudgetPriorityDecision decision,
    String label,
    String description,
  ) => DragTarget<String>(
    onWillAcceptWithDetails: (_) => !submitting && !completed,
    onAcceptWithDetails: (details) => _moveItem(details.data, decision),
    builder: (context, candidates, rejected) => TaskDecisionZone(
      zoneKey: Key('budget-priority-zone-${decision.wireValue}'),
      title: label,
      description: description,
      icon: decision == BudgetPriorityDecision.buyNow
          ? Icons.shopping_cart_rounded
          : Icons.favorite_rounded,
      color: decision == BudgetPriorityDecision.buyNow
          ? AppColors.need
          : AppColors.want,
      highlighted: candidates.isNotEmpty || selectedItemId != null,
      onTap: submitting || completed ? null : () => _placeSelected(decision),
      children: [
        for (final item in displayItems)
          if (assignments[item.id] == decision.wireValue)
            _buildDraggableItem(item, compact: true),
      ],
    ),
  );

  Widget _buildDraggableItem(
    BudgetPriorityTaskItem item, {
    required bool compact,
  }) => Draggable<String>(
    data: item.id,
    maxSimultaneousDrags: submitting || completed ? 0 : 1,
    feedback: Material(
      color: Colors.transparent,
      child: SizedBox(
        width: compact ? 150 : 160,
        child: _buildItemCard(item, compact: compact, dragging: true),
      ),
    ),
    childWhenDragging: Opacity(
      opacity: 0.35,
      child: _buildItemCard(item, compact: compact, dragging: true),
    ),
    child: _buildItemCard(item, compact: compact),
  );

  Widget _buildItemCard(
    BudgetPriorityTaskItem item, {
    required bool compact,
    bool dragging = false,
  }) => TaskItemTile(
    itemId: item.id,
    label: item.label,
    price: item.price,
    shopItems: widget.shopItems,
    compact: compact,
    selected: selectedItemId == item.id,
    incorrect: incorrectItemIds.contains(item.id),
    tileKey: dragging ? null : Key('budget-priority-item-${item.id}'),
    onTap: dragging || submitting || completed
        ? null
        : () => _selectItem(item.id),
    onRemove: dragging || !compact || submitting || completed
        ? null
        : () => _removeItem(item.id),
  );
}
