import 'dart:math';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/tasks/tasks_controller.dart';
import 'package:finny/features/tasks/task_visual_components.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:flutter/material.dart';

class PlanAdaptationTaskScreen extends StatefulWidget {
  const PlanAdaptationTaskScreen({
    super.key,
    required this.task,
    required this.controller,
    this.shopItems = const {},
    this.random,
  });

  final FinancialTask task;
  final TasksController controller;
  final Map<String, ShopItem> shopItems;
  final Random? random;

  @override
  State<PlanAdaptationTaskScreen> createState() =>
      _PlanAdaptationTaskScreenState();
}

class _PlanAdaptationTaskScreenState extends State<PlanAdaptationTaskScreen> {
  final Map<String, String> assignments = {};
  String? selectedItemId;
  TaskSubmissionResult? result;
  bool submitting = false;
  bool failed = false;
  late List<PlanAdaptationTaskItem> shuffledItems;

  PlanAdaptationTaskScenario get scenario => widget.task.planAdaptationScenario;

  Set<String> get incorrectItemIds => switch (result) {
    TaskPlanAdaptationIncorrect(:final incorrectItemIds) => incorrectItemIds,
    _ => const {},
  };

  bool get completed => result is TaskAnswerCompleted;

  @override
  void initState() {
    super.initState();
    shuffledItems = [...scenario.items];
    final random = widget.random ?? Random();
    shuffledItems.shuffle(random);
    if (_sameOrder(shuffledItems, scenario.items) && shuffledItems.length > 1) {
      final first = shuffledItems.removeAt(0);
      shuffledItems.add(first);
    }
    for (final item in shuffledItems) {
      assignments[item.id] = PlanAdaptationDecision.keep.wireValue;
    }
  }

