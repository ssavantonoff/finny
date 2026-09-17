import 'dart:math' as math;

import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/budget/budget_controller.dart';
import 'package:finny/services/budget_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(ref.read(budgetControllerProvider.notifier).load);
  }

  Future<void> _leave() async {
    final controller = ref.read(budgetControllerProvider.notifier);
    await controller.waitForPendingSaves();
    if (!mounted) return;
    final current = ref.read(budgetControllerProvider);
    if (current is BudgetReady &&
        (current.saveFailed || !current.draftIsPersisted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала сохрани изменение или повтори попытку.'),
        ),
      );
      return;
    }
    context.go('/home');
  }

  Future<void> _confirm() async {
    final controller = ref.read(budgetControllerProvider.notifier);
    final allocation = await controller.prepareConfirmation();
    if (!mounted || allocation == null) return;
    final current = ref.read(budgetControllerProvider);
    if (current is! BudgetReady || !current.canConfirm) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ConfirmationSheet(
        allocation: allocation,
        remainder: allocation.remainderFor(current.period.startingBudget),
      ),
    );
    if (!mounted || confirmed != true) return;
    final succeeded = await controller.confirmPlan();
    if (mounted && succeeded) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(budgetControllerProvider);
    ref.listen<int?>(activeProfileIdProvider, (_, _) {
      ref.read(budgetControllerProvider.notifier).load();
    });
    if (state is BudgetNeedsBootstrap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/startup');
      });
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: switch (state) {
        BudgetLoading() || BudgetNeedsBootstrap() => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        BudgetFailure() => _BudgetError(
          onBack: _leave,
          onRetry: ref.read(budgetControllerProvider.notifier).load,
        ),
        BudgetReady() => _BudgetContent(
          state: state,
          onBack: _leave,
          onConfirm: _confirm,
        ),
      },
    );
  }
}

class _BudgetContent extends ConsumerWidget {
  const _BudgetContent({
    required this.state,
    required this.onBack,
    required this.onConfirm,
  });

