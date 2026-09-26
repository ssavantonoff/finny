import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_art.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_models.dart';
import 'package:finny/features/savings/savings_controller.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SavingsScreen extends ConsumerStatefulWidget {
  const SavingsScreen({super.key});

  @override
  ConsumerState<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends ConsumerState<SavingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(ref.read(savingsControllerProvider.notifier).load);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savingsControllerProvider);
    ref.listen<int?>(activeProfileIdProvider, (_, _) {
      ref.read(savingsControllerProvider.notifier).load();
    });
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _SavingsBackdrop()),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  key: const Key('savings-content'),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    24,
                    16,
                    AppTheme.homeContentNavigationClearance +
                        MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 20),
                      child: Text(
                        'Накопления',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    switch (state) {
                      SavingsLoading() => const _LoadingState(),
                      SavingsNoProfile() => const _FailureState(
                        message: 'Профиль пока не выбран.',
                      ),
                      SavingsContentFailure() => _FailureState(
                        message: 'Не удалось загрузить финансовые цели.',
                        onRetry: ref
                            .read(savingsControllerProvider.notifier)
                            .load,
                      ),
                      SavingsRuntimeFailure() => _FailureState(
                        message: 'Не удалось открыть накопления.',
                        onRetry: ref
                            .read(savingsControllerProvider.notifier)
                            .load,
                      ),
                      SavingsReady() => _readyContent(state),
                    },
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readyContent(SavingsReady state) {
    final active = state.activeGoal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Balances(state: state),
        const SizedBox(height: 16),
        if (state.message != null) ...[
          _Notice(
            state.message!,
            icon: Icons.info_outline_rounded,
            error: true,
          ),
          const SizedBox(height: 10),
        ],
        if (state.pendingOperation != null) ...[
          OutlinedButton.icon(
            key: const Key('savings-retry'),
            onPressed: state.mutating
                ? null
                : ref
                      .read(savingsControllerProvider.notifier)
                      .retryPendingOperation,
            style: _outlineStyle,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
          ),
          const SizedBox(height: 10),
        ],
        if (state.allGoalsCompleted && active == null)
          _AllGoalsCompleted(
            state: state,
            onContinue: ref
                .read(savingsControllerProvider.notifier)
                .resolveAllGoalsCompletedDecision,
          )
        else if (active == null)
          _GoalChoice(
            state: state,
            onGoal: (goal) => _confirmSelection(goal, state),
          )
        else ...[
          _ActiveGoalHero(state: state),
          if (state.period != null) ...[
            const SizedBox(height: 12),
            _TodaySummary(period: state.period!),
          ],
          if (state.goalReached) ...[
            const SizedBox(height: 14),
            _PrimaryAction(
              key: const Key('savings-claim'),
              label: 'Получить цель',
              onPressed: state.canClaim ? () => _confirmClaim(state) : null,
            ),
          ] else ...[
            if (state.period?.status == GamePeriodStatus.planning) ...[
              const SizedBox(height: 12),
              const _Notice(
                'Пополнить копилку можно после подтверждения плана дня.',
                icon: Icons.info_outline_rounded,
              ),
            ],
            if (state.period?.status == GamePeriodStatus.readyToFinish) ...[
              const SizedBox(height: 12),
              const _Notice(
                'День уже готов к завершению, но до его завершения ты ещё можешь пополнить копилку.',
                icon: Icons.info_outline_rounded,
              ),
            ],
            const SizedBox(height: 14),
            _PrimaryAction(
              key: const Key('savings-open-deposit'),
              label: 'Пополнить копилку',
              onPressed: state.canDeposit ? () => _openDeposit(state) : null,
            ),
            if (state.canSkip)
              TextButton(
                key: const Key('savings-skip'),
                onPressed: _confirmSkip,
                child: const Text('Сегодня не откладывать'),
              ),
            if (state.canChange) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('savings-change-goal'),
                onPressed: () => _chooseChangedGoal(state),
                style: _outlineStyle,
                child: const Text('Сменить цель'),
              ),
            ],
          ],
          const SizedBox(height: 24),
          const _SectionTitle('Все цели'),
          const SizedBox(height: 10),
          for (final goal in state.goals) ...[
            _GoalTile(goal: goal, state: state),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Future<void> _openDeposit(SavingsReady state) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DepositSheet(initial: state),
  );

  Future<void> _confirmSelection(SavingsGoal goal, SavingsReady state) async {
    final saved = state.gameState.savedAmount;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmationSheet(
        title: 'Выбрать «${goal.name}»?',
        art: _GoalArt(goal: goal, size: 72),
        lines: [
          _CoinLine(label: 'Цена', amount: goal.price),
          _CoinLine(label: 'В копилке', amount: saved),
          LinearProgressIndicator(
            value: (saved / goal.price).clamp(0, 1).toDouble(),
          ),
          Text(
            saved >= goal.price
                ? 'После выбора цель сразу будет достигнута.'
                : 'Останется накопить ${goal.price - saved} монет.',
          ),
        ],
        confirmLabel: 'Выбрать цель',
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(savingsControllerProvider.notifier).selectGoal(goal.id);
    }
  }

  Future<void> _chooseChangedGoal(SavingsReady state) async {
    final candidates = state.availableGoals
        .where((goal) => goal.id != state.activeGoal!.id)
        .toList(growable: false);
    final selected = await showModalBottomSheet<SavingsGoal>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangeGoalSheet(state: state, candidates: candidates),
    );
    if (selected != null && mounted) {
      await ref
          .read(savingsControllerProvider.notifier)
          .changeGoal(selected.id);
    }
  }

  Future<void> _confirmSkip() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ConfirmationSheet(
        title: 'Сегодня ничего не откладывать?',
        lines: [Text('Позже в этом дне ты всё ещё сможешь передумать.')],
        confirmLabel: 'Подтвердить',
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(savingsControllerProvider.notifier).skipToday();
    }
  }

  Future<void> _confirmClaim(SavingsReady state) async {
    final goal = state.activeGoal!;
    final saved = state.gameState.savedAmount;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmationSheet(
        title: 'Получить «${goal.name}»?',
        art: _GoalArt(goal: goal, size: 72),
        lines: [
          _CoinLine(label: 'Цена', amount: goal.price),
          _CoinLine(label: 'В копилке', amount: saved),
          _CoinLine(label: 'Останется', amount: saved - goal.price),
        ],
        confirmLabel: 'Получить',
        confirmKey: const Key('savings-confirm-claim'),
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(savingsControllerProvider.notifier).claimGoal();
    }
  }
}

