import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/savings/savings_controller.dart';
import 'package:finny/features/savings/savings_screen.dart';
import 'package:finny/models/completed_goal.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'savings_core_test.dart' show goals;

class _StaticSavingsController extends SavingsController {
  _StaticSavingsController(this.initial);
  final SavingsViewState initial;
  @override
  SavingsViewState build() => initial;
  @override
  Future<void> load() async {}
}

GamePeriod testPeriod({
  GamePeriodStatus status = GamePeriodStatus.active,
  int planned = 100,
  int actual = 50,
}) => GamePeriod(
  id: 1,
  profileId: 1,
  definitionId: 'period_1',
  periodNumber: 1,
  startWalletBalance: 0,
  baseIncome: 500,
  extraIncome: 0,
  plannedNeed: 0,
  plannedWant: 0,
  plannedSavings: planned,
  plannedFree: 400,
  actualNeed: 0,
  actualWant: 0,
  actualSavings: actual,
  requiredCheckpoints: const ['savings_decision'],
  resolvedCheckpoints: actual > 0 ? const ['savings_decision'] : const [],
  growthPointsEarned: 0,
  status: status,
  createdAt: DateTime.utc(2026, 1, 1),
);

SavingsReady ready({
  String? activeGoalId,
  int saved = 0,
  int wallet = 500,
  GamePeriod? period,
  List<CompletedGoal> completed = const [],
}) => SavingsReady(
  profileId: 1,
  gameState: GameState(
    profileId: 1,
    walletBalance: wallet,
    currentPeriod: period?.periodNumber ?? 0,
    activeGoalId: activeGoalId,
    savedAmount: saved,
    updatedAt: DateTime.utc(2026, 1, 1),
  ),
  goals: goals,
  completedGoals: completed,
  period: period,
);

Future<void> pumpSavings(WidgetTester tester, SavingsReady initial) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        savingsControllerProvider.overrideWith(
          () => _StaticSavingsController(initial),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const SavingsScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('goal choice shows canonical cards and separate balances', (
    tester,
  ) async {
    await pumpSavings(tester, ready(saved: 25, wallet: 475));
    expect(find.text('Выбери цель накоплений'), findsOneWidget);
    expect(find.byKey(const Key('savings-wallet')), findsOneWidget);
    expect(find.byKey(const Key('savings-saved')), findsOneWidget);
    expect(find.text('Самокат'), findsWidgets);
  });

  testWidgets('active ready goal shows plan fact and deposit controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSavings(
      tester,
      ready(
        activeGoalId: 'goal_scooter',
        saved: 350,
        wallet: 150,
        period: testPeriod(status: GamePeriodStatus.readyToFinish),
      ),
    );
    expect(find.text('350 / 600'), findsOneWidget);
    expect(find.text('Планировал отложить: 100'), findsOneWidget);
    expect(find.text('Уже отложил: 50'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('savings-deposit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reached goal shows claim and excess remainder', (tester) async {
    await pumpSavings(
      tester,
      ready(activeGoalId: 'goal_night_light', saved: 700, wallet: 20),
    );
    expect(find.text('Цель достигнута!'), findsOneWidget);
    expect(find.text('После получения останется 300'), findsWidgets);
    expect(find.byKey(const Key('savings-claim')), findsOneWidget);
    expect(find.byKey(const Key('savings-deposit')), findsNothing);
  });

  testWidgets('planning disables deposit while active offers skip and change', (
    tester,
  ) async {
    await pumpSavings(
      tester,
      ready(
        activeGoalId: 'goal_scooter',
        period: testPeriod(status: GamePeriodStatus.planning, actual: 0),
      ),
    );
    expect(
      find.text('Реально отложить деньги можно после подтверждения плана дня.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('savings-deposit')), findsNothing);

    await pumpSavings(
      tester,
      ready(
        activeGoalId: 'goal_scooter',
        period: testPeriod(status: GamePeriodStatus.active, actual: 0),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('savings-skip')), findsOneWidget);
    expect(find.byKey(const Key('savings-change-goal')), findsOneWidget);
  });

  testWidgets('all completed goals show final state and leftover', (
    tester,
  ) async {
    final completed = [
      for (final goal in goals)
        CompletedGoal(
          profileId: 1,
          goalId: goal.id,
          rewardAssetId: goal.rewardAssetId,
          pricePaid: goal.price,
          completedAt: DateTime.utc(2026, 1, 1),
          claimOperationId: 'claim-${goal.id}',
        ),
    ];
    await pumpSavings(tester, ready(saved: 25, completed: completed));
    expect(find.text('Все финансовые цели достигнуты'), findsOneWidget);
    expect(find.text('В копилке осталось 25'), findsOneWidget);
    expect(find.text('Получено'), findsWidgets);
  });
}
