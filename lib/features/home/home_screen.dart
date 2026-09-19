import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/features/home/campaign_event_controller.dart';
import 'package:finny/features/pet_creation/finny_preview.dart';
import 'package:finny/models/day_lifecycle.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/virtual_day_rules.dart';
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
  bool _eventDialogOpen = false;
  String? _eventLoadKey;

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
    final controller = ref.read(homeControllerProvider.notifier);
    final decision = await controller.evaluateBedtime();
    if (!mounted || decision == null) return;
    var allowFallback = false;
    switch (decision.type) {
      case BedtimeDecisionType.tooEarly:
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ещё рано спать'),
            content: const Text(
              'У Финни ещё есть время для дел и заботы. Вернись к нему позже.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Хорошо'),
              ),
            ],
          ),
        );
        return;
      case BedtimeDecisionType.blockedByCheckpoints:
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Перед сном осталось важное дело'),
            content: Text(
              decision.unresolvedCheckpoints
                  .map(_checkpointBlockerText)
                  .join('\n\n'),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Вернуться'),
              ),
            ],
          ),
        );
        return;
      case BedtimeDecisionType.ready:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Финни готов отдыхать.'),
            content: const Text('Завершить день?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Вернуться'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Уложить спать'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        break;
      case BedtimeDecisionType.carePossible:
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Финни ещё не готов спать.'),
            content: Text(
              'Подними ${_statLabels(decision.statsNeedingCare)} '
              'в зелёную зону.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Вернуться'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'things'),
                child: const Text('Открыть Вещи'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, 'shop'),
                child: const Text('Открыть Магазин'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (action == 'things') context.go('/things');
        if (action == 'shop') context.go('/shop');
        return;
      case BedtimeDecisionType.fallbackAllowed:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Сегодня Финни нужна помощь'),
            content: const Text(
              'Сегодня уже не хватает доступных вещей и монет, чтобы '
              'привести все показатели Финни в зелёную зону.\n\n'
              'Можно завершить день сейчас. Завтра Финни начнёт день '
              'с более низким состоянием.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Вернуться'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Завершить день'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        allowFallback = true;
        break;
    }
    if (!mounted) return;
    final completed = await ref
        .read(homeControllerProvider.notifier)
        .sleep(allowFallback: allowFallback);
    if (completed && mounted) context.go('/period-summary');
  }

  Future<void> _showCampaignEvent(int walletBalance) async {
    if (_eventDialogOpen || !mounted) return;
    _eventDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CampaignEventDialog(walletBalance: walletBalance),
    );
    _eventDialogOpen = false;
    if (mounted) {
      await ref.read(homeControllerProvider.notifier).load();
    }
  }

  String _statLabels(Set<PetStat> stats) => [
    if (stats.contains(PetStat.satiety)) 'Сытость',
    if (stats.contains(PetStat.care)) 'Уход',
    if (stats.contains(PetStat.mood)) 'Настроение',
  ].join(', ');

  String _checkpointBlockerText(String checkpoint) => switch (checkpoint) {
    'financial_task' => 'Осталось выполнить сегодняшнее финансовое задание.',
    'savings_decision' =>
      'Осталось решить, будешь ли ты сегодня откладывать монеты.',
    'changed_circumstance' =>
      'Осталось разобраться с сегодняшней неожиданной ситуацией.',
    'discount_decision' =>
      'Осталось принять решение о сегодняшнем предложении.',
    _ => 'Осталось завершить одно важное дело этого дня.',
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    ref.listen<CampaignEventState>(campaignEventControllerProvider, (_, next) {
      if (next is CampaignEventReady && !_eventDialogOpen) {
        final home = ref.read(homeControllerProvider);
        if (home is HomeReady) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _showCampaignEvent(home.gameState.walletBalance),
          );
        }
      }
    });

    ref.listen<int?>(activeProfileIdProvider, (_, _) {
      controller.load();
    });

    if (state is HomeNeedsBootstrap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/startup');
      });
    }
    if (state is HomeReady && state.period?.id != null) {
      final key =
          '${state.profile.id}:${state.period!.id}:'
          '${state.period!.resolvedCheckpoints.join(',')}';
      if (_eventLoadKey != key) {
        _eventLoadKey = key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(campaignEventControllerProvider.notifier).load();
          }
        });
      }
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
        periodAllowsPetAction && state.petUsageCount == 0 && !state.interacting;

    final dayProgress = period?.dayProgress ?? 0;
    final progressFraction = dayProgress / VirtualDayRules.maxProgress;
    final skyTop = Color.lerp(
      const Color(0xFFFFE0B2),
      const Color(0xFF81D4FA),
      (progressFraction * 2).clamp(0.0, 1.0),
    )!;
    final skyBottom = Color.lerp(
      const Color(0xFFB3E5FC),
      const Color(0xFF9575CD),
      ((progressFraction - 0.5) * 2).clamp(0.0, 1.0),
    )!;

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
                    key: const Key('home-day-sky'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [skyTop, skyBottom],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                      vertical: AppSpacing.small,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 42,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const diameter = 28.0;
                              final travel = (constraints.maxWidth - diameter)
                                  .clamp(0.0, double.infinity);
                              final distanceFromNoon =
                                  (progressFraction * 2 - 1).abs();
                              return Stack(
                                children: [
                                  Positioned(
                                    left: travel * progressFraction,
                                    top: 2 + 12 * distanceFromNoon,
                                    child: Container(
                                      key: const Key('home-sun'),
                                      width: diameter,
                                      height: diameter,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFFFFD54F),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
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
                              developmentStage: state.pet.developmentStage,
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
                        FilledButton.tonalIcon(
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
                      ],
                    ),
                  ),
                  if (state.interactionNotice case final notice?) ...[
                    const SizedBox(height: AppSpacing.small),
                    _Notice(notice),
                  ],
                  const SizedBox(height: AppSpacing.small),
                  _DayStatusCard(
                    period: period,
                    completedDays: state.completedDays,
                  ),
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
                    _Notice(
                      'Все 5 дней завершены • Финни — этап '
                      '${state.pet.developmentStage}',
                    )
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
                  else if ((period.status == GamePeriodStatus.active ||
                          period.status == GamePeriodStatus.readyToFinish) &&
                      VirtualDayRules.bedtimeReached(period.dayProgress))
                    FilledButton(
                      key: const Key('home-finish-day'),
                      onPressed: state.finishingDay ? null : onFinishDay,
                      child: Text(
                        state.finishingDay
                            ? 'Укладываем…'
                            : 'Уложить Финни спать',
                      ),
                    )
                  else if (period.status == GamePeriodStatus.active ||
                      period.status == GamePeriodStatus.readyToFinish)
                    FilledButton(
                      key: const Key('home-view-plan'),
                      onPressed: () => context.go('/budget'),
                      child: const Text('Посмотреть план'),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value:
                                          (state.gameState.savedAmount /
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
        .where((id) => id == 'financial_task' || id == 'savings_decision')
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
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
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
  const _DayStatusCard({required this.period, required this.completedDays});

  final GamePeriod? period;
  final int completedDays;

  @override
  Widget build(BuildContext context) {
    final (title, description) = switch (period?.status) {
      null when completedDays == 0 => (
        'Первый день с Финни',
        'Получи монеты и составь план на день.',
      ),
      null => (
        'День $completedDays завершён',
        'Можно начать день ${completedDays + 1}.',
      ),
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
          if (period.periodNumber == 1) ...[
            Text(
              'Ты получил ${period.baseIncome} 🪙',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.small),
            const Text(
              'Каждый день у тебя есть монеты на Финни.\n\n'
              'Сначала составь план: сколько потратить на нужное, '
              'сколько на желания, сколько отложить и сколько оставить '
              'на потом.\n\nПлан помогает принимать решения, но не '
              'запрещает изменить траты позже.',
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              'День ${period.periodNumber}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.small),
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

class CampaignEventDialog extends ConsumerWidget {
  const CampaignEventDialog({super.key, required this.walletBalance});

  final int walletBalance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(campaignEventControllerProvider);
    if (state is! CampaignEventReady) {
      return const PopScope(
        canPop: false,
        child: AlertDialog(content: Center(child: CircularProgressIndicator())),
      );
    }
    final controller = ref.read(campaignEventControllerProvider.notifier);
    final isBowl = state.kind == CampaignEventKind.day3Bowl;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(isBowl ? 'Ой! Миска Финни сломалась' : 'Сегодня акция!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isBowl
                  ? 'Это неожиданная нужная трата. Новая миска стоит 120 монет.'
                  : 'Лакомство обычно стоит 60 монет, а сейчас одну штуку '
                        'можно купить за 35. Купить по акции?',
            ),
            if (state.message case final message?) ...[
              const SizedBox(height: AppSpacing.small),
              Text(message),
            ],
          ],
        ),
        actions: [
          if (!isBowl)
            TextButton(
              key: const Key('campaign-promo-skip'),
              onPressed: state.mutating
                  ? null
                  : () async {
                      if (await controller.skipPromotion() && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
              child: const Text('Пропустить'),
            ),
          FilledButton(
            key: Key(isBowl ? 'campaign-buy-bowl' : 'campaign-promo-buy'),
            onPressed: state.mutating || (!isBowl && walletBalance < 35)
                ? null
                : () async {
                    final success = isBowl
                        ? await controller.purchaseBowl()
                        : await controller.buyPromotion();
                    if (success && context.mounted) Navigator.pop(context);
                  },
            child: Text(isBowl ? 'Купить новую миску — 120' : 'Купить за 35'),
          ),
          if (state.pending != null && state.message != null)
            FilledButton.tonal(
              key: const Key('campaign-retry'),
              onPressed: state.mutating
                  ? null
                  : () async {
                      if (await controller.retry() && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
              child: const Text('Проверить ещё раз'),
            ),
        ],
      ),
    );
  }
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