const _outlineStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size.fromHeight(50)),
  foregroundColor: WidgetStatePropertyAll(AppColors.primaryDark),
  side: WidgetStatePropertyAll(BorderSide(color: AppColors.primary)),
);

class _SavingsBackdrop extends StatelessWidget {
  const _SavingsBackdrop();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF8F7FF), Color(0xFFEFEDFF)],
      ),
    ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.highlight = false,
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  final bool highlight;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.91),
      borderRadius: BorderRadius.circular(AppRadii.card),
      border: Border.all(
        color: highlight ? AppColors.primary : Colors.white,
        width: highlight ? 1.5 : 1,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x160D0C52),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Padding(padding: padding, child: child),
  );
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.onPressed,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFD8D2FA),
        disabledForegroundColor: const Color(0xFF8176BA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 21,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _CoinAmount extends StatelessWidget {
  const _CoinAmount(
    this.amount, {
    this.fontSize = 20,
    this.coinSize = 24,
    super.key,
  });
  final int amount;
  final double fontSize;
  final double coinSize;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$amount',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(width: 5),
      FinnyCatchArt(type: FinnyCatchObjectType.coin, size: coinSize),
    ],
  );
}

class _GoalArt extends StatelessWidget {
  const _GoalArt({required this.goal, required this.size});
  final SavingsGoal goal;
  final double size;
  @override
  Widget build(BuildContext context) {
    final icon = switch (goal.rewardAssetId) {
      'reward_night_light' => Icons.nightlight_round,
      'reward_scooter' => Icons.electric_scooter_rounded,
      'reward_play_house' => Icons.cottage_rounded,
      _ => Icons.card_giftcard_rounded,
    };
    return Semantics(
      image: true,
      label: goal.name,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF7F2FF), Color(0xFFE9E3FF)],
          ),
          borderRadius: BorderRadius.circular(size * 0.27),
        ),
        child: Icon(icon, color: AppColors.primaryDark, size: size * 0.57),
      ),
    );
  }
}

