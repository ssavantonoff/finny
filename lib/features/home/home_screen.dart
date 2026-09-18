import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/features/pet_creation/finny_preview.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/pet_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PetStatIndicator extends StatelessWidget {
  const PetStatIndicator({
    super.key,
    required this.label,
    required this.value,
    this.barKey,
  });

  final String label;
  final int value;
  final Key? barKey;

  static const Color red = Color(0xFFE57373);
  static const Color yellow = Color(0xFFFFB74D);
  static const Color green = Color(0xFF81C784);

  static Color statColor(int value) {
    if (value <= 39) return red;
    if (value <= 69) return yellow;
    return green;
  }

  @override
  Widget build(BuildContext context) {
    final color = statColor(value);
    final clamped = value.clamp(0, 100);
    return Semantics(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                key: barKey,
                value: clamped / 100.0,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                backgroundColor: color.withValues(alpha: 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _incomeSheetOpen = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(ref.read(homeControllerProvider.notifier).load);
  }

  Future<void> _startDay() async {
    final period = await ref.read(homeControllerProvider.notifier).startDay();
    if (!mounted || period == null || _incomeSheetOpen) return;
    _incomeSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _IncomeExplanation(period: period),
    );
    _incomeSheetOpen = false;
  }

  Future<void> _finishDay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить день?'),
        content: const Text(
          'После завершения изменить решения этого дня нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final completed = await ref
        .read(homeControllerProvider.notifier)
        .finishDay();
    if (completed && mounted) context.go('/period-summary');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    ref.listen<int?>(activeProfileIdProvider, (_, _) {
      controller.load();
    });

    if (state is HomeNeedsBootstrap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/startup');
      });
    }

    return switch (state) {
      HomeLoading() || HomeNeedsBootstrap() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      HomeFailure() => _HomeError(onRetry: controller.load),
      HomeReady() => _HomeContent(
        state: state,
        controller: controller,
        onStartDay: _startDay,
        onFinishDay: _finishDay,
      ),
    };
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.state,
    required this.controller,
    required this.onStartDay,
    required this.onFinishDay,
  });

  final HomeReady state;
  final HomeController controller;
  final VoidCallback onStartDay;
  final VoidCallback onFinishDay;

  @override
  Widget build(BuildContext context) {
    final period = state.period;
    final title = period == null
        ? state.completedDays == 0
            ? 'Первый день'
            : 'Дом Финни'
        : 'День ${period.periodNumber} • ${state.definition!.title}';

    final periodAllowsPetAction =
        period != null &&
        (period.status == GamePeriodStatus.active ||
            period.status == GamePeriodStatus.readyToFinish);

    final canPet =
        periodAllowsPetAction &&
        state.petUsageCount == 0 &&
        !state.interacting;

    final canPlay =
        periodAllowsPetAction &&
        state.playUsageCount == 0 &&
        !state.interacting;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.medium),
              child: Text(
                '${state.gameState.walletBalance} 🪙',
                key: const Key('home-wallet'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ],
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
                  // Pet Room Atmosphere
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                      vertical: AppSpacing.small,
                    ),
                    child: Column(
                      children: [
                        // 3 Stat Indicators
                        Row(
                          children: [
                            Expanded(
                              child: PetStatIndicator(
                                key: const Key('home-stat-satiety'),
                                barKey: const Key('home-stat-satiety-bar'),
                                label: 'Сытость',
                                value: state.pet.satiety,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.small),
                            Expanded(
                              child: PetStatIndicator(
                                key: const Key('home-stat-care'),
                                barKey: const Key('home-stat-care-bar'),
                                label: 'Уход',
                                value: state.pet.care,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.small),
                            Expanded(
                              child: PetStatIndicator(
                                key: const Key('home-stat-mood'),
                                barKey: const Key('home-stat-mood-bar'),
                                label: 'Настроение',
                                value: state.pet.mood,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.small),
                        SizedBox(
                          height: 140,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: FinnyPreview(
                              colorId: state.pet.colorId,
                              patternId: state.pet.patternId,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.pet.name,
                          key: const Key('home-pet-name'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.small),
                        // Free Interactions
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                key: const Key('home-free-pet'),
                                onPressed: canPet
                                    ? () => controller.performFreeInteraction(
                                          FreePetInteraction.pet,
                                        )
                                    : null,
                                icon: const Icon(Icons.favorite_outline),
                                label: Text(
                                  state.petUsageCount > 0
                                      ? 'Погладить ✓'
                                      : 'Погладить',
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.small),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                key: const Key('home-free-play'),
                                onPressed: canPlay
                                    ? () => controller.performFreeInteraction(
                                          FreePetInteraction.play,
                                        )
                                    : null,
                                icon: const Icon(Icons.sports_baseball_outlined),
                                label: Text(
                                  state.playUsageCount > 0
                                      ? 'Поиграть ✓'
                                      : 'Поиграть',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (state.interactionNotice case final notice?) ...[
                    const SizedBox(height: AppSpacing.small),
                    _Notice(notice),
                  ],
                  const SizedBox(height: AppSpacing.small),
                  _DayStatusCard(period: period),
                  if (state.startFailed) ...[
                    const SizedBox(height: AppSpacing.small),
                    const _Notice(
                      'Не получилось начать день. Попробуй ещё раз.',
                    ),
                  ],
                  if (state.finishFailed) ...[
                    const SizedBox(height: AppSpacing.small),
                    const _Notice(
                      'Не получилось завершить день. Попробуй ещё раз.',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.small),
                  if (state.allDaysCompleted)
                    const _Notice('Все дни завершены')
                  else if (period == null)
                    FilledButton(
                      key: const Key('home-start-day'),
                      onPressed: state.startingDay ? null : onStartDay,
                      child: Text(
                        state.startingDay
                            ? 'Начинаем…'
                            : state.completedDays == 0
                            ? 'Начать день'
                            : 'Начать следующий день',
                      ),
                    )
                  else if (period.status == GamePeriodStatus.planning)
                    FilledButton(
                      key: const Key('home-continue-plan'),
                      onPressed: () => context.go('/budget'),
                      child: const Text('Продолжить план'),
                    )
                  else if (period.status == GamePeriodStatus.active)
                    FilledButton(
                      key: const Key('home-view-plan'),
                      onPressed: () => context.go('/budget'),
                      child: const Text('Посмотреть план'),
                    )
                  else if (period.status == GamePeriodStatus.readyToFinish)
                    FilledButton(
                      key: const Key('home-finish-day'),
                      onPressed: state.finishingDay ? null : onFinishDay,
                      child: Text(
                        state.finishingDay ? 'Завершаем…' : 'Завершить день',
                      ),
                    ),
                  // Compact "Today" block
                  if (period != null) ...[
                    const SizedBox(height: AppSpacing.medium),
                    _TodayCard(period: period),
                  ],
                  // Active Savings Goal (Compact)
                  if (state.activeGoal case final goal?) ...[
                    const SizedBox(height: AppSpacing.medium),
                    Card(
                      key: const Key('home-savings-goal'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        child: Row(
                          children: [
                            Icon(
                              Icons.savings_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.medium),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goal.name,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: (state.gameState.savedAmount /
                                              goal.price)
                                          .clamp(0.0, 1.0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.medium),
                            Text(
                              '${state.gameState.savedAmount}/${goal.price} 🪙',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
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
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.period});

  final GamePeriod period;

  @override
  Widget build(BuildContext context) {
    final checkpoints = period.requiredCheckpoints
        .where((id) => id != 'mandatory_need')
        .toList(growable: false);

    if (checkpoints.isEmpty) return const SizedBox.shrink();

    return Card(
      key: const Key('home-today-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сегодня',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.small),
            Wrap(
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.small,
              children: [
                for (final cp in checkpoints) ...[
                  _CheckpointChip(
                    label: switch (cp) {
                      'financial_task' => 'Задание',
                      'savings_decision' => 'Накопления',
                      'changed_circumstance' => 'Событие',
                      'discount_decision' => 'Скидка',
                      _ => cp,
                    },
                    resolved: period.resolvedCheckpoints.contains(cp),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckpointChip extends StatelessWidget {
  const _CheckpointChip({required this.label, required this.resolved});

  final String label;
  final bool resolved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          resolved ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: resolved
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: resolved ? FontWeight.w600 : FontWeight.normal,
            color: resolved
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DayStatusCard extends StatelessWidget {
  const _DayStatusCard({required this.period});

  final GamePeriod? period;

  @override
  Widget build(BuildContext context) {
    final (title, description) = switch (period?.status) {
      null => ('Первый день с Финни', 'Получи монеты и составь план на день.'),
      GamePeriodStatus.planning => ('План ещё не готов', ''),
      GamePeriodStatus.active => (
        'План готов',
        'Теперь можно принимать решения этого дня.',
      ),
      GamePeriodStatus.readyToFinish => (
        'Все важные решения приняты',
        'День почти завершён.',
      ),
      GamePeriodStatus.completed => ('День завершён', ''),
    };
    return Card(
      key: const Key('home-day-status'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.small),
              Text(description, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class _IncomeExplanation extends StatelessWidget {
  const _IncomeExplanation({required this.period});

  final GamePeriod period;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Новый день начался!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.large),
          if (period.startWalletBalance == 0) ...[
            Text(
              'Ты получил ${period.baseIncome} 🪙',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.small),
            const Text(
              'Теперь реши, как ими распорядиться.',
              textAlign: TextAlign.center,
            ),
          ] else ...[
            _MoneyRow('Было с прошлого дня', period.startWalletBalance),
            _MoneyRow('Получено в начале дня', period.baseIncome, prefix: '+'),
            const Divider(),
            _MoneyRow('Доступно', period.startingBudget, emphasized: true),
          ],
          const SizedBox(height: AppSpacing.large),
          FilledButton(
            key: const Key('income-build-plan'),
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/budget');
            },
            child: const Text('Составить план'),
          ),
        ],
      ),
    ),
  );
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow(
    this.label,
    this.amount, {
    this.prefix = '',
    this.emphasized = false,
  });

  final String label;
  final int amount;
  final String prefix;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          '$prefix$amount',
          style: emphasized ? Theme.of(context).textTheme.titleLarge : null,
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Не получилось открыть дом Финни.',
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
