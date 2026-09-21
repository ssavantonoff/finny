import 'dart:math';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/tasks/tasks_controller.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:flutter/material.dart';

class PlanAdaptationTaskScreen extends StatefulWidget {
  const PlanAdaptationTaskScreen({
    super.key,
    required this.task,
    required this.controller,
    this.random,
  });

  final FinancialTask task;
  final TasksController controller;
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
  Widget build(BuildContext context) => Scaffold(
    key: const Key('plan-adaptation-task-screen'),
    appBar: AppBar(
      title: Text(widget.task.title),
      leading: IconButton(
        tooltip: 'Закрыть',
        onPressed: submitting ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.close),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: [
          _BudgetSummary(
            scenario: scenario,
            currentKeepTotal: scenario.items
                .where(
                  (item) =>
                      assignments[item.id] ==
                      PlanAdaptationDecision.keep.wireValue,
                )
                .fold<int>(0, (total, item) => total + item.price),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(scenario.prompt, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.small),
          Text(
            'Перетащи карточку или нажми на неё, а затем выбери зону.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.medium),
          if (assignments.length < scenario.items.length) ...[
            Text('Карточки', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.small),
            Wrap(
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.small,
              children: [
                for (final item in shuffledItems)
                  if (!assignments.containsKey(item.id))
                    _buildDraggableItem(context, item),
              ],
            ),
            const SizedBox(height: AppSpacing.medium),
          ],
          _buildZone(
            context,
            decision: PlanAdaptationDecision.keep.wireValue,
            label: scenario.keepLabel,
            description: scenario.keepDescription,
          ),
          const SizedBox(height: AppSpacing.medium),
          _buildZone(
            context,
            decision: PlanAdaptationDecision.later.wireValue,
            label: scenario.laterLabel,
            description: scenario.laterDescription,
          ),
          if (result is TaskPlanAdaptationIncorrect) ...[
            const SizedBox(height: AppSpacing.medium),
            Semantics(
              liveRegion: true,
              child: Text(
                'Проверь план',
                key: const Key('plan-adaptation-incorrect-title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (result case TaskPlanAdaptationIncorrect(:final overBudgetBy))
              if (overBudgetBy > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.small),
                  child: Text(
                    'Не хватает $overBudgetBy монет.',
                    key: const Key('plan-adaptation-over-budget'),
                  ),
                ),
            if (result case TaskPlanAdaptationIncorrect(:final explanation))
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.small),
                child: Text(
                  explanation,
                  key: const Key('plan-adaptation-incorrect-explanation'),
                ),
              ),
            for (final item in scenario.items)
              if (incorrectItemIds.contains(item.id))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.small),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: AppSpacing.small),
                      Expanded(
                        child: Text(
                          '${item.label}: ${item.feedback}',
                          key: Key('plan-adaptation-feedback-${item.id}'),
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
                key: const Key('plan-adaptation-success-title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text('+${widget.task.reward} монет'),
            const SizedBox(height: AppSpacing.small),
            Text(explanation),
          ],
          if (failed)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.small),
              child: Text(
                'Не получилось выполнить действие. Попробуй ещё раз.',
              ),
            ),
          const SizedBox(height: AppSpacing.small),
          if (completed)
            FilledButton(
              key: const Key('plan-adaptation-continue'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Продолжить'),
            )
          else
            FilledButton(
              key: const Key('plan-adaptation-check'),
              onPressed:
                  assignments.length == scenario.items.length && !submitting
                  ? _check
                  : null,
              child: Text(submitting ? 'Проверяем…' : 'Проверить решение'),
            ),
        ],
      ),
    ),
  );

  Widget _buildZone(
    BuildContext context, {
    required String decision,
    required String label,
    required String description,
  }) => DragTarget<String>(
    onWillAcceptWithDetails: (_) => !submitting && !completed,
    onAcceptWithDetails: (details) => _moveItem(details.data, decision),
    builder: (context, candidates, rejected) {
      final highlighted = candidates.isNotEmpty || selectedItemId != null;
      return InkWell(
        key: Key('plan-adaptation-zone-$decision'),
        onTap: submitting || completed ? null : () => _placeSelected(decision),
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 112),
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
              if (selectedItemId != null) ...[
                const SizedBox(height: AppSpacing.small),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    key: Key('plan-adaptation-place-$decision'),
                    onPressed: submitting || completed
                        ? null
                        : () => _placeSelected(decision),
                    child: Text('Поместить в «$label»'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.small),
              Wrap(
                spacing: AppSpacing.small,
                runSpacing: AppSpacing.small,
                children: [
                  for (final item in shuffledItems)
                    if (assignments[item.id] == decision)
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
    PlanAdaptationTaskItem item,
  ) => Draggable<String>(
    data: item.id,
    maxSimultaneousDrags: submitting || completed ? 0 : 1,
    feedback: Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
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
    PlanAdaptationTaskItem item, {
    bool dragging = false,
  }) {
    final selected = selectedItemId == item.id;
    return Semantics(
      button: true,
      selected: selected,
      label: '${item.label}, ${item.price} монет',
      child: InkWell(
        key: dragging ? null : Key('plan-adaptation-item-${item.id}'),
        onTap: dragging || submitting || completed
            ? null
            : () => _selectItem(item.id),
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
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
              color: selected
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Text('${item.label} · ${item.price} 🪙'),
        ),
      ),
    );
  }
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({
    required this.scenario,
    required this.currentKeepTotal,
  });

  final PlanAdaptationTaskScenario scenario;
  final int currentKeepTotal;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('plan-adaptation-budget-summary'),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'План и новая ситуация',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.small),
          Text('Исходный план: ${scenario.originalPlan} монет'),
          Text('Потерялось: ${scenario.lostAmount} монет'),
          Text('Теперь доступно: ${scenario.availableBudget} монет'),
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
        ],
      ),
    ),
  );
}