  final BudgetReady state;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(budgetControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: Text(state.editable ? 'План на день' : 'Твой план'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'День ${state.period.periodNumber} • ${state.definition.title}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  _BudgetOriginCard(state: state),
                  const SizedBox(height: AppSpacing.large),
                  if (state.editable) ...[
                    _BudgetCategoryEditor(
                      key: const Key('budget-editor-need'),
                      title: 'Нужно Финни',
                      description: 'Важное для заботы о Финни.',
                      semanticName: 'Нужно Финни',
                      value: state.draft.need,
                      maximum: controller.maximumFor(
                        state,
                        BudgetCategory.need,
                      ),
                      onPreview: (value) =>
                          controller.previewValue(BudgetCategory.need, value),
                      onCommit: (value) =>
                          controller.setValue(BudgetCategory.need, value),
                      onSavePreview: controller.savePreview,
                    ),
                    _BudgetCategoryEditor(
                      key: const Key('budget-editor-want'),
                      title: 'Хочется Финни',
                      description: 'Приятные, но необязательные покупки.',
                      semanticName: 'Хочется Финни',
                      value: state.draft.want,
                      maximum: controller.maximumFor(
                        state,
                        BudgetCategory.want,
                      ),
                      onPreview: (value) =>
                          controller.previewValue(BudgetCategory.want, value),
                      onCommit: (value) =>
                          controller.setValue(BudgetCategory.want, value),
                      onSavePreview: controller.savePreview,
                    ),
                    _BudgetCategoryEditor(
                      key: const Key('budget-editor-savings'),
                      title: 'Копилка',
                      description: 'План, сколько хочется отложить позже.',
                      semanticName: 'Копилка',
                      value: state.draft.savings,
                      maximum: controller.maximumFor(
                        state,
                        BudgetCategory.savings,
                      ),
                      onPreview: (value) => controller.previewValue(
                        BudgetCategory.savings,
                        value,
                      ),
                      onCommit: (value) =>
                          controller.setValue(BudgetCategory.savings, value),
                      onSavePreview: controller.savePreview,
                    ),
                  ] else ...[
                    _ReadOnlyAmount('Нужно', state.period.plannedNeed),
                    _ReadOnlyAmount('Хочется', state.period.plannedWant),
                    _ReadOnlyAmount('Копилка', state.period.plannedSavings),
                  ],
                  const SizedBox(height: AppSpacing.small),
                  Card(
                    key: const Key('budget-remainder'),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.medium),
                      child: Row(
                        children: [
                          const Expanded(child: Text('Останется свободно')),
                          Text(
                            '${state.remainder} 🪙',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!state.editable) ...[
                    const SizedBox(height: AppSpacing.medium),
                    const Text(
                      'План подтверждён. Изменить его уже нельзя.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (state.saving) ...[
                    const SizedBox(height: AppSpacing.medium),
                    const LinearProgressIndicator(key: Key('budget-saving')),
                  ],
                  if (state.saveFailed) ...[
                    const SizedBox(height: AppSpacing.medium),
                    _MutationError(
                      message: 'Не получилось сохранить изменение',
                      onRetry: controller.retrySave,
                    ),
                  ],
                  if (state.confirmFailed) ...[
                    const SizedBox(height: AppSpacing.medium),
                    const _MutationError(
                      message:
                          'Не получилось подтвердить план. Попробуй ещё раз.',
                    ),
                  ],
                  if (state.editable) ...[
                    const SizedBox(height: AppSpacing.large),
                    FilledButton(
                      key: const Key('budget-confirm'),
                      onPressed: state.canConfirm ? onConfirm : null,
                      child: Text(
                        state.confirming ? 'Подтверждаем…' : 'Подтвердить план',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetOriginCard extends StatelessWidget {
  const _BudgetOriginCard({required this.state});

  final BudgetReady state;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('budget-origin'),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        children: [
          if (state.period.startWalletBalance > 0)
            _OriginRow(
              'Осталось с прошлого дня',
              '${state.period.startWalletBalance}',
            ),
          _OriginRow('Получено в начале дня', '+${state.period.baseIncome}'),
          const Divider(),
          _OriginRow(
            'На этот день',
            '${state.period.startingBudget}',
            emphasized: true,
          ),
        ],
      ),
    ),
  );
}

class _OriginRow extends StatelessWidget {
  const _OriginRow(this.label, this.value, {this.emphasized = false});

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: emphasized ? Theme.of(context).textTheme.titleLarge : null,
        ),
      ],
    ),
  );
}

class _BudgetCategoryEditor extends StatefulWidget {
  const _BudgetCategoryEditor({
    required this.title,
    required this.description,
    required this.semanticName,
    required this.value,
    required this.maximum,
    required this.onPreview,
    required this.onCommit,
    required this.onSavePreview,
    super.key,
  });

  final String title;
  final String description;
  final String semanticName;
  final int value;
  final int maximum;
  final ValueChanged<int> onPreview;
  final ValueChanged<int> onCommit;
  final VoidCallback onSavePreview;

  @override
  State<_BudgetCategoryEditor> createState() => _BudgetCategoryEditorState();
}

class _BudgetCategoryEditorState extends State<_BudgetCategoryEditor> {
  int? _dragMaximum;

  int _snap(double raw, int maximum) {
    if (raw >= maximum - 5) return maximum;
    return ((raw / 10).round() * 10).clamp(0, maximum);
  }

  @override
  Widget build(BuildContext context) {
    final maximum = _dragMaximum ?? widget.maximum;
    final value = widget.value.clamp(0, maximum);
    final decreased = math.max(0, widget.value - 10);
    final increased = math.min(widget.maximum, widget.value + 10);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text('${widget.value} 🪙'),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Text(widget.description),
            const SizedBox(height: AppSpacing.small),
            Row(
              children: [
                Semantics(
                  label: 'Уменьшить: ${widget.semanticName}',
                  button: true,
                  child: IconButton(
                    key: Key('budget-minus-${widget.semanticName}'),
                    tooltip: 'Уменьшить ${widget.semanticName}',
                    onPressed: widget.value > 0
                        ? () => widget.onCommit(decreased)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                ),
                Expanded(
                  child: Slider(
                    key: Key('budget-slider-${widget.semanticName}'),
                    value: value.toDouble(),
                    min: 0,
                    max: math.max(1, maximum).toDouble(),
                    onChangeStart: maximum > 0
                        ? (_) => setState(() => _dragMaximum = widget.maximum)
                        : null,
                    onChanged: maximum > 0
                        ? (raw) => widget.onPreview(_snap(raw, maximum))
                        : null,
                    onChangeEnd: maximum > 0
                        ? (_) {
                            setState(() => _dragMaximum = null);
                            widget.onSavePreview();
                          }
                        : null,
                    semanticFormatterCallback: (raw) =>
                        '${widget.semanticName}: ${_snap(raw, maximum)} монет',
                  ),
                ),
                Semantics(
                  label: 'Увеличить: ${widget.semanticName}',
                  button: true,
                  child: IconButton(
                    key: Key('budget-plus-${widget.semanticName}'),
                    tooltip: 'Увеличить ${widget.semanticName}',
                    onPressed: widget.value < widget.maximum
                        ? () => widget.onCommit(increased)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyAmount extends StatelessWidget {
  const _ReadOnlyAmount(this.label, this.amount);

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('$amount 🪙', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}

class _MutationError extends StatelessWidget {
  const _MutationError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    ),
  );
}

class _ConfirmationSheet extends StatelessWidget {
  const _ConfirmationSheet({required this.allocation, required this.remainder});

  final BudgetAllocation allocation;
  final int remainder;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Всё готово?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.medium),
          _OriginRow('Нужно', '${allocation.need}'),
          _OriginRow('Хочется', '${allocation.want}'),
          _OriginRow('Копилка', '${allocation.savings}'),
          _OriginRow('Останется', '$remainder'),
          const SizedBox(height: AppSpacing.small),
          const Text(
            'После подтверждения изменить план этого дня уже нельзя.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.large),
          FilledButton(
            key: const Key('budget-confirm-sheet'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Подтвердить'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Вернуться к плану'),
          ),
        ],
      ),
    ),
  );
}

class _BudgetError extends StatelessWidget {
  const _BudgetError({required this.onBack, required this.onRetry});

  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: BackButton(onPressed: onBack)),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Не получилось открыть план дня.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.large),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Попробовать снова'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
