import 'dart:async';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/features/tasks/tasks_controller.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(ref.read(tasksControllerProvider.notifier).load);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasksControllerProvider);
    final controller = ref.read(tasksControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Задания')),
      body: SafeArea(
        child: switch (state.load) {
          TasksLoad.loading => const Center(child: CircularProgressIndicator()),
          TasksLoad.noProfile => const Center(
            child: Text('Профиль пока не выбран.'),
          ),
          TasksLoad.noCurrentDay => _Message(
            text: 'Сначала начни новый день вместе с Финни.',
            button: 'К Финни',
            onPressed: () => context.go('/home'),
          ),
          TasksLoad.planning => _Message(
            text: 'Сначала закончи план на этот день.',
            button: 'К плану',
            onPressed: () => context.go('/budget'),
          ),
          TasksLoad.contentFailure => _Message(
            text: 'Не получилось загрузить задания. Попробуй ещё раз.',
            button: 'Попробовать ещё раз',
            onPressed: controller.load,
          ),
          TasksLoad.runtimeFailure => _Message(
            text: 'Не получилось открыть задания. Попробуй ещё раз.',
            button: 'Попробовать ещё раз',
            onPressed: controller.load,
          ),
          TasksLoad.ready => _TaskList(state: state, controller: controller),
        },
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.state, required this.controller});

  final TasksState state;
  final TasksController controller;

  @override
  Widget build(BuildContext context) {
    final required = state.tasks.where((task) => task.requiredForCheckpoint);
    final optional = state.tasks.where((task) => !task.requiredForCheckpoint);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Text(
          'Задания дня ${state.period!.periodNumber}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.medium),
        const Text('Главное задание'),
        for (final task in required)
          _TaskCard(task: task, state: state, controller: controller),
        if (optional.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.medium),
          const Text('Дополнительное задание'),
          for (final task in optional)
            _TaskCard(task: task, state: state, controller: controller),
        ],
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.state,
    required this.controller,
  });

  final FinancialTask task;
  final TasksState state;
  final TasksController controller;

  @override
  Widget build(BuildContext context) {
    final completed = state.isCompleted(task);
    return Card(
      key: Key('task-card-${task.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(task.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(task.description),
            const SizedBox(height: AppSpacing.small),
            Text('+${task.reward} монет'),
            const SizedBox(height: AppSpacing.small),
            FilledButton(
              key: Key('task-open-${task.id}'),
              onPressed: completed || state.submittingTaskId != null
                  ? null
                  : () {
                      if (task.type == 'categorization') {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (_) => _CategorizationTaskScreen(
                              task: task,
                              controller: controller,
                            ),
                          ),
                        );
                        return;
                      }
                      showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) =>
                            _TaskDialog(task: task, controller: controller),
                      );
                    },
              child: Text(completed ? 'Выполнено ✓' : 'Выполнить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskDialog extends ConsumerStatefulWidget {
  const _TaskDialog({required this.task, required this.controller});

  final FinancialTask task;
  final TasksController controller;

  @override
  ConsumerState<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends ConsumerState<_TaskDialog> {
  String? selected;
  TaskSubmissionResult? result;
  bool submitting = false;
  bool failed = false;

  Future<void> _submit() async {
    if (selected == null || submitting) return;
    setState(() {
      submitting = true;
      failed = false;
    });
    try {
      final submitted = await widget.controller.submit(widget.task, selected!);
      if (mounted) setState(() => result = submitted);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = result is TaskAnswerCompleted;
    return AlertDialog(
      title: Text(widget.task.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.task.choiceScenario.prompt),
            const SizedBox(height: AppSpacing.small),
            if (result == null)
              RadioGroup<String>(
                groupValue: selected,
                onChanged: submitting
                    ? (_) {}
                    : (value) => setState(() => selected = value),
                child: Column(
                  children: [
                    for (final option in widget.task.choiceScenario.options)
                      RadioListTile<String>(
                        value: option.id,
                        enabled: !submitting,
                        title: Text(option.label),
                      ),
                  ],
                ),
              ),
            if (result case TaskAnswerIncorrect(:final explanation)) ...[
              const Text('Пока не совсем.'),
              Text(explanation),
            ],
            if (result case TaskAnswerCompleted(:final explanation)) ...[
              const Text('Верно!'),
              Text('+${widget.task.reward} монет'),
              Text(explanation),
            ],
            if (failed)
              const Text('Не получилось выполнить действие. Попробуй ещё раз.'),
          ],
        ),
      ),
      actions: [
        if (result == null)
          FilledButton(
            key: const Key('task-submit'),
            onPressed: selected == null || submitting ? null : _submit,
            child: Text(submitting ? 'Проверяем…' : 'Ответить'),
          )
        else if (completed)
          FilledButton(
            onPressed: () {
              final refreshDayFour =
                  widget.task.period == 4 && widget.task.requiredForCheckpoint;
              Navigator.pop(context);
              if (refreshDayFour) {
                context.go('/home');
                unawaited(ref.read(homeControllerProvider.notifier).load());
              }
            },
            child: const Text('Готово'),
          )
        else
          FilledButton(
            onPressed: () => setState(() {
              result = null;
              selected = null;
            }),
            child: const Text('Попробовать ещё раз'),
          ),
      ],
    );
  }
}