  bool _sameOrder(
    List<PlanAdaptationTaskItem> left,
    List<PlanAdaptationTaskItem> right,
  ) {
    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id) return false;
    }
    return true;
  }

  void _selectItem(String itemId) {
    if (submitting || completed) return;
    setState(() {
      selectedItemId = selectedItemId == itemId ? null : itemId;
      result = null;
      failed = false;
    });
  }

  void _moveItem(String itemId, String decision) {
    if (submitting || completed) return;
    setState(() {
      assignments[itemId] = decision;
      selectedItemId = null;
      result = null;
      failed = false;
    });
  }

  void _placeSelected(String decision) {
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
      final submitted = await widget.controller.submitPlanAdaptation(
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
  Widget build(BuildContext context) {
    final currentKeepTotal = scenario.items
        .where(
          (item) =>
              assignments[item.id] == PlanAdaptationDecision.keep.wireValue,
        )
        .fold<int>(0, (total, item) => total + item.price);
    return Scaffold(
      key: const Key('plan-adaptation-task-screen'),
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
                        description: 'По дороге потерялись монеты. Измени готовый план и сохрани важное для Финни.',
                        onClose: submitting
                            ? null
                            : () => Navigator.pop(context),
                      ),
                      const SizedBox(height: 16),
                      if (result case TaskAnswerCompleted(:final explanation))
                        TaskSuccessPanel(
                          reward: widget.task.reward,
                          explanation: explanation,
                          titleKey: const Key('plan-adaptation-success-title'),
                          rewardKey: const Key('plan-adaptation-reward'),
                        )
                      else ...[
                        TaskSurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ситуация изменилась',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Исходный план: ${scenario.originalPlan} монет',
                              ),
                              Text(
                                'Потерялось: −${scenario.lostAmount} монет',
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                'Теперь доступно: ${scenario.availableBudget} монет',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _BudgetSummary(
                          scenario: scenario,
                          currentKeepTotal: currentKeepTotal,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Перетащи карточку или нажми на неё, а затем выбери зону.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildZone(
                                decision: PlanAdaptationDecision.keep.wireValue,
                                label: scenario.keepLabel,
                                description: scenario.keepDescription,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildZone(
                                decision:
                                    PlanAdaptationDecision.later.wireValue,
                                label: scenario.laterLabel,
                                description: scenario.laterDescription,
                              ),
                            ),
                          ],
                        ),
                        if (result case TaskPlanAdaptationIncorrect(
                          :final explanation,
                          :final overBudgetBy,
                        )) ...[
                          const SizedBox(height: 16),
                          TaskFeedbackPanel(
                            title: 'Проверь план',
                            titleKey: const Key(
                              'plan-adaptation-incorrect-title',
                            ),
                            children: [
                              if (overBudgetBy > 0)
                                Text(
                                  'Не хватает $overBudgetBy монет.',
                                  key: const Key('plan-adaptation-over-budget'),
                                ),
                              Text(
                                explanation,
                                key: const Key(
                                  'plan-adaptation-incorrect-explanation',
                                ),
                              ),
                              for (final item in scenario.items)
                                if (incorrectItemIds.contains(item.id))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '${item.label}: ${item.feedback}',
                                      key: Key(
                                        'plan-adaptation-feedback-${item.id}',
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
                        ? 'plan-adaptation-continue'
                        : 'plan-adaptation-check',
                    label: completed
                        ? 'Продолжить'
                        : submitting
                        ? 'Проверяем…'
                        : 'Проверить решение',
                    onPressed: completed
                        ? () => Navigator.pop(context)
                        : !submitting
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
  }

  Widget _buildZone({
    required String decision,
    required String label,
    required String description,
  }) => DragTarget<String>(
    onWillAcceptWithDetails: (_) => !submitting && !completed,
    onAcceptWithDetails: (details) => _moveItem(details.data, decision),
    builder: (context, candidates, rejected) {
      return TaskDecisionZone(
        zoneKey: Key('plan-adaptation-zone-$decision'),
        title: label,
        description: description,
        icon: decision == PlanAdaptationDecision.keep.wireValue
            ? Icons.shopping_bag_rounded
            : Icons.favorite_rounded,
        color: decision == PlanAdaptationDecision.keep.wireValue
            ? AppColors.need
            : AppColors.want,
        highlighted: candidates.isNotEmpty || selectedItemId != null,
        onTap: submitting || completed ? null : () => _placeSelected(decision),
        children: [
          if (selectedItemId != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                key: Key('plan-adaptation-place-$decision'),
                onPressed: submitting || completed
                    ? null
                    : () => _placeSelected(decision),
                child: const Text('Поместить'),
              ),
            ),
          for (final item in shuffledItems)
            if (assignments[item.id] == decision)
              _buildDraggableItem(context, item),
        ],
      );
    },
  );

  Widget _buildDraggableItem(
    BuildContext context,
    PlanAdaptationTaskItem item,
  ) => Draggable<String>(
    data: item.id,
    maxSimultaneousDrags: submitting || completed ? 0 : 1,
    feedback: Material(
      color: Colors.transparent,
      child: SizedBox(width: 150, child: _buildItemCard(item, dragging: true)),
    ),
    childWhenDragging: Opacity(
      opacity: 0.35,
      child: _buildItemCard(item, dragging: true),
    ),
    child: _buildItemCard(item),
  );

  Widget _buildItemCard(PlanAdaptationTaskItem item, {bool dragging = false}) =>
      TaskItemTile(
        itemId: item.id,
        label: item.label,
        price: item.price,
        shopItems: widget.shopItems,
        compact: true,
        selected: selectedItemId == item.id,
        incorrect: incorrectItemIds.contains(item.id),
        tileKey: dragging ? null : Key('plan-adaptation-item-${item.id}'),
        onTap: dragging || submitting || completed
            ? null
            : () => _selectItem(item.id),
      );
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({
    required this.scenario,
    required this.currentKeepTotal,
  });

  final PlanAdaptationTaskScenario scenario;
  final int currentKeepTotal;

  @override
  Widget build(BuildContext context) => TaskSurface(
    key: const Key('plan-adaptation-budget-summary'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Текущий план',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 8),
        Text('Сейчас в плане: $currentKeepTotal монет'),
        if (currentKeepTotal > scenario.availableBudget)
          Text(
            'Нужно сократить план на '
            '${currentKeepTotal - scenario.availableBudget} монет',
          )
        else
          Text(
            'Свободно: ${scenario.availableBudget - currentKeepTotal} монет',
          ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (currentKeepTotal / scenario.availableBudget)
                .clamp(0, 1)
                .toDouble(),
            minHeight: 9,
            backgroundColor: AppColors.primaryLight,
            color: currentKeepTotal > scenario.availableBudget
                ? AppColors.warning
                : AppColors.primary,
          ),
        ),
      ],
    ),
  );
}
