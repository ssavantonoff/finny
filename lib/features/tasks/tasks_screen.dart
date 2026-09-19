import 'package:finny/core/theme/app_theme.dart';
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
                  : () => showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          _TaskDialog(task: task, controller: controller),
                    ),
              child: Text(completed ? 'Выполнено ✓' : 'Выполнить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({required this.task, required this.controller});

  final FinancialTask task;
  final TasksController controller;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
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
              Navigator.pop(context);
              if (widget.task.period == 4 &&
                  widget.task.requiredForCheckpoint) {
                context.go('/home');
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