class _CategorizationTaskScreen extends StatefulWidget {
  const _CategorizationTaskScreen({
    required this.task,
    required this.controller,
  });

  final FinancialTask task;
  final TasksController controller;

  @override
  State<_CategorizationTaskScreen> createState() =>
      _CategorizationTaskScreenState();
}

class _CategorizationTaskScreenState extends State<_CategorizationTaskScreen> {
  final Map<String, String> assignments = {};
  String? selectedItemId;
  TaskSubmissionResult? result;
  bool submitting = false;
  bool failed = false;

  CategorizationTaskScenario get scenario => widget.task.categorizationScenario;

  Set<String> get incorrectItemIds => switch (result) {
    TaskCategorizationIncorrect(:final incorrectItemIds) => incorrectItemIds,
    _ => const {},
  };

  bool get completed => result is TaskAnswerCompleted;

  void _selectItem(String itemId) {
    if (submitting || completed) return;
    setState(() {
      selectedItemId = selectedItemId == itemId ? null : itemId;
      result = null;
      failed = false;
    });
  }

  void _moveItem(String itemId, String categoryId) {
    if (submitting || completed) return;
    setState(() {
      assignments[itemId] = categoryId;
      selectedItemId = null;
      result = null;
      failed = false;
    });
  }

  void _placeSelected(String categoryId) {
    final itemId = selectedItemId;
    if (itemId != null) _moveItem(itemId, categoryId);
  }

  Future<void> _check() async {
    if (assignments.length != scenario.items.length || submitting) return;
    setState(() {
      submitting = true;
      failed = false;
    });
    try {
      final submitted = await widget.controller.submitCategorization(
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
    key: const Key('categorization-task-screen'),
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
          Text(scenario.prompt, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.small),
          Text(
            'Перетащи карточку или нажми на неё, а затем выбери категорию.',
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
                for (final item in scenario.items)
                  if (!assignments.containsKey(item.id))
                    _buildDraggableItem(context, item),
              ],
            ),
            const SizedBox(height: AppSpacing.medium),
          ],
          for (final category in scenario.categories) ...[
            _buildCategory(context, category),
            const SizedBox(height: AppSpacing.medium),
          ],
          if (result is TaskCategorizationIncorrect) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                'Почти получилось!',
                key: const Key('categorization-incorrect-title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            for (final item in scenario.items)
              if (incorrectItemIds.contains(item.id))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.small),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: AppSpacing.small),
                      Expanded(
                        child: Text(
                          '${item.label}: ${item.feedback}',
                          key: Key('categorization-feedback-${item.id}'),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
          if (result case TaskAnswerCompleted(:final explanation)) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                'Отлично!',
                key: const Key('categorization-success-title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              '+${widget.task.reward} монет',
              key: const Key('categorization-reward'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(explanation),
          ],
          if (failed)
            const Text('Не получилось выполнить действие. Попробуй ещё раз.'),
          const SizedBox(height: AppSpacing.small),
          if (completed)
            FilledButton(
              key: const Key('categorization-continue'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Продолжить'),
            )
          else
            FilledButton(
              key: const Key('categorization-check'),
              onPressed:
                  assignments.length == scenario.items.length && !submitting
                  ? _check
                  : null,
              child: Text(submitting ? 'Проверяем…' : 'Проверить'),
            ),
        ],
      ),
    ),
  );

  Widget _buildCategory(
    BuildContext context,
    CategorizationTaskCategory category,
  ) => DragTarget<String>(
    onWillAcceptWithDetails: (_) => !submitting && !completed,
    onAcceptWithDetails: (details) => _moveItem(details.data, category.id),
    builder: (context, candidates, rejected) {
      final highlighted = candidates.isNotEmpty || selectedItemId != null;
      return InkWell(
        key: Key('categorization-zone-${category.id}'),
        onTap: submitting || completed
            ? null
            : () => _placeSelected(category.id),
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
              Text(
                category.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(category.description),
              const SizedBox(height: AppSpacing.small),
              Wrap(
                spacing: AppSpacing.small,
                runSpacing: AppSpacing.small,
                children: [
                  for (final item in scenario.items)
                    if (assignments[item.id] == category.id)
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
    CategorizationTaskItem item,
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
    CategorizationTaskItem item, {
    bool dragging = false,
  }) {
    final selected = selectedItemId == item.id;
    final incorrect = incorrectItemIds.contains(item.id);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        key: dragging ? null : Key('categorization-item-${item.id}'),
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
              Flexible(child: Text(item.label)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.button,
    required this.onPressed,
  });

  final String text;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.large),
          FilledButton(onPressed: onPressed, child: Text(button)),
        ],
      ),
    ),
  );
}
