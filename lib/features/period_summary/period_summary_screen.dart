import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_flow_visuals.dart';
import 'package:finny/features/home/home_visual_components.dart';
import 'package:finny/features/period_summary/period_summary_controller.dart';
import 'package:finny/models/period_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Short observations from persisted plan and fact. This never changes accounting.
List<String> summaryObservations(PeriodSummary summary) {
  final observations = <String>[];
  if (summary.factWant > summary.plannedWant) {
    observations.add('На «Хочу» ушло больше, чем было в плане.');
  } else if (summary.factWant < summary.plannedWant) {
    observations.add('На «Хочу» ушло меньше, чем было в плане.');
  }
  if (summary.factSavings > summary.plannedSavings) {
    observations.add(
      'В копилку получилось отложить больше, чем планировалось.',
    );
  } else if (summary.factSavings < summary.plannedSavings) {
    observations.add(
      'В копилку получилось отложить меньше, чем планировалось.',
    );
  }
  if (observations.length < 2 && summary.factNeed != summary.plannedNeed) {
    observations.add(
      summary.factNeed > summary.plannedNeed
          ? 'На нужные покупки ушло больше, чем было в плане.'
          : 'На нужные покупки ушло меньше, чем было в плане.',
    );
  }
  if (observations.isEmpty) {
    observations.add('План и фактические траты за день совпали.');
  }
  return observations.take(2).toList(growable: false);
}

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
      body: FinnyFlowBackdrop(
        child: SafeArea(
          child: switch (state) {
            PeriodSummaryLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            PeriodSummaryFailure() => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Не удалось загрузить итоги дня.'),
                  const SizedBox(height: AppSpacing.medium),
                  FinnyFlowButton(
                    label: 'Попробовать снова',
                    onPressed: ref
                        .read(periodSummaryControllerProvider.notifier)
                        .load,
                  ),
                ],
              ),
            ),
            PeriodSummaryReady() => _SummaryBody(
              state: state,
              profileId: ref.watch(activeProfileIdProvider),
            ),
          },
        ),
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.state, required this.profileId});
  final PeriodSummaryReady state;
  final int? profileId;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            'День ${state.period.periodNumber} завершён!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              height: 1.08,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Посмотрим, как прошёл твой день.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          if (profileId != null) ...[
            const SizedBox(height: 8),
            CurrentFinnyArt(profileId: profileId!, height: 170),
          ],
          const SizedBox(height: 14),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Как получилось?',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Spacer(),
                    SizedBox(
                      width: 56,
                      child: Text('План', textAlign: TextAlign.center),
                    ),
                    SizedBox(width: 20),
                    SizedBox(
                      width: 56,
                      child: Text('Факт', textAlign: TextAlign.center),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _SummaryRow(
                  'Нужно',
                  Icons.pets_rounded,
                  AppColors.need,
                  state.summary.plannedNeed,
                  state.summary.factNeed,
                ),
                _SummaryRow(
                  'Хочу',
                  Icons.favorite_rounded,
                  AppColors.want,
                  state.summary.plannedWant,
                  state.summary.factWant,
                ),
                _SummaryRow(
                  'Копилка',
                  Icons.savings_rounded,
                  AppColors.savings,
                  state.summary.plannedSavings,
                  state.summary.factSavings,
                ),
                _SummaryRow(
                  'Свободно',
                  Icons.toll_rounded,
                  AppColors.primary,
                  state.summary.plannedRemainder,
                  state.summary.factRemainder,
                ),
              ],
            ),
          ),
          if (state.summary.additionalIncome > 0) ...[
            const SizedBox(height: 12),
            _Panel(
              child: Row(
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Заработано за задания')),
                  Text(
                    '+${state.summary.additionalIncome}',
                    key: const Key('summary-additional-income'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.savings,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const FinnyCoin(size: 23),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Что изменилось?',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final text in summaryObservations(state.summary))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (state.summary.unexpectedNeed > 0)
                  Text(
                    '${state.summary.carriedUnexpectedNeed ? 'Перенесённая' : 'Незапланированная'} нужная трата: Новая миска — '
                    '${state.summary.unexpectedNeed} монет',
                    key: const Key('summary-unexpected-bowl'),
                  ),
                if (state.summary.savingsWithdrawn > 0)
                  Text(
                    'Из копилки использовано: ${state.summary.savingsWithdrawn} монет',
                    key: const Key('summary-savings-withdrawn'),
                  ),
                if (state.summary.bowlPostponed)
                  Text(
                    state.period.periodNumber == 3
                        ? 'Нужная покупка отложена.'
                        : 'Новая миска всё ещё отложена.',
                    key: const Key('summary-bowl-postponed'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FinnyFlowButton(
            key: const Key('summary-home'),
            label: 'Продолжить',
            onPressed: () {
              final day = state.period.periodNumber;
              context.go(day == 2 || day == 5 ? '/progress?day=$day' : '/home');
            },
          ),
        ],
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.icon, this.color, this.plan, this.fact);
  final String label;
  final IconData icon;
  final Color color;
  final int plan;
  final int fact;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.20),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$plan',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
        ),
        const Icon(
          Icons.arrow_forward_rounded,
          size: 20,
          color: AppColors.textSecondary,
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$fact',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
        ),
      ],
    ),
  );
}
