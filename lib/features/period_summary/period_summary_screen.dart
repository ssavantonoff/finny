import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/period_summary/period_summary_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PeriodSummaryScreen extends ConsumerStatefulWidget {
  const PeriodSummaryScreen({super.key});

  @override
  ConsumerState<PeriodSummaryScreen> createState() =>
      _PeriodSummaryScreenState();
}

class _PeriodSummaryScreenState extends ConsumerState<PeriodSummaryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(ref.read(periodSummaryControllerProvider.notifier).load);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(periodSummaryControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          state is PeriodSummaryReady
              ? 'Итоги дня ${state.period.periodNumber}'
              : 'Итоги дня',
        ),
      ),
      body: switch (state) {
        PeriodSummaryLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        PeriodSummaryFailure() => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Не удалось загрузить итоги дня.'),
                const SizedBox(height: AppSpacing.medium),
                FilledButton(
                  onPressed: ref
                      .read(periodSummaryControllerProvider.notifier)
                      .load,
                  child: const Text('Попробовать снова'),
                ),
              ],
            ),
          ),
        ),
        PeriodSummaryReady() => _SummaryBody(state: state),
      },
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.state});
  final PeriodSummaryReady state;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        Text(
          'День ${state.period.periodNumber} завершён',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.large),
        const Row(
          children: [
            Expanded(child: Text('Категория')),
            SizedBox(width: 80, child: Text('План')),
            SizedBox(width: 80, child: Text('Факт')),
          ],
        ),
        const Divider(),
        _SummaryRow(
          'Нужное',
          state.summary.plannedNeed,
          state.summary.factNeed,
        ),
        _SummaryRow(
          'Желания',
          state.summary.plannedWant,
          state.summary.factWant,
        ),
        _SummaryRow(
          'Накопления',
          state.summary.plannedSavings,
          state.summary.factSavings,
        ),
        _SummaryRow(
          'На потом',
          state.summary.plannedRemainder,
          state.summary.factRemainder,
        ),
        if (state.summary.additionalIncome > 0) ...[
          const SizedBox(height: AppSpacing.medium),
          Text(
            'Дополнительный доход: +${state.summary.additionalIncome}',
            key: const Key('summary-additional-income'),
          ),
        ],
        if (state.summary.unexpectedNeed > 0) ...[
          const SizedBox(height: AppSpacing.small),
          Text(
            '${state.summary.carriedUnexpectedNeed ? 'Перенесённая' : 'Незапланированная'} нужная трата: Новая миска — '
            '${state.summary.unexpectedNeed} монет',
            key: const Key('summary-unexpected-bowl'),
          ),
        ],
        if (state.summary.savingsWithdrawn > 0) ...[
          const SizedBox(height: AppSpacing.small),
          Text(
            'Из копилки использовано: ${state.summary.savingsWithdrawn} монет',
            key: const Key('summary-savings-withdrawn'),
          ),
        ],
        if (state.summary.bowlPostponed) ...[
          const SizedBox(height: AppSpacing.small),
          Text(
            state.period.periodNumber == 3
                ? 'Нужная покупка отложена.'
                : 'Новая миска всё ещё отложена.',
            key: Key('summary-bowl-postponed'),
          ),
        ],
        const SizedBox(height: AppSpacing.large),
        FilledButton(
          key: const Key('summary-home'),
          onPressed: () {
            final day = state.period.periodNumber;
            context.go(day == 2 || day == 5 ? '/progress?day=$day' : '/home');
          },
          child: Text(
            state.period.periodNumber == 2 || state.period.periodNumber == 5
                ? 'Продолжить'
                : 'На главную',
          ),
        ),
      ],
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.plan, this.fact);
  final String label;
  final int plan;
  final int fact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        SizedBox(width: 80, child: Text('$plan')),
        SizedBox(width: 80, child: Text('$fact')),
      ],
    ),
  );
}
