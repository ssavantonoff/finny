import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
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
  int _depositAmount = 10;

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
      appBar: AppBar(title: const Text('Накопления')),
      body: switch (state) {
        SavingsLoading() => const Center(child: CircularProgressIndicator()),
        SavingsNoProfile() => const _FailureBody(
          message: 'Профиль пока не выбран.',
        ),
        SavingsContentFailure() => _FailureBody(
          message: 'Не удалось загрузить финансовые цели.',
          onRetry: ref.read(savingsControllerProvider.notifier).load,
        ),
        SavingsRuntimeFailure() => _FailureBody(
          message: 'Не удалось открыть накопления.',
          onRetry: ref.read(savingsControllerProvider.notifier).load,
        ),
        SavingsReady() => _buildReady(context, state),
      },
    );
  }

  Widget _buildReady(BuildContext context, SavingsReady state) {
    if (state.maxDeposit > 0 && _depositAmount > state.maxDeposit) {
      _depositAmount = state.maxDeposit;
    }
    final active = state.activeGoal;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.medium,
          AppSpacing.medium,
          AppSpacing.medium,
          AppTheme.homeContentNavigationClearance +
              MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          _Balances(state: state),
          if (state.period != null) ...[
            const SizedBox(height: AppSpacing.medium),
            _PlanFact(period: state.period!),
          ],
          if (state.message != null) ...[
            const SizedBox(height: AppSpacing.medium),
            _Notice(state.message!),
          ],
          if (state.pendingOperation != null) ...[
            const SizedBox(height: AppSpacing.small),
            FilledButton.tonal(
              key: const Key('savings-retry'),
              onPressed: state.mutating
                  ? null
                  : ref
                        .read(savingsControllerProvider.notifier)
                        .retryPendingOperation,
              child: const Text('Повторить операцию'),
            ),
          ],
          const SizedBox(height: AppSpacing.large),
          if (state.allGoalsCompleted && active == null)
            _AllGoalsCompleted(state: state)
          else if (active == null)
            _GoalChoice(
              state: state,
              onGoal: (goal) => _confirmSelection(goal, state),
            )
          else ...[
            _ActiveGoalCard(state: state),
            const SizedBox(height: AppSpacing.medium),
            if (state.goalReached)
              _ReachedActions(state: state, onClaim: () => _confirmClaim(state))
            else ...[
              if (state.period?.status == GamePeriodStatus.planning)
                const _Notice(
                  'Реально отложить деньги можно после подтверждения плана дня.',
                ),
              if (state.period?.status == GamePeriodStatus.readyToFinish)
                const _Notice(
                  'День уже готов к завершению, но до его завершения ты ещё можешь пополнить копилку.',
                ),
              if (state.canDeposit) ...[
                const SizedBox(height: AppSpacing.medium),
                _DepositControls(
                  amount: _depositAmount.clamp(1, state.maxDeposit),
                  maximum: state.maxDeposit,
                  mutating: state.mutating,
                  onChanged: (value) => setState(() {
                    _depositAmount = value.clamp(1, state.maxDeposit);
                  }),
                  onDeposit: () => ref
                      .read(savingsControllerProvider.notifier)
                      .deposit(_depositAmount.clamp(1, state.maxDeposit)),
                ),
              ],
              if (state.canSkip) ...[
                const SizedBox(height: AppSpacing.small),
                TextButton(
                  key: const Key('savings-skip'),
                  onPressed: _confirmSkip,
                  child: const Text('Сегодня не откладывать'),
                ),
              ],
              if (state.canChange) ...[
                const SizedBox(height: AppSpacing.small),
                OutlinedButton(
                  key: const Key('savings-change-goal'),
                  onPressed: () => _chooseChangedGoal(state),
                  child: const Text('Сменить цель'),
                ),
              ],
            ],
          ],
          const SizedBox(height: AppSpacing.large),
          Text('Все цели', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.small),
          for (final goal in state.goals)
            Card(
              child: ListTile(
                title: Text(goal.name),
                subtitle: Text('${goal.price} 🪙'),
                trailing: state.completedGoalIds.contains(goal.id)
                    ? const Text('Получено')
                    : state.activeGoal?.id == goal.id
                    ? const Text('Активна')
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmSelection(SavingsGoal goal, SavingsReady state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(goal.name),
        content: Text(
          '${goal.description}\n\nЦена: ${goal.price} 🪙\n'
          'В копилке уже ${state.gameState.savedAmount} 🪙'
          '${state.gameState.savedAmount >= goal.price ? '\nПосле выбора цель сразу будет достигнута.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выбрать'),
          ),
        ],
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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Text(
                state.freePlay
                    ? 'Цель можно менять снова. Накопленные деньги сохранятся.'
                    : 'Цель можно поменять только один раз. Накопленные деньги сохранятся. После смены вторую смену сделать нельзя до получения цели.',
                textAlign: TextAlign.center,
              ),
            ),
            for (final goal in candidates)
              ListTile(
                title: Text(goal.name),
                subtitle: Text('${goal.price} 🪙'),
                onTap: () => Navigator.pop(context, goal),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      await ref
          .read(savingsControllerProvider.notifier)
          .changeGoal(selected.id);
    }
  }

  Future<void> _confirmSkip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сегодня ничего не откладывать?'),
        content: const Text('Позже в этом дне ты всё ещё сможешь передумать.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(savingsControllerProvider.notifier).skipToday();
    }
  }

  Future<void> _confirmClaim(SavingsReady state) async {
    final goal = state.activeGoal!;
    final remainder = state.gameState.savedAmount - goal.price;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Получить цель?'),
        content: Text(
          'Получить «${goal.name}» за ${goal.price} монет из копилки?\n'
          'После получения останется $remainder 🪙.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const Key('savings-confirm-claim'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Получить'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(savingsControllerProvider.notifier).claimGoal();
    }
  }
}