class _Balances extends StatelessWidget {
  const _Balances({required this.state});
  final SavingsReady state;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _balance(
          'В кошельке',
          state.gameState.walletBalance,
          Icons.account_balance_wallet_rounded,
          const Key('savings-wallet'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _balance(
          'В копилке',
          state.gameState.savedAmount,
          Icons.savings_rounded,
          const Key('savings-saved'),
        ),
      ),
    ],
  );

  Widget _balance(String label, int value, IconData icon, Key key) => _Surface(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    child: Row(
      children: [
        Icon(icon, size: 30, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Row(
                  children: [
                    Text(
                      '$value',
                      key: key,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const FinnyCatchArt(
                      type: FinnyCatchObjectType.coin,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActiveGoalHero extends StatelessWidget {
  const _ActiveGoalHero({required this.state});
  final SavingsReady state;
  @override
  Widget build(BuildContext context) {
    final goal = state.activeGoal!;
    final saved = state.gameState.savedAmount;
    final reached = state.goalReached;
    return _Surface(
      key: const Key('savings-active-goal'),
      padding: const EdgeInsets.all(20),
      highlight: reached,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reached)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Цель достигнута!',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  goal.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _GoalArt(goal: goal, size: 88),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$saved / ${goal.price}',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              key: const Key('savings-goal-progress'),
              value: (saved / goal.price).clamp(0, 1).toDouble(),
              minHeight: 11,
              backgroundColor: AppColors.primaryLight,
              color: reached ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            reached
                ? 'Накоплено достаточно'
                : 'Осталось ${state.missingAmount} монет',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (reached && saved > goal.price)
            Text(
              'После получения останется ${saved - goal.price} монет',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.period});
  final GamePeriod period;
  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Сегодня'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _todayValue(
                'Планировал отложить',
                period.plannedSavings,
                Icons.event_note_rounded,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _todayValue(
                'Уже отложил',
                period.actualSavings,
                Icons.check_circle_rounded,
                period.actualSavings > period.plannedSavings
                    ? AppColors.success
                    : AppColors.savings,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _todayValue(String label, int amount, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            _CoinAmount(amount, fontSize: 16, coinSize: 16),
          ],
        ),
      );
}

class _GoalChoice extends StatelessWidget {
  const _GoalChoice({required this.state, required this.onGoal});
  final SavingsReady state;
  final ValueChanged<SavingsGoal> onGoal;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Выбери цель накоплений'),
            const SizedBox(height: 6),
            const Text(
              'Накопленные монеты сохраняются, даже если ты меняешь цель.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            if (state.gameState.savedAmount > 0) ...[
              const SizedBox(height: 8),
              _CoinAmount(
                state.gameState.savedAmount,
                fontSize: 17,
                coinSize: 19,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (final goal in state.goals) ...[
        _GoalTile(
          goal: goal,
          state: state,
          expanded: true,
          onTap: state.completedGoalIds.contains(goal.id) || state.mutating
              ? null
              : () => onGoal(goal),
        ),
        const SizedBox(height: 8),
      ],
    ],
  );
}

String _goalStatus(SavingsReady state, SavingsGoal goal) {
  if (state.completedGoalIds.contains(goal.id)) return 'Получено';
  if (state.activeGoal?.id == goal.id) return 'Активна';
  final missing = goal.price - state.gameState.savedAmount;
  return missing <= 0 ? 'Накоплено достаточно' : 'Осталось $missing';
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.state,
    this.expanded = false,
    this.onTap,
  });
  final SavingsGoal goal;
  final SavingsReady state;
  final bool expanded;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final status = _goalStatus(state, goal);
    final active = state.activeGoal?.id == goal.id;
    final complete = state.completedGoalIds.contains(goal.id);
    return _Surface(
      key: Key('savings-goal-${goal.id}'),
      highlight: active,
      padding: EdgeInsets.all(expanded ? 14 : 11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            _GoalArt(goal: goal, size: expanded ? 70 : 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (expanded)
                    Text(
                      goal.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  const SizedBox(height: 4),
                  _CoinAmount(goal.price, fontSize: 14, coinSize: 16),
                  if (expanded) ...[
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (state.gameState.savedAmount / goal.price)
                          .clamp(0, 1)
                          .toDouble(),
                      minHeight: 4,
                      backgroundColor: AppColors.primaryLight,
                      color: AppColors.primary,
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    status,
                    style: TextStyle(
                      color: complete || status == 'Накоплено достаточно'
                          ? AppColors.success
                          : active
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _AllGoalsCompleted extends StatelessWidget {
  const _AllGoalsCompleted({required this.state, required this.onContinue});
  final SavingsReady state;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.success,
              size: 44,
            ),
            const SizedBox(height: 8),
            const _SectionTitle('Все финансовые цели достигнуты'),
            if (state.gameState.savedAmount > 0) ...[
              const SizedBox(height: 8),
              Text('В копилке осталось ${state.gameState.savedAmount} монет'),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (final goal in state.goals) ...[
        _GoalTile(goal: goal, state: state),
        const SizedBox(height: 8),
      ],
      if (state.canResolveAllGoals) ...[
        const SizedBox(height: 12),
        _PrimaryAction(
          key: const Key('savings-all-goals-continue'),
          label: 'Продолжить день',
          onPressed: onContinue,
        ),
      ],
    ],
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {required this.icon, this.error = false});
  final String message;
  final IconData icon;
  final bool error;
  @override
  Widget build(BuildContext context) => _Surface(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: error ? AppColors.error : AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const _Surface(
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    ),
  );
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          _PrimaryAction(label: 'Попробовать снова', onPressed: onRetry),
        ],
      ],
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    decoration: const BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: child,
      ),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Center(
        child: Container(
          width: 38,
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Закрыть',
            onPressed: () => Navigator.pop(context),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.close_rounded, color: AppColors.primary),
          ),
        ],
      ),
      if (subtitle != null)
        Text(
          subtitle!,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
    ],
  );
}

class _CoinLine extends StatelessWidget {
  const _CoinLine({required this.label, required this.amount});
  final String label;
  final int amount;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
      _CoinAmount(amount, fontSize: 17, coinSize: 19),
    ],
  );
}

class _ConfirmationSheet extends StatelessWidget {
  const _ConfirmationSheet({
    required this.title,
    required this.lines,
    required this.confirmLabel,
    this.art,
    this.confirmKey,
  });
  final String title;
  final List<Widget> lines;
  final String confirmLabel;
  final Widget? art;
  final Key? confirmKey;
  @override
  Widget build(BuildContext context) => _SheetFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetHeader(title: title),
        if (art != null)
          Center(
            child: Padding(padding: const EdgeInsets.all(12), child: art),
          ),
        const SizedBox(height: 12),
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final line in lines) ...[line, const SizedBox(height: 8)],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PrimaryAction(
          key: confirmKey,
          label: confirmLabel,
          onPressed: () => Navigator.pop(context, true),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
      ],
    ),
  );
}

