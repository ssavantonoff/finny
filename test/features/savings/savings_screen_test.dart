import 'dart:async';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/savings/savings_controller.dart';
import 'package:finny/features/savings/savings_screen.dart';
import 'package:finny/models/completed_goal.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'savings_core_test.dart' show goals;

class _RecordingSavingsController extends SavingsController {
  _RecordingSavingsController(this.initial);
  final SavingsViewState initial;
  int? deposited;
  String? selectedGoalId;
  String? changedGoalId;
  int claims = 0;
  int skips = 0;
  int retries = 0;
  int continuations = 0;
  Completer<void>? depositGate;

  @override
  SavingsViewState build() => initial;
  @override
  Future<void> load() async {}

  @override
  Future<void> selectGoal(String goalId) async {
    selectedGoalId = goalId;
    final current = state as SavingsReady;
    state = current.copyWith(
      gameState: current.gameState.copyWith(activeGoalId: goalId),
    );
  }

  @override
  Future<void> changeGoal(String goalId) async {
    changedGoalId = goalId;
    final current = state as SavingsReady;
    state = current.copyWith(
      gameState: current.gameState.copyWith(
        activeGoalId: goalId,
        goalChangeUsed: !current.freePlay,
      ),
    );
  }

  @override
  Future<void> deposit(int amount) async {
    deposited = amount;
    final current = state as SavingsReady;
    state = current.copyWith(mutating: true);
    if (depositGate case final gate?) await gate.future;
    final period = current.period;
    state = current.copyWith(
      mutating: false,
      gameState: current.gameState.copyWith(
        walletBalance: current.gameState.walletBalance - amount,
        savedAmount: current.gameState.savedAmount + amount,
      ),
      period: period?.copyWith(actualSavings: period.actualSavings + amount),
    );
  }

  @override
  Future<void> claimGoal() async {
    claims++;
    final current = state as SavingsReady;
    final goal = current.activeGoal!;
    state = current.copyWith(
      gameState: current.gameState.copyWith(
        savedAmount: current.gameState.savedAmount - goal.price,
        clearActiveGoal: true,
      ),
      completedGoals: [
        ...current.completedGoals,
        CompletedGoal(
          profileId: current.profileId,
          goalId: goal.id,
          rewardAssetId: goal.rewardAssetId,
          pricePaid: goal.price,
          completedAt: DateTime.utc(2026),
          claimOperationId: 'test-${goal.id}',
        ),
      ],
    );
  }

  @override
  Future<void> skipToday() async {
    skips++;
  }

  @override
  Future<void> retryPendingOperation() async {
    retries++;
  }

  @override
  Future<void> resolveAllGoalsCompletedDecision() async {
    continuations++;
  }
}

GamePeriod testPeriod({
  GamePeriodStatus status = GamePeriodStatus.active,
  int planned = 70,
  int actual = 110,
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
  bool freePlay = false,
  bool goalChangeUsed = false,
  String? message,
  PendingSavingsOperation? pending,
  List<SavingsGoal>? goalList,
}) => SavingsReady(
  profileId: 1,
  gameState: GameState(
    profileId: 1,
    walletBalance: wallet,
    currentPeriod: period?.periodNumber ?? 0,
    activeGoalId: activeGoalId,
    savedAmount: saved,
    goalChangeUsed: goalChangeUsed,
    updatedAt: DateTime.utc(2026, 1, 1),
  ),
  goals: goalList ?? goals,
  completedGoals: completed,
  period: period,
  freePlay: freePlay,
  message: message,
  pendingOperation: pending,
);

