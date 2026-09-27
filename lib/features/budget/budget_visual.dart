import 'dart:math' as math;

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_flow_visuals.dart';
import 'package:finny/features/budget/budget_controller.dart';
import 'package:finny/services/budget_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _freeColor = Color(0xFFDCD9F6);

List<double> budgetDistributionFractions(
  BudgetAllocation allocation,
  int total,
) {
  if (total <= 0) return const [0, 0, 0, 1];
  return [
    allocation.need,
    allocation.want,
    allocation.savings,
    allocation.remainderFor(total),
  ].map((value) => value.clamp(0, total) / total).toList();
}

class BudgetVisual extends ConsumerWidget {
  const BudgetVisual({
    required this.state,
    required this.onBack,
    required this.onConfirm,
    super.key,
  });
  final BudgetReady state;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(budgetControllerProvider.notifier);
    final allocation = state.draft;
    return Theme(
      data: AppTheme.home(Theme.of(context)),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: FinnyFlowBackdrop(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SizedBox.square(
                            dimension: 48,
                            child: IconButton(
                              tooltip: 'Назад',
                              onPressed: onBack,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primaryDark,
                              ),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                          ),
                          const Spacer(),
                          _DayPill(state.period.periodNumber),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.editable ? 'План на день' : 'Твой план',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.editable
                            ? 'Распредели монеты так, как считаешь правильным.'
                            : 'Вот как ты распределил монеты на этот день.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.3,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        state.definition.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _BudgetSummary(state: state),
                      const SizedBox(height: 16),
                      BudgetDistributionBar(
                        allocation: allocation,
                        total: state.period.startingBudget,
                        legend: true,
                      ),
                      const SizedBox(height: 16),
                      if (state.editable) ...[
                        BudgetCategoryEditor(
                          key: const Key('budget-editor-need'),
                          title: 'Нужно',
                          description: 'Важное для заботы о Финни.',
                          color: AppColors.need,
                          icon: Icons.pets_rounded,
                          value: allocation.need,
                          maximum: controller.maximumFor(
                            state,
                            BudgetCategory.need,
                          ),
                          onPreview: (value) => controller.previewValue(
                            BudgetCategory.need,
                            value,
                          ),
                          onCommit: (value) =>
                              controller.setValue(BudgetCategory.need, value),
                          onSavePreview: controller.savePreview,
                        ),
                        const SizedBox(height: 12),
                        BudgetCategoryEditor(
                          key: const Key('budget-editor-want'),
                          title: 'Хочу',
                          description: 'Приятные, но необязательные покупки.',
                          color: AppColors.want,
                          icon: Icons.toys_rounded,
                          value: allocation.want,
                          maximum: controller.maximumFor(
                            state,
                            BudgetCategory.want,
                          ),
                          onPreview: (value) => controller.previewValue(
                            BudgetCategory.want,
                            value,
                          ),
                          onCommit: (value) =>
                              controller.setValue(BudgetCategory.want, value),
                          onSavePreview: controller.savePreview,
                        ),
                        const SizedBox(height: 12),
                        BudgetCategoryEditor(
                          key: const Key('budget-editor-savings'),
                          title: 'Копилка',
                          description:
                              'Сколько хочешь отложить на будущую цель.',
                          color: AppColors.savings,
                          icon: Icons.savings_rounded,
                          value: allocation.savings,
                          maximum: controller.maximumFor(
                            state,
                            BudgetCategory.savings,
                          ),
                          onPreview: (value) => controller.previewValue(
                            BudgetCategory.savings,
                            value,
                          ),
                          onCommit: (value) => controller.setValue(
                            BudgetCategory.savings,
                            value,
                          ),
                          onSavePreview: controller.savePreview,
                        ),
                      ] else ...[
                        _BudgetAmountRow(
                          'Нужно',
                          allocation.need,
                          AppColors.need,
                          Icons.pets_rounded,
                        ),
                        const SizedBox(height: 10),
                        _BudgetAmountRow(
                          'Хочу',
                          allocation.want,
                          AppColors.want,
                          Icons.toys_rounded,
                        ),
                        const SizedBox(height: 10),
                        _BudgetAmountRow(
                          'Копилка',
                          allocation.savings,
                          AppColors.savings,
                          Icons.savings_rounded,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _BudgetAmountRow(
                        'Останется свободно',
                        state.remainder,
                        _freeColor,
                        Icons.toll_rounded,
                        key: const Key('budget-remainder'),
                        description: 'Эти монеты останутся у тебя.',
                      ),
                      if (!state.editable) ...[
                        const SizedBox(height: 14),
                        const _BudgetNotice(
                          'План подтверждён. Изменить его уже нельзя.',
                          icon: Icons.info_rounded,
                        ),
                      ],
                      if (state.saving) ...[
                        const SizedBox(height: 14),
                        const _BudgetNotice(
                          'Сохраняем изменение…',
                          icon: Icons.sync_rounded,
                        ),
                        const LinearProgressIndicator(
                          key: Key('budget-saving'),
                          minHeight: 3,
                        ),
                      ],
                      if (state.saveFailed) ...[
                        const SizedBox(height: 14),
                        BudgetMutationError(
                          message: 'Не получилось сохранить изменение',
                          onRetry: controller.retrySave,
                        ),
                      ],
                      if (state.confirmFailed) ...[
                        const SizedBox(height: 14),
                        const BudgetMutationError(
                          message: 'Не получилось подтвердить план. Попробуй ещё раз.',
                        ),
                      ],
                      if (state.editable) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 58,
                          child: FilledButton(
                            key: const Key('budget-confirm'),
                            onPressed: state.canConfirm ? onConfirm : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              state.confirming
                                  ? 'Подтверждаем…'
                                  : 'Подтвердить план',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill(this.day);
  final int day;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    decoration: const BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.all(Radius.circular(30)),
    ),
    child: Text(
      'День $day',
      style: const TextStyle(
        color: AppColors.primaryDark,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({required this.state});
  final BudgetReady state;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('budget-origin'),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.93),
      borderRadius: BorderRadius.circular(30),
      boxShadow: const [
        BoxShadow(
          color: Color(0x176C5CE7),
          blurRadius: 22,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'На этот день',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  FinnyAmount('${state.period.startingBudget}', size: 42),
                ],
              ),
            ),
            CurrentFinnyArt(profileId: state.profile.id!, height: 112),
          ],
        ),
        const Divider(height: 24, color: AppColors.primaryLight),
        Row(
          children: [
            Expanded(
              child: _OriginMini(
                'С прошлого дня',
                '${state.period.startWalletBalance}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OriginMini('Новый доход', '+${state.period.baseIncome}'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _OriginMini extends StatelessWidget {
  const _OriginMini(this.label, this.amount);
  final String label;
  final String amount;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 2,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      FinnyAmount(amount, size: 17),
    ],
  );
}

class BudgetDistributionBar extends StatelessWidget {
  const BudgetDistributionBar({
    required this.allocation,
    required this.total,
    this.legend = false,
    super.key,
  });
  final BudgetAllocation allocation;
  final int total;
  final bool legend;

  @override
  Widget build(BuildContext context) {
    final portions = budgetDistributionFractions(allocation, total);
    final values = [
      allocation.need,
      allocation.want,
      allocation.savings,
      allocation.remainderFor(total),
    ];
    const colors = [
      AppColors.need,
      AppColors.want,
      AppColors.savings,
      _freeColor,
    ];
    const labels = ['Нужно', 'Хочу', 'Копилка', 'Свободно'];
    return Container(
      key: const Key('budget-distribution'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 22,
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    if (portions[i] > 0)
                      Expanded(
                        flex: math.max(1, (portions[i] * 10000).round()),
                        child: ColoredBox(
                          key: Key('budget-segment-$i'),
                          color: colors[i],
                        ),
                      ),
                ],
              ),
            ),
          ),
          if (legend) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Column(
                      children: [
                        FinnyAmount('${values[i]}', size: 14),
                        Text(
                          labels[i],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class BudgetCategoryEditor extends StatefulWidget {
  const BudgetCategoryEditor({
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
    required this.value,
    required this.maximum,
    required this.onPreview,
    required this.onCommit,
    required this.onSavePreview,
    super.key,
  });
  final String title;
  final String description;
  final Color color;
  final IconData icon;
  final int value;
  final int maximum;
  final ValueChanged<int> onPreview;
  final ValueChanged<int> onCommit;
  final VoidCallback onSavePreview;

  @override
  State<BudgetCategoryEditor> createState() => _BudgetCategoryEditorState();
}

class _BudgetCategoryEditorState extends State<BudgetCategoryEditor> {
  int? _dragMaximum;
  int _snap(double raw, int maximum) {
    if (raw >= maximum - 5) return maximum;
    return ((raw / 10).round() * 10).clamp(0, maximum);
  }

  @override
  Widget build(BuildContext context) {
    final maximum = _dragMaximum ?? widget.maximum;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.lerp(widget.color, Colors.white, 0.91),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: widget.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _CategoryArt(icon: widget.icon, color: widget.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      widget.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              FinnyAmount('${widget.value}', size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _AdjustButton(
                key: Key('budget-minus-${widget.title}'),
                icon: Icons.remove_rounded,
                label: 'Уменьшить ${widget.title}',
                onPressed: widget.value > 0
                    ? () => widget.onCommit(math.max(0, widget.value - 10))
                    : null,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: widget.color,
                    inactiveTrackColor: _freeColor,
                    thumbColor: widget.color,
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 13,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 22,
                    ),
                  ),
                  child: Slider(
                    key: Key('budget-slider-${widget.title}'),
                    value: widget.value.clamp(0, maximum).toDouble(),
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
                        '${widget.title}: ${_snap(raw, maximum)} монет',
                  ),
                ),
              ),
              _AdjustButton(
                key: Key('budget-plus-${widget.title}'),
                icon: Icons.add_rounded,
                label: 'Увеличить ${widget.title}',
                onPressed: widget.value < widget.maximum
                    ? () => widget.onCommit(
                        math.min(widget.maximum, widget.value + 10),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    child: SizedBox.square(
      dimension: 48,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryDark,
        ),
      ),
    ),
  );
}

class _BudgetAmountRow extends StatelessWidget {
  const _BudgetAmountRow(
    this.label,
    this.value,
    this.color,
    this.icon, {
    this.description,
    super.key,
  });
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final String? description;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Color.lerp(color, Colors.white, 0.9),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 38,
          child: _CategoryArt(icon: icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (description != null)
                Text(
                  description!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        FinnyAmount('$value', size: 19),
      ],
    ),
  );
}

class _CategoryArt extends StatelessWidget {
  const _CategoryArt({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => icon == Icons.toys_rounded
      ? Image.asset(
          'assets/minigames/ball/ball.png',
          fit: BoxFit.contain,
          semanticLabel: 'Игрушка',
        )
      : Icon(
          icon,
          size: 34,
          color: color == _freeColor ? AppColors.primary : color,
        );
}

class _BudgetNotice extends StatelessWidget {
  const _BudgetNotice(this.message, {required this.icon});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );
}

class BudgetMutationError extends StatelessWidget {
  const BudgetMutationError({required this.message, this.onRetry, super.key});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.error),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
      ],
    ),
  );
}

class BudgetConfirmationSheet extends StatelessWidget {
  const BudgetConfirmationSheet({
    required this.allocation,
    required this.total,
    super.key,
  });
  final BudgetAllocation allocation;
  final int total;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: FractionallySizedBox(
      heightFactor: 0.88,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Всё готово?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Проверь свой план перед подтверждением.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 18),
            BudgetDistributionBar(allocation: allocation, total: total),
            const SizedBox(height: 12),
            _BudgetAmountRow(
              'Нужно',
              allocation.need,
              AppColors.need,
              Icons.pets_rounded,
            ),
            const SizedBox(height: 8),
            _BudgetAmountRow(
              'Хочу',
              allocation.want,
              AppColors.want,
              Icons.toys_rounded,
            ),
            const SizedBox(height: 8),
            _BudgetAmountRow(
              'Копилка',
              allocation.savings,
              AppColors.savings,
              Icons.savings_rounded,
            ),
            const SizedBox(height: 8),
            _BudgetAmountRow(
              'Останется свободно',
              allocation.remainderFor(total),
              _freeColor,
              Icons.toll_rounded,
            ),
            const SizedBox(height: 14),
            const _BudgetNotice(
              'После подтверждения изменить план этого дня уже нельзя.',
              icon: Icons.info_rounded,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              child: FilledButton(
                key: const Key('budget-confirm-sheet'),
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Подтвердить',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Вернуться к плану'),
            ),
          ],
        ),
      ),
    ),
  );
}
