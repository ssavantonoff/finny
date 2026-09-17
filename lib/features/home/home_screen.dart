import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/features/pet_creation/finny_preview.dart';
import 'package:finny/models/game_period.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  Future<void> _openSavings() async {
    await context.push('/savings');
    if (mounted) await ref.read(homeControllerProvider.notifier).load();
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
    ref.listen<int?>(activeProfileIdProvider, (_, _) {
      ref.read(homeControllerProvider.notifier).load();
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
      HomeFailure() => _HomeError(
        onRetry: ref.read(homeControllerProvider.notifier).load,
      ),
      HomeReady() => _HomeContent(
        state: state,
        onStartDay: _startDay,
        onSavings: _openSavings,
        onFinishDay: _finishDay,
      ),
    };
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.state,
    required this.onStartDay,
    required this.onSavings,
    required this.onFinishDay,
  });

  final HomeReady state;
  final VoidCallback onStartDay;
  final VoidCallback onSavings;
  final VoidCallback onFinishDay;

  @override
  Widget build(BuildContext context) {
    final period = state.period;
    final title = period == null
        ? state.completedDays == 0
              ? 'Первый день'
              : 'Дом Финни'
        : 'День ${period.periodNumber} • ${state.definition!.title}';
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
                  FinnyPreview(
                    colorId: state.pet.colorId,
                    patternId: state.pet.patternId,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    state.pet.name,
                    key: const Key('home-pet-name'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.large),
                  _DayStatusCard(period: period),
                  if (state.startFailed) ...[
                    const SizedBox(height: AppSpacing.medium),
                    const _Notice(
                      'Не получилось начать день. Попробуй ещё раз.',
                    ),
                  ],
                  if (state.finishFailed) ...[
                    const SizedBox(height: AppSpacing.medium),
                    const _Notice(
                      'Не получилось завершить день. Попробуй ещё раз.',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.large),
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
                  const SizedBox(height: AppSpacing.small),
                  OutlinedButton.icon(
                    key: const Key('home-savings'),
                    onPressed: onSavings,
                    icon: const Icon(Icons.savings_outlined),
                    label: const Text('Накопления'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
        padding: const EdgeInsets.all(AppSpacing.large),
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