Future<_RecordingSavingsController> _pumpSavings(
  WidgetTester tester,
  SavingsViewState initial, {
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = _RecordingSavingsController(initial);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [savingsControllerProvider.overrideWith(() => controller)],
      child: MaterialApp(theme: AppTheme.light, home: const SavingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

List<CompletedGoal> completedGoals([int count = 3]) => [
  for (final goal in goals.take(count))
    CompletedGoal(
      profileId: 1,
      goalId: goal.id,
      rewardAssetId: goal.rewardAssetId,
      pricePaid: goal.price,
      completedAt: DateTime.utc(2026),
      claimOperationId: 'claim-${goal.id}',
    ),
];

void main() {
  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets('production goal names fit $size', (tester) async {
      const productionGoals = [
        SavingsGoal(
          id: 'goal_night_light',
          name: 'Ночник для Финни',
          price: 400,
          description: 'Накопи на уютный ночник для комнаты Финни.',
          rewardAssetId: 'reward_night_light',
        ),
        SavingsGoal(
          id: 'goal_scooter',
          name: 'Самокат для Финни',
          price: 600,
          description: 'Накопи на самокат для прогулок с Финни.',
          rewardAssetId: 'reward_scooter',
        ),
        SavingsGoal(
          id: 'goal_play_house',
          name: 'Игровой домик для Финни',
          price: 900,
          description: 'Накопи на игровой домик для комнаты Финни.',
          rewardAssetId: 'reward_play_house',
        ),
      ];
      await _pumpSavings(
        tester,
        ready(
          activeGoalId: 'goal_play_house',
          saved: 590,
          wallet: 405,
          period: testPeriod(),
          goalList: productionGoals,
        ),
        size: size,
      );
      expect(find.text('Игровой домик для Финни'), findsWidgets);
      await tester.ensureVisible(
        find.byKey(const Key('savings-goal-goal_play_house')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('active goal hierarchy and balances fit $size', (tester) async {
      await _pumpSavings(
        tester,
        ready(
          activeGoalId: 'goal_play_house',
          saved: 590,
          wallet: 405,
          period: testPeriod(),
        ),
        size: size,
      );
      expect(find.byKey(const Key('savings-wallet')), findsOneWidget);
      expect(find.byKey(const Key('savings-saved')), findsOneWidget);
      expect(find.text('590 / 900'), findsOneWidget);
      expect(find.text('Осталось 310 монет'), findsOneWidget);
      expect(find.byKey(const Key('savings-goal-progress')), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const Key('savings-goal-progress')),
            )
            .value,
        closeTo(590 / 900, 0.001),
      );
      expect(find.text('Планировал отложить'), findsOneWidget);
      expect(find.text('Уже отложил'), findsOneWidget);
      expect(find.byKey(const Key('savings-open-deposit')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('savings-change-goal')));
      expect(find.byKey(const Key('savings-change-goal')), findsOneWidget);
      expect(find.text('Активна'), findsOneWidget);
      expect(find.text('Накоплено достаточно'), findsOneWidget);
      expect(find.text('Осталось 10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('deposit sheet previews and additive controls fit $size', (
      tester,
    ) async {
      final controller = await _pumpSavings(
        tester,
        ready(
          activeGoalId: 'goal_play_house',
          saved: 590,
          wallet: 405,
          period: testPeriod(),
        ),
        size: size,
      );
      await tapVisible(tester, find.byKey(const Key('savings-open-deposit')));
      expect(find.text('Сколько отложить?'), findsOneWidget);
      expect(find.text('Максимум (310)'), findsOneWidget);
      expect(find.text('405 → 395'), findsOneWidget);
      await tester.tap(find.byTooltip('Увеличить сумму'));
      await tester.pumpAndSettle();
      expect(find.text('Отложить 20'), findsOneWidget);
      await tester.tap(find.byTooltip('Уменьшить сумму'));
      await tester.pumpAndSettle();
      expect(find.text('Отложить 10'), findsOneWidget);
      await tester.tap(find.byKey(const Key('savings-deposit-plus-50')));
      await tester.pumpAndSettle();
      expect(find.text('Отложить 60'), findsOneWidget);
      await tester.tap(find.byKey(const Key('savings-deposit-plus-50')));
      await tester.pumpAndSettle();
      expect(find.text('Отложить 110'), findsOneWidget);
      expect(find.text('405 → 295'), findsOneWidget);
      expect(find.text('590 → 700'), findsOneWidget);
      expect(find.text('До цели останется 200 монет'), findsOneWidget);
      await tester.tap(find.byKey(const Key('savings-deposit-plus-100')));
      await tester.pumpAndSettle();
      expect(find.text('Отложить 210'), findsOneWidget);
      await tester.tap(find.byKey(const Key('savings-deposit-plus-100')));
      await tester.pumpAndSettle();
      expect(find.text('Отложить 310'), findsOneWidget);
      await tester.tap(find.byKey(const Key('savings-deposit-maximum')));
      await tester.pumpAndSettle();
      expect(find.text('Отложить 310'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('savings-deposit')));
      await tester.pumpAndSettle();
      expect(controller.deposited, 310);
      expect(find.text('715'), findsNothing);
      expect(find.text('900 / 900'), findsOneWidget);
    });
  }

  testWidgets('deposit sheet disables repeated submit while mutating', (
    tester,
  ) async {
    final controller = await _pumpSavings(
      tester,
      ready(
        activeGoalId: 'goal_play_house',
        saved: 590,
        wallet: 405,
        period: testPeriod(),
      ),
    );
    controller.depositGate = Completer<void>();
    await tapVisible(tester, find.byKey(const Key('savings-open-deposit')));
    await tester.tap(find.byKey(const Key('savings-deposit')));
    await tester.pump();
    expect(find.text('Сохраняем…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const Key('savings-deposit')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(controller.deposited, 10);
    controller.depositGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Сколько отложить?'), findsNothing);
    expect((controller.state as SavingsReady).gameState.savedAmount, 600);
  });

  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets('goal selection, change and claim sheets fit $size', (
      tester,
    ) async {
      await _pumpSavings(tester, ready(saved: 250), size: size);
      await tapVisible(
        tester,
        find.byKey(const Key('savings-goal-goal_scooter')),
      );
      expect(find.text('Выбрать «Самокат»?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();

      await _pumpSavings(
        tester,
        ready(
          activeGoalId: 'goal_night_light',
          saved: 250,
          period: testPeriod(actual: 0),
        ),
        size: size,
      );
      await tapVisible(tester, find.byKey(const Key('savings-change-goal')));
      expect(find.text('Сменить цель'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();

      await _pumpSavings(
        tester,
        ready(activeGoalId: 'goal_night_light', saved: 590),
        size: size,
      );
      await tapVisible(tester, find.byKey(const Key('savings-claim')));
      expect(find.text('Получить «Ночник»?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();

      await _pumpSavings(
        tester,
        ready(
          activeGoalId: 'goal_night_light',
          saved: 250,
          period: testPeriod(actual: 0),
        ),
        size: size,
      );
      await tapVisible(tester, find.byKey(const Key('savings-skip')));
      expect(find.text('Сегодня ничего не откладывать?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no goal shows canonical choices and confirms a reached goal', (
    tester,
  ) async {
    final controller = await _pumpSavings(
      tester,
      ready(saved: 590, wallet: 405),
    );
    expect(find.text('Выбери цель накоплений'), findsOneWidget);
    for (final goal in goals) {
      expect(find.byKey(Key('savings-goal-${goal.id}')), findsOneWidget);
    }
    expect(find.text('Накоплено достаточно'), findsOneWidget);
    expect(find.text('Осталось 10'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const Key('savings-goal-goal_night_light')),
    );
    expect(find.text('Выбрать «Ночник»?'), findsOneWidget);
    expect(
      find.text('После выбора цель сразу будет достигнута.'),
      findsOneWidget,
    );
    expect(controller.selectedGoalId, isNull);
    await tester.tap(find.text('Выбрать цель').last);
    await tester.pumpAndSettle();
    expect(controller.selectedGoalId, 'goal_night_light');
    expect(find.text('Цель достигнута!'), findsOneWidget);
    expect(find.byKey(const Key('savings-claim')), findsOneWidget);
    expect(controller.claims, 0);
  });

  testWidgets('completed goal is disabled in no-goal selection', (
    tester,
  ) async {
    final controller = await _pumpSavings(
      tester,
      ready(saved: 590, completed: completedGoals(1)),
    );
    expect(find.text('Получено'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const Key('savings-goal-goal_night_light')),
    );
    expect(controller.selectedGoalId, isNull);
    expect(find.text('Выбрать «Ночник»?'), findsNothing);
  });

  testWidgets('claim confirmation keeps remainder and completed identity', (
    tester,
  ) async {
    final controller = await _pumpSavings(
      tester,
      ready(activeGoalId: 'goal_night_light', saved: 590, wallet: 20),
    );
    expect(find.text('590 / 400'), findsOneWidget);
    expect(find.text('После получения останется 190 монет'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('savings-claim')));
    expect(find.text('Получить «Ночник»?'), findsOneWidget);
    expect(controller.claims, 0);
    await tester.tap(find.byKey(const Key('savings-confirm-claim')));
    await tester.pumpAndSettle();
    expect(controller.claims, 1);
    final result = controller.state as SavingsReady;
    expect(result.gameState.savedAmount, 190);
    expect(result.activeGoal, isNull);
    expect(result.completedGoals.single.rewardAssetId, 'reward_night_light');
    expect(result.completedGoals.single.pricePaid, 400);
    expect(find.text('Получено'), findsOneWidget);
  });

  testWidgets('planning, ready to finish, skip and retry preserve states', (
    tester,
  ) async {
    await _pumpSavings(
      tester,
      ready(
        activeGoalId: 'goal_scooter',
        period: testPeriod(status: GamePeriodStatus.planning, actual: 0),
      ),
    );
    expect(
      find.text('Пополнить копилку можно после подтверждения плана дня.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const Key('savings-open-deposit')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );

    final controller = await _pumpSavings(
      tester,
      ready(
        activeGoalId: 'goal_scooter',
        period: testPeriod(status: GamePeriodStatus.active, actual: 0),
      ),
    );
    await tapVisible(tester, find.byKey(const Key('savings-skip')));
    expect(find.text('Сегодня ничего не откладывать?'), findsOneWidget);
    await tester.tap(find.text('Подтвердить'));
    await tester.pumpAndSettle();
    expect(controller.skips, 1);

    await _pumpSavings(
      tester,
      ready(
        activeGoalId: 'goal_scooter',
        period: testPeriod(status: GamePeriodStatus.readyToFinish),
      ),
    );
    expect(
      find.text(
        'День уже готов к завершению, но до его завершения ты ещё можешь пополнить копилку.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const Key('savings-open-deposit')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );

    final pending = PendingSavingsDeposit(
      profileId: 1,
      periodId: 1,
      goalId: 'goal_scooter',
      amount: 10,
      operationId: 'same-id',
    );
    final retryController = await _pumpSavings(
      tester,
      ready(
        activeGoalId: 'goal_scooter',
        period: testPeriod(),
        pending: pending,
        message: 'Не удалось подтвердить операцию. Повтори попытку.',
      ),
    );
    expect(
      find.text('Не удалось подтвердить операцию. Повтори попытку.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('savings-retry')));
    await tester.pumpAndSettle();
    expect(retryController.retries, 1);
    expect(
      (retryController.state as SavingsReady).pendingOperation,
      same(pending),
    );
  });

  testWidgets('change goal excludes current/completed and uses campaign copy', (
    tester,
  ) async {
    final controller = await _pumpSavings(
      tester,
      ready(
        activeGoalId: 'goal_scooter',
        saved: 250,
        completed: completedGoals(1),
        period: testPeriod(actual: 0),
      ),
    );
    await tapVisible(tester, find.byKey(const Key('savings-change-goal')));
    expect(
      find.text(
        'Цель можно поменять только один раз. Накопленные монеты сохранятся.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('savings-change-candidate-goal_scooter')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('savings-change-candidate-goal_night_light')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const Key('savings-change-candidate-goal_play_house')),
    );
    await tester.pumpAndSettle();
    expect(controller.changedGoalId, isNull);
    await tester.tap(find.byKey(const Key('savings-confirm-change-goal')));
    await tester.pumpAndSettle();
    expect(controller.changedGoalId, 'goal_play_house');
    expect((controller.state as SavingsReady).gameState.savedAmount, 250);
    expect(find.byKey(const Key('savings-change-goal')), findsNothing);
  });

  testWidgets('Free Play can change goal repeatedly and hides Today', (
    tester,
  ) async {
    final controller = await _pumpSavings(
      tester,
      ready(activeGoalId: 'goal_night_light', saved: 250, freePlay: true),
    );
    expect(find.text('Сегодня'), findsNothing);
    await tapVisible(tester, find.byKey(const Key('savings-change-goal')));
    expect(
      find.text(
        'Накопленные монеты сохранятся. Цель можно будет поменять снова.',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('savings-change-candidate-goal_scooter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('savings-confirm-change-goal')));
    await tester.pumpAndSettle();
    expect(controller.changedGoalId, 'goal_scooter');
    await tapVisible(tester, find.byKey(const Key('savings-change-goal')));
    expect(
      find.byKey(const Key('savings-change-candidate-goal_night_light')),
      findsOneWidget,
    );
    expect(find.text('Сегодня не откладывать'), findsNothing);
  });

  testWidgets('all completed keeps leftover and campaign continuation only', (
    tester,
  ) async {
    final controller = await _pumpSavings(
      tester,
      ready(
        saved: 25,
        completed: completedGoals(),
        period: testPeriod(actual: 0),
      ),
    );
    expect(find.text('Все финансовые цели достигнуты'), findsOneWidget);
    expect(find.text('В копилке осталось 25 монет'), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const Key('savings-all-goals-continue')),
    );
    expect(controller.continuations, 1);

    await _pumpSavings(
      tester,
      ready(saved: 25, completed: completedGoals(), freePlay: true),
    );
    expect(find.text('Все финансовые цели достигнуты'), findsOneWidget);
    expect(find.byKey(const Key('savings-all-goals-continue')), findsNothing);
    expect(find.text('Сегодня'), findsNothing);
  });
}
