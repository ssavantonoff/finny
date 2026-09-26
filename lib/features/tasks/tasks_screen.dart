import 'dart:async';
import 'dart:math';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/features/tasks/budget_priority_task_screen.dart';
import 'package:finny/features/tasks/day_five_task_screens.dart';
import 'package:finny/features/tasks/plan_adaptation_task_screen.dart';
import 'package:finny/features/tasks/shopping_trip_task_screen.dart';
import 'package:finny/features/tasks/tasks_controller.dart';
import 'package:finny/features/tasks/task_visual_components.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key, this.random});

  final Random? random;

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
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            const Positioned.fill(child: TaskBackdrop()),
            switch (state.load) {
              TasksLoad.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              TasksLoad.noProfile => const Center(
                child: Text('Профиль пока не выбран.'),
              ),
              TasksLoad.noCurrentDay => _Message(
                text: 'Сначала начни новый день вместе с Финни.',
                button: 'К Финни',
                onPressed: () => context.go('/home'),
              ),
              TasksLoad.freePlayCompleted => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.large),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Все задания выполнены!',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppSpacing.small),
                      Text(
                        'Ты прошёл все 5 дней и выполнил задания Финни.',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppSpacing.small),
                      Text('5 / 5 дней ✓'),
                      SizedBox(height: AppSpacing.small),
                      Text(
                        'Теперь можно играть, копить на цели и украшать дом Финни.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
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
              TasksLoad.ready => _TaskList(
                state: state,
                controller: controller,
                random: widget.random,
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.state, required this.controller, this.random});

  final TasksState state;
  final TasksController controller;
  final Random? random;

  @override
  Widget build(BuildContext context) {
    final required = state.tasks.where((task) => task.requiredForCheckpoint);
    final optional = state.tasks.where((task) => !task.requiredForCheckpoint);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.medium,
        AppSpacing.medium,
        AppSpacing.medium,
        AppTheme.homeContentNavigationClearance +
            MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        const Text(
          'Задания',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Учимся обращаться с монетами вместе с Финни',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.large),
        Align(
          alignment: Alignment.centerLeft,
          child: TaskDayBadge(day: state.period!.periodNumber),
        ),
        const SizedBox(height: AppSpacing.medium),
        Text(
          required.length > 1 ? 'Главные задания' : 'Главное задание',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        if (state.legacyDayFiveCompleted)
          const TaskSurface(
            child: Text('Финансовое задание этого дня уже выполнено.'),
          )
        else
          for (final task in required)
            _TaskCard(
              task: task,
              state: state,
              controller: controller,
              random: random,
            ),
        if (optional.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.medium),
          const Text(
            'Дополнительное задание',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final task in optional)
            _TaskCard(
              task: task,
              state: state,
              controller: controller,
              random: random,
            ),
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
    this.random,
  });

  final FinancialTask task;
  final TasksState state;
  final TasksController controller;
  final Random? random;

  @override
  Widget build(BuildContext context) {
    final completed = state.isCompleted(task);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: TaskSurface(
        key: Key('task-card-${task.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              task.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              task.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            TaskCoinAmount(text: '+${task.reward}', coinSize: 25),
            const SizedBox(height: AppSpacing.small),
            if (completed)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'Выполнено ✓',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else
              FilledButton(
                key: Key('task-open-${task.id}'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: completed || state.submittingTaskId != null
                    ? null
                    : () {
                        if (task.type == 'independent_budget') {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => IndependentBudgetTaskScreen(
                                task: task,
                                controller: controller,
                                shopItems: state.shopItems,
                              ),
                            ),
                          );
                          return;
                        }
                        if (task.type == 'plan_repair') {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => PlanRepairTaskScreen(
                                task: task,
                                controller: controller,
                                shopItems: state.shopItems,
                              ),
                            ),
                          );
                          return;
                        }
                        if (task.type == 'shopping_trip') {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => ShoppingTripTaskScreen(
                                task: task,
                                controller: controller,
                                random: random,
                              ),
                            ),
                          );
                          return;
                        }
                        if (task.type == 'budget_priority') {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => BudgetPriorityTaskScreen(
                                task: task,
                                controller: controller,
                                shopItems: state.shopItems,
                              ),
                            ),
                          );
                          return;
                        }
                        if (task.type == 'categorization') {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => _CategorizationTaskScreen(
                                task: task,
                                controller: controller,
                                random: random,
                                shopItems: state.shopItems,
                              ),
                            ),
                          );
                          return;
                        }
                        if (task.type == 'plan_adaptation') {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => PlanAdaptationTaskScreen(
                                task: task,
                                controller: controller,
                                shopItems: state.shopItems,
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
                child: const Text('Выполнить'),
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
    required this.shopItems,
    this.random,
  });

  final FinancialTask task;
  final TasksController controller;
  final Map<String, ShopItem> shopItems;
  final Random? random;

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
  late final List<CategorizationTaskItem> shuffledItems;

  CategorizationTaskScenario get scenario => widget.task.categorizationScenario;

  @override
  void initState() {
    super.initState();
    shuffledItems = [...scenario.items]..shuffle(widget.random ?? Random());
    if (_sameOrder(shuffledItems, scenario.items) && shuffledItems.length > 1) {
      final first = shuffledItems.removeAt(0);
      shuffledItems.add(first);
    }
  }

  bool _sameOrder(
    List<CategorizationTaskItem> left,
    List<CategorizationTaskItem> right,
  ) {
    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id) return false;
    }
    return true;
  }

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

  void _removeItem(String itemId) {
    if (submitting || completed) return;
    setState(() {
      assignments.remove(itemId);
      selectedItemId = null;
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
                      description: 'Помоги Финни понять, что ему действительно нужно, а что можно купить позже.',
                      onClose: submitting ? null : () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 16),
                    if (result case TaskAnswerCompleted(:final explanation))
                      TaskSuccessPanel(
                        reward: widget.task.reward,
                        explanation: explanation,
                        titleKey: const Key('categorization-success-title'),
                        rewardKey: const Key('categorization-reward'),
                      )
                    else ...[
                      Text(
                        'Перетащи карточку или нажми на неё, а затем выбери категорию.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final category in scenario.categories) ...[
                            if (category != scenario.categories.first)
                              const SizedBox(width: 8),
                            Expanded(child: _buildCategory(category)),
                          ],
                        ],
                      ),
                      if (assignments.length < scenario.items.length) ...[
                        const SizedBox(height: 16),
                        TaskUnresolvedSection(
                          title: 'Осталось распределить',
                          children: [
                            for (final item in shuffledItems)
                              if (!assignments.containsKey(item.id))
                                _buildDraggableItem(item, compact: false),
                          ],
                        ),
                      ],
                      if (result is TaskCategorizationIncorrect) ...[
                        const SizedBox(height: 16),
                        TaskFeedbackPanel(
                          title: 'Почти получилось!',
                          titleKey: const Key('categorization-incorrect-title'),
                          children: [
                            for (final item in shuffledItems)
                              if (incorrectItemIds.contains(item.id))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${item.label}: ${item.feedback}',
                                    key: Key(
                                      'categorization-feedback-${item.id}',
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
                      ? 'categorization-continue'
                      : 'categorization-check',
                  label: completed
                      ? 'Продолжить'
                      : submitting
                      ? 'Проверяем…'
                      : 'Проверить',
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

  Widget _buildCategory(CategorizationTaskCategory category) =>
      DragTarget<String>(
        onWillAcceptWithDetails: (_) => !submitting && !completed,
        onAcceptWithDetails: (details) => _moveItem(details.data, category.id),
        builder: (context, candidates, rejected) => TaskDecisionZone(
          zoneKey: Key('categorization-zone-${category.id}'),
          title: category.label,
          description: category.id == 'need'
              ? 'То, без чего сегодня трудно обойтись.'
              : 'То, что приятно, но можно купить позже.',
          icon: category.id == 'need'
              ? Icons.shopping_bag_rounded
              : Icons.favorite_rounded,
          color: category.id == 'need' ? AppColors.need : AppColors.want,
          highlighted: candidates.isNotEmpty || selectedItemId != null,
          onTap: submitting || completed
              ? null
              : () => _placeSelected(category.id),
          children: [
            for (final item in shuffledItems)
              if (assignments[item.id] == category.id)
                _buildDraggableItem(item, compact: true),
          ],
        ),
      );

  Widget _buildDraggableItem(
    CategorizationTaskItem item, {
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
    CategorizationTaskItem item, {
    required bool compact,
    bool dragging = false,
  }) => TaskItemTile(
    itemId: item.id,
    label: item.label,
    shopItems: widget.shopItems,
    compact: compact,
    selected: selectedItemId == item.id,
    incorrect: incorrectItemIds.contains(item.id),
    tileKey: dragging ? null : Key('categorization-item-${item.id}'),
    onTap: dragging || submitting || completed
        ? null
        : () => _selectItem(item.id),
    onRemove: dragging || !compact || submitting || completed
        ? null
        : () => _removeItem(item.id),
  );
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