class _ChangeGoalSheet extends StatefulWidget {
  const _ChangeGoalSheet({required this.state, required this.candidates});
  final SavingsReady state;
  final List<SavingsGoal> candidates;
  @override
  State<_ChangeGoalSheet> createState() => _ChangeGoalSheetState();
}

class _ChangeGoalSheetState extends State<_ChangeGoalSheet> {
  SavingsGoal? selected;
  @override
  Widget build(BuildContext context) => _SheetFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetHeader(title: 'Сменить цель'),
        const SizedBox(height: 8),
        Text(
          'В копилке сейчас ${widget.state.gameState.savedAmount} монет. Они сохранятся.',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.state.freePlay
              ? 'Накопленные монеты сохранятся. Цель можно будет поменять снова.'
              : 'Цель можно поменять только один раз. Накопленные монеты сохранятся.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),
        for (final goal in widget.candidates) ...[
          InkWell(
            key: Key('savings-change-candidate-${goal.id}'),
            onTap: () => setState(() => selected = goal),
            child: _Surface(
              highlight: selected?.id == goal.id,
              child: Row(
                children: [
                  _GoalArt(goal: goal, size: 56),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        _CoinAmount(goal.price, fontSize: 14, coinSize: 16),
                        LinearProgressIndicator(
                          value:
                              (widget.state.gameState.savedAmount / goal.price)
                                  .clamp(0, 1)
                                  .toDouble(),
                          minHeight: 4,
                          backgroundColor: AppColors.primaryLight,
                          color: AppColors.primary,
                        ),
                        Text(
                          _goalStatus(widget.state, goal),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected?.id == goal.id)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),
        _PrimaryAction(
          key: const Key('savings-confirm-change-goal'),
          label: 'Сменить цель',
          onPressed: selected == null
              ? null
              : () => Navigator.pop(context, selected),
        ),
      ],
    ),
  );
}

class _DepositSheet extends ConsumerStatefulWidget {
  const _DepositSheet({required this.initial});
  final SavingsReady initial;
  @override
  ConsumerState<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<_DepositSheet> {
  int amount = 10;
  bool submitting = false;

  Future<void> _run(Future<void> Function() action) async {
    if (submitting) return;
    setState(() => submitting = true);
    await action();
    if (!mounted) return;
    final latest = ref.read(savingsControllerProvider);
    if (latest is SavingsReady &&
        latest.pendingOperation == null &&
        latest.message == null &&
        latest.gameState.savedAmount > widget.initial.gameState.savedAmount) {
      Navigator.pop(context);
    } else {
      setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(savingsControllerProvider);
    final state = current is SavingsReady ? current : widget.initial;
    final max = state.maxDeposit;
    final selected = amount.clamp(1, max < 1 ? 1 : max);
    final blocked =
        submitting ||
        state.mutating ||
        state.pendingOperation != null ||
        max <= 0;
    final wallet = state.gameState.walletBalance;
    final saved = state.gameState.savedAmount;
    return _SheetFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHeader(
            title: 'Сколько отложить?',
            subtitle: 'Выбери сумму для копилки',
          ),
          const SizedBox(height: 14),
          Center(
            child: _CoinAmount(
              selected,
              fontSize: 42,
              coinSize: 48,
              key: const Key('savings-deposit-amount'),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _stepButton(
                    Icons.remove_rounded,
                    'Уменьшить сумму',
                    selected > 1 && !blocked
                        ? () => setState(
                            () => amount = (selected - 10).clamp(1, max),
                          )
                        : null,
                  ),
                  SizedBox(
                    width: 74,
                    child: Text(
                      '$selected',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _stepButton(
                    Icons.add_rounded,
                    'Увеличить сумму',
                    selected < max && !blocked
                        ? () => setState(
                            () => amount = (selected + 10).clamp(1, max),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _quick(
                  '+50',
                  const Key('savings-deposit-plus-50'),
                  blocked
                      ? null
                      : () => setState(
                          () => amount = (selected + 50).clamp(1, max),
                        ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _quick(
                  '+100',
                  const Key('savings-deposit-plus-100'),
                  blocked
                      ? null
                      : () => setState(
                          () => amount = (selected + 100).clamp(1, max),
                        ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _quick(
                  'Максимум ($max)',
                  const Key('savings-deposit-maximum'),
                  blocked ? null : () => setState(() => amount = max),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _preview('В кошельке', wallet, wallet - selected),
                const Divider(height: 16),
                _preview('В копилке', saved, saved + selected),
                const SizedBox(height: 8),
                Text(
                  'До цели останется ${((state.activeGoal?.price ?? 0) - saved - selected).clamp(0, state.activeGoal?.price ?? 0)} монет',
                  key: const Key('savings-deposit-missing-after'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (state.message != null) ...[
            const SizedBox(height: 10),
            _Notice(
              state.message!,
              icon: Icons.info_outline_rounded,
              error: true,
            ),
          ],
          if (state.pendingOperation != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('savings-retry-in-sheet'),
              onPressed: submitting
                  ? null
                  : () => _run(
                      ref
                          .read(savingsControllerProvider.notifier)
                          .retryPendingOperation,
                    ),
              style: _outlineStyle,
              child: const Text('Повторить'),
            ),
          ],
          const SizedBox(height: 14),
          _PrimaryAction(
            key: const Key('savings-deposit'),
            label: submitting || state.mutating
                ? 'Сохраняем…'
                : 'Отложить $selected',
            onPressed: blocked
                ? null
                : () => _run(
                    () => ref
                        .read(savingsControllerProvider.notifier)
                        .deposit(selected),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, String tooltip, VoidCallback? onPressed) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        icon: Icon(icon),
      );

  Widget _quick(String label, Key key, VoidCallback? onPressed) =>
      OutlinedButton(
        key: key,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 3),
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );

  Widget _preview(String label, int before, int after) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Text(
        '$before → $after',
        key: Key(
          label == 'В кошельке'
              ? 'savings-wallet-preview'
              : 'savings-saved-preview',
        ),
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(width: 5),
      const FinnyCatchArt(type: FinnyCatchObjectType.coin, size: 17),
    ],
  );
}