class _Balances extends StatelessWidget {
  const _Balances({required this.state});
  final SavingsReady state;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              children: [
                const Text('В кошельке'),
                Text(
                  '${state.gameState.walletBalance} 🪙',
                  key: const Key('savings-wallet'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
      ),
      Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              children: [
                const Text('В копилке'),
                Text(
                  '${state.gameState.savedAmount} 🪙',
                  key: const Key('savings-saved'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _PlanFact extends StatelessWidget {
  const _PlanFact({required this.period});
  final GamePeriod period;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Row(
        children: [
          Expanded(
            child: Text('Планировал отложить: ${period.plannedSavings}'),
          ),
          Expanded(child: Text('Уже отложил: ${period.actualSavings}')),
        ],
      ),
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
      Text(
        'Выбери цель накоплений',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: AppSpacing.small),
      for (final goal in state.goals)
        Card(
          child: ListTile(
            enabled:
                !state.completedGoalIds.contains(goal.id) && !state.mutating,
            title: Text(goal.name),
            subtitle: Text('${goal.description}\n${goal.price} 🪙'),
            trailing: state.completedGoalIds.contains(goal.id)
                ? const Text('Получено')
                : const Icon(Icons.chevron_right),
            onTap: state.completedGoalIds.contains(goal.id)
                ? null
                : () => onGoal(goal),
          ),
        ),
    ],
  );
}

class _ActiveGoalCard extends StatelessWidget {
  const _ActiveGoalCard({required this.state});
  final SavingsReady state;
  @override
  Widget build(BuildContext context) {
    final goal = state.activeGoal!;
    final saved = state.gameState.savedAmount;
    final remainder = saved - goal.price;
    return Card(
      key: const Key('savings-active-goal'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(goal.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.small),
            Text('$saved / ${goal.price}'),
            const SizedBox(height: AppSpacing.small),
            LinearProgressIndicator(value: (saved / goal.price).clamp(0, 1)),
            const SizedBox(height: AppSpacing.small),
            Text('Осталось ${state.missingAmount}'),
            if (remainder > 0) Text('После получения останется $remainder'),
          ],
        ),
      ),
    );
  }
}

class _DepositControls extends StatelessWidget {
  const _DepositControls({
    required this.amount,
    required this.maximum,
    required this.mutating,
    required this.onChanged,
    required this.onDeposit,
  });
  final int amount;
  final int maximum;
  final bool mutating;
  final ValueChanged<int> onChanged;
  final VoidCallback onDeposit;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        children: [
          Text('Отложить $amount 🪙', key: const Key('savings-deposit-amount')),
          Wrap(
            spacing: AppSpacing.small,
            alignment: WrapAlignment.center,
            children: [
              IconButton(
                onPressed: amount > 1 ? () => onChanged(amount - 10) : null,
                icon: const Icon(Icons.remove),
              ),
              IconButton(
                onPressed: amount < maximum
                    ? () => onChanged(amount + 10)
                    : null,
                icon: const Icon(Icons.add),
              ),
              TextButton(
                onPressed: () => onChanged(50),
                child: const Text('50'),
              ),
              TextButton(
                onPressed: () => onChanged(100),
                child: const Text('100'),
              ),
              TextButton(
                onPressed: () => onChanged(maximum),
                child: const Text('Максимум'),
              ),
            ],
          ),
          FilledButton(
            key: const Key('savings-deposit'),
            onPressed: mutating ? null : onDeposit,
            child: Text(mutating ? 'Сохраняем…' : 'Отложить'),
          ),
        ],
      ),
    ),
  );
}

class _ReachedActions extends StatelessWidget {
  const _ReachedActions({required this.state, required this.onClaim});
  final SavingsReady state;
  final VoidCallback onClaim;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Цель достигнута!',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('Накоплено: ${state.gameState.savedAmount}'),
          Text('Цена: ${state.activeGoal!.price}'),
          Text(
            'После получения останется ${state.gameState.savedAmount - state.activeGoal!.price}',
          ),
          FilledButton(
            key: const Key('savings-claim'),
            onPressed: state.canClaim ? onClaim : null,
            child: const Text('Получить цель'),
          ),
        ],
      ),
    ),
  );
}

class _AllGoalsCompleted extends ConsumerWidget {
  const _AllGoalsCompleted({required this.state});
  final SavingsReady state;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Все финансовые цели достигнуты',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (state.gameState.savedAmount > 0)
            Text('В копилке осталось ${state.gameState.savedAmount}'),
          if (state.canResolveAllGoals)
            FilledButton(
              key: const Key('savings-all-goals-continue'),
              onPressed: ref
                  .read(savingsControllerProvider.notifier)
                  .resolveAllGoalsCompletedDecision,
              child: const Text('Продолжить день'),
            ),
        ],
      ),
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

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.medium),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Попробовать снова'),
            ),
          ],
        ],
      ),
    ),
  );
}
