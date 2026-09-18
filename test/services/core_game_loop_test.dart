import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/content_entry.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/models/savings_exception.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/budget_service.dart';
import 'package:finny/services/period_service.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:finny/services/savings_service.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

const needItem = ShopItem(
  id: 'need_food',
  name: 'Еда',
  category: ShopItemCategory.need,
  price: 150,
  persistent: false,
  effectType: 'satiety',
  effectValue: 10,
  unlockType: 'available',
);

const wantItem = ShopItem(
  id: 'want_ball',
  name: 'Мяч',
  category: ShopItemCategory.want,
  price: 120,
  persistent: true,
  effectType: 'mood',
  effectValue: 8,
  unlockType: 'available',
);

const carryExpenseItem = ShopItem(
  id: 'carry_expense',
  name: 'Расход периода',
  category: ShopItemCategory.need,
  price: 220,
  persistent: false,
  effectType: 'none',
  effectValue: 0,
  unlockType: 'available',
);

const tooExpensiveItem = ShopItem(
  id: 'too_expensive',
  name: 'Дорогая покупка',
  category: ShopItemCategory.want,
  price: 200,
  persistent: true,
  effectType: 'mood',
  effectValue: 1,
  unlockType: 'available',
);

const testSavingsGoal = SavingsGoal(
  id: 'goal_test',
  name: 'Тестовая цель',
  price: 600,
  description: 'Описание',
  rewardAssetId: 'reward_test',
);

void main() {
  late AppDatabase database;
  late SqliteProfileRepository profiles;
  late SqliteGameRepository games;
  late PeriodService periods;
  late BudgetService budgets;
  late PurchaseService purchases;
  late SavingsService savings;
  late TaskService tasks;

  setUp(() {
    database = createTestDatabase();
    profiles = SqliteProfileRepository(database);
    games = SqliteGameRepository(database);
    final content = TestContentRepository(
      testPeriodDefinitions(count: 5),
      shopItems: const [needItem, wantItem, carryExpenseItem, tooExpensiveItem],
      goals: const [testSavingsGoal],
    );
    periods = PeriodService(games, content);
    budgets = BudgetService(games);
    purchases = PurchaseService(SqlitePurchasePort(database), content);
    savings = SavingsService(games, content);
    tasks = TaskService(games, SqliteTaskCompletionPort(database), content);
  });

  tearDown(() => database.close());

  Future<Profile> createPlayer({
    ProfileType type = ProfileType.normal,
    int wallet = 0,
    int saved = 0,
  }) async {
    final profile = await profiles.create(
      Profile(
        gameName: type == ProfileType.normal ? 'Игрок' : 'Демо',
        profileType: type,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await games.createInitialState(
      GameState(
        profileId: profile.id!,
        walletBalance: wallet,
        currentPeriod: 0,
        savedAmount: saved,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await savings.selectGoal(
      profileId: profile.id!,
      goalId: testSavingsGoal.id,
    );
    return profile;
  }

  Future<GamePeriod> startActivePeriod(int profileId) async {
    final period = await periods.startNextPeriod(profileId: profileId);
    return budgets.confirmPlan(profileId: profileId, periodId: period!.id!);
  }

  Future<GamePeriod> resolveAll(GamePeriod period) async {
    var current = period;
    for (final checkpoint in period.requiredCheckpoints) {
      current = checkpoint == 'financial_task'
          ? (await tasks.submitAnswer(
              profileId: period.profileId,
              periodId: period.id!,
              taskId: 'task_period_${period.periodNumber}',
              answerId: 'apple',
            ) as TaskAnswerCompleted).period
          : await periods.resolveCheckpoint(
              profileId: period.profileId,
              periodId: period.id!,
              checkpointId: checkpoint,
            );
    }
    return current;
  }

  test('period start is atomic, persisted, and cannot be doubled', () async {
    final profile = await createPlayer();

    final period = await periods.startNextPeriod(profileId: profile.id!);

    expect(period, isNotNull);
    expect(period!.status, GamePeriodStatus.planning);
    expect(period.startWalletBalance, 0);
    expect(period.baseIncome, 500);
    expect(period.startingBudget, 500);
    expect(period.plannedFree, 500);
    expect((await games.getGameState(profile.id!))?.walletBalance, 500);
    final transactions = await games.getTransactions(
      profile.id!,
      periodId: period.id,
    );
    expect(transactions, hasLength(1));
    expect(transactions.single.type, GameTransactionType.periodIncome);

    await expectLater(
      periods.startNextPeriod(profileId: profile.id!),
      throwsStateError,
    );
    expect(await games.getPeriods(profile.id!), hasLength(1));
    expect((await games.getGameState(profile.id!))?.walletBalance, 500);
  });

  test('failed income insert rolls back period creation and wallet', () async {
    final profile = await createPlayer();
    final db = await database.database;
    await db.insert(
      'transactions',
      GameTransaction(
        profileId: profile.id!,
        type: GameTransactionType.otherIncome,
        amount: 1,
        source: 'test_conflict',
        description: 'Предварительный конфликт',
        createdAt: DateTime.utc(2026, 1, 1),
        deduplicationKey: 'period_income_period_1',
      ).toMap(),
    );

    await expectLater(
      periods.startNextPeriod(profileId: profile.id!),
      throwsA(isA<DatabaseException>()),
    );

    expect(await games.getPeriods(profile.id!), isEmpty);
    expect((await games.getGameState(profile.id!))?.walletBalance, 0);
  });

  test('invalid content changes neither wallet nor period state', () async {
    final profile = await createPlayer();
    final invalidDefinitions = [
      const PeriodDefinition(
        id: 'invalid_income',
        number: 1,
        title: 'Invalid',
        baseIncome: -1,
        requiredCheckpoints: ['financial_task'],
      ),
      const PeriodDefinition(
        id: 'duplicate_checkpoint',
        number: 1,
        title: 'Invalid',
        baseIncome: 500,
        requiredCheckpoints: ['financial_task', 'financial_task'],
      ),
    ];

    for (final definition in invalidDefinitions) {
      final service = PeriodService(games, TestContentRepository([definition]));
      await expectLater(
        service.startNextPeriod(profileId: profile.id!),
        throwsFormatException,
      );
      expect(await games.getPeriods(profile.id!), isEmpty);
      expect((await games.getGameState(profile.id!))?.walletBalance, 0);
      expect(await games.getTransactions(profile.id!), isEmpty);
    }
  });

  test(
    'content order is explicit and a started period keeps its snapshot',
    () async {
      final profile = await createPlayer();
      final definitions = [
        const PeriodDefinition(
          id: 'first',
          number: 10,
          title: 'Первый',
          baseIncome: 100,
          requiredCheckpoints: ['decision'],
        ),
        const PeriodDefinition(
          id: 'second',
          number: 30,
          title: 'Второй',
          baseIncome: 200,
          requiredCheckpoints: ['next_decision'],
        ),
      ];
      final customPeriods = PeriodService(
        games,
        TestContentRepository(definitions),
      );

      var period = await customPeriods.startNextPeriod(profileId: profile.id!);
      expect(period?.periodNumber, 10);
      expect(period?.baseIncome, 100);
      definitions[0] = const PeriodDefinition(
        id: 'first',
        number: 10,
        title: 'Изменённый content',
        baseIncome: 900,
        requiredCheckpoints: ['changed'],
      );

      final restored = await games.getPeriodById(profile.id!, period!.id!);
      expect(restored?.baseIncome, 100);
      expect(restored?.requiredCheckpoints, ['decision']);
      period = await budgets.confirmPlan(
        profileId: profile.id!,
        periodId: period.id!,
      );
      period = await customPeriods.resolveCheckpoint(
        profileId: profile.id!,
        periodId: period.id!,
        checkpointId: 'decision',
      );
      await customPeriods.completePeriod(
        profileId: profile.id!,
        periodId: period.id!,
      );

      final next = await customPeriods.startNextPeriod(profileId: profile.id!);
      expect(next?.periodNumber, 30);
      expect(next?.startWalletBalance, 100);
      expect(next?.startingBudget, 300);
    },
  );

  test('budget draft persists, validates, and becomes immutable', () async {
    final profile = await createPlayer();
    final period = await periods.startNextPeriod(profileId: profile.id!);

    final draft = await budgets.saveDraft(
      profileId: profile.id!,
      periodId: period!.id!,
      allocation: const BudgetAllocation(need: 200, want: 100, savings: 100),
    );
    expect(draft.plannedFree, 100);
    expect(
      (await games.getPeriodById(profile.id!, period.id!))?.plannedWant,
      100,
    );
    expect((await games.getGameState(profile.id!))?.walletBalance, 500);

    expect(
      () => budgets.saveDraft(
        profileId: profile.id!,
        periodId: period.id!,
        allocation: const BudgetAllocation(need: -1, want: 0, savings: 0),
      ),
      throwsArgumentError,
    );
    await expectLater(
      budgets.saveDraft(
        profileId: profile.id!,
        periodId: period.id!,
        allocation: const BudgetAllocation(need: 501, want: 0, savings: 0),
      ),
      throwsStateError,
    );

    final confirmed = await budgets.confirmPlan(
      profileId: profile.id!,
      periodId: period.id!,
    );
    expect(confirmed.status, GamePeriodStatus.active);
    expect((await games.getGameState(profile.id!))?.walletBalance, 500);
    await expectLater(
      budgets.saveDraft(
        profileId: profile.id!,
        periodId: period.id!,
        allocation: const BudgetAllocation(need: 0, want: 0, savings: 0),
      ),
      throwsStateError,
    );
    await expectLater(
      budgets.confirmPlan(profileId: profile.id!, periodId: period.id!),
      throwsStateError,
    );
  });

  test('zero budget plan is valid and keeps all money as remainder', () async {
    final profile = await createPlayer();
    final period = await periods.startNextPeriod(profileId: profile.id!);

    final draft = await budgets.saveDraft(
      profileId: profile.id!,
      periodId: period!.id!,
      allocation: const BudgetAllocation(need: 0, want: 0, savings: 0),
    );
    final confirmed = await budgets.confirmPlan(
      profileId: profile.id!,
      periodId: period.id!,
    );

    expect(draft.plannedFree, 500);
    expect(confirmed.plannedFree, 500);
    expect((await games.getGameState(profile.id!))?.walletBalance, 500);
  });

  test('financial actions are rejected while planning', () async {
    final profile = await createPlayer();
    final period = await periods.startNextPeriod(profileId: profile.id!);

    await expectLater(
      purchases.purchase(
        profileId: profile.id!,
        periodId: period!.id!,
        itemId: needItem.id,
        operationId: 'planning-purchase',
      ),
      throwsStateError,
    );
    await expectLater(
      savings.deposit(
        profileId: profile.id!,
        periodId: period.id!,
        amount: 10,
        operationId: 'planning-savings',
      ),
      throwsA(isA<SavingsPeriodNotAvailableException>()),
    );
    await expectLater(
      tasks.submitAnswer(
        profileId: profile.id!,
        periodId: period.id!,
        taskId: 'task_period_1',
        answerId: 'apple',
      ),
      throwsStateError,
    );
    await expectLater(
      periods.addExplicitIncome(
        profileId: profile.id!,
        periodId: period.id!,
        amount: 10,
        operationId: 'planning-income',
        source: 'test',
        description: 'Недопустимый доход',
      ),
      throwsStateError,
    );
    expect((await games.getGameState(profile.id!))?.walletBalance, 500);
    expect((await games.getGameState(profile.id!))?.savedAmount, 0);
    expect(await games.getInventoryQuantity(profile.id!, needItem.id), 0);
    expect(
      await games.getTransactions(profile.id!, periodId: period.id),
      hasLength(1),
    );
  });

  test(
    'purchase accepts only canonical item ID and uses canonical values',
    () async {
      final profile = await createPlayer();
      final period = await startActivePeriod(profile.id!);
      await expectLater(
        purchases.purchase(
          profileId: profile.id!,
          periodId: period.id!,
          itemId: 'unknown_item',
          operationId: 'unknown-item',
        ),
        throwsStateError,
      );
      expect((await games.getGameState(profile.id!))?.walletBalance, 500);
      await purchases.purchase(
        profileId: profile.id!,
        periodId: period.id!,
        itemId: wantItem.id,
        operationId: 'canonical-item',
      );
      expect((await games.getGameState(profile.id!))?.walletBalance, 380);
      expect(await games.getInventoryQuantity(profile.id!, wantItem.id), 1);
      expect(
        await games.getTransactions(profile.id!, periodId: period.id),
        hasLength(2),
      );
    },
  );

  test(
    'period-bound operations reject a period owned by another profile',
    () async {
      final profileA = await createPlayer();
      final profileB = await createPlayer(type: ProfileType.demo);
      final periodB = await startActivePeriod(profileB.id!);

      await expectLater(
        purchases.purchase(
          profileId: profileA.id!,
          periodId: periodB.id!,
          itemId: needItem.id,
          operationId: 'foreign-purchase',
        ),
        throwsStateError,
      );
      await expectLater(
        tasks.submitAnswer(
          profileId: profileA.id!,
          periodId: periodB.id!,
          taskId: 'task_period_1',
          answerId: 'apple',
        ),
        throwsStateError,
      );
      await expectLater(
        savings.deposit(
          profileId: profileA.id!,
          periodId: periodB.id!,
          amount: 10,
          operationId: 'foreign-savings',
        ),
        throwsStateError,
      );
      await expectLater(
        periods.resolveCheckpoint(
          profileId: profileA.id!,
          periodId: periodB.id!,
          checkpointId: 'financial_task',
        ),
        throwsStateError,
      );
      await expectLater(
        periods.addExplicitIncome(
          profileId: profileA.id!,
          periodId: periodB.id!,
          amount: 10,
          operationId: 'foreign-income',
          source: 'test',
          description: 'Чужой период',
        ),
        throwsStateError,
      );

      expect((await games.getGameState(profileA.id!))?.walletBalance, 0);
      expect((await games.getGameState(profileB.id!))?.walletBalance, 500);
      expect(await games.getTransactions(profileA.id!), isEmpty);
      expect(
        await games.getTransactions(profileB.id!, periodId: periodB.id),
        hasLength(1),
      );
      expect(
        (await games.getPeriodById(
          profileB.id!,
          periodB.id!,
        ))?.resolvedCheckpoints,
        isEmpty,
      );
    },
  );

  test(
    'Plan/Fact uses persisted transactions and idempotent commands',
    () async {
      final profile = await createPlayer();
      final started = await periods.startNextPeriod(profileId: profile.id!);
      await budgets.saveDraft(
        profileId: profile.id!,
        periodId: started!.id!,
        allocation: const BudgetAllocation(need: 200, want: 100, savings: 100),
      );
      final period = await budgets.confirmPlan(
        profileId: profile.id!,
        periodId: started.id!,
      );

      await tasks.submitAnswer(
        profileId: profile.id!,
        periodId: period.id!,
        taskId: 'task_period_1',
        answerId: 'apple',
      );
      await purchases.purchase(
        profileId: profile.id!,
        periodId: period.id!,
        itemId: needItem.id,
        operationId: 'need-1',
      );
      await purchases.purchase(
        profileId: profile.id!,
        periodId: period.id!,
        itemId: wantItem.id,
        operationId: 'want-1',
      );
      await savings.deposit(
        profileId: profile.id!,
        periodId: period.id!,
        amount: 100,
        operationId: 'savings-1',
      );
      await expectLater(
        savings.deposit(
          profileId: profile.id!,
          periodId: period.id!,
          amount: 90,
          operationId: 'savings-1',
        ),
        throwsA(isA<SavingsOperationConflictException>()),
      );

      await purchases.purchase(
        profileId: profile.id!,
        periodId: period.id!,
        itemId: needItem.id,
        operationId: 'need-1',
      );
      await savings.deposit(
        profileId: profile.id!,
        periodId: period.id!,
        amount: 100,
        operationId: 'savings-1',
      );
      await expectLater(
        purchases.purchase(
          profileId: profile.id!,
          periodId: period.id!,
          itemId: wantItem.id,
          operationId: 'need-1',
        ),
        throwsStateError,
      );
      expect(
        await tasks.submitAnswer(
          profileId: profile.id!,
          periodId: period.id!,
          taskId: 'task_period_1',
          answerId: 'apple',
        ),
        isA<TaskAnswerCompleted>().having(
          (result) => result.wasAlreadyCompleted,
          'wasAlreadyCompleted',
          isTrue,
        ),
      );

      final summary = await periods.getSummary(
        profileId: profile.id!,
        periodId: period.id!,
      );
      expect(summary.startingBudget, 500);
      expect(summary.additionalIncome, 50);
      expect(summary.factNeed, 150);
      expect(summary.factWant, 120);
      expect(summary.factSavings, 100);
      expect(summary.factRemainder, 180);
      expect(summary.totalExpenses, 270);
      expect(summary.needDeviation, -50);
      expect(summary.wantDeviation, 20);
      expect(summary.savingsDeviation, 0);
      final aggregated = await games.getPeriodById(profile.id!, period.id!);
      expect(aggregated?.actualNeed, 150);
      expect(aggregated?.actualWant, 120);
      expect(aggregated?.actualSavings, 100);
      expect(aggregated?.extraIncome, 50);
      expect(await games.getInventoryQuantity(profile.id!, needItem.id), 1);
      expect(await games.getInventoryQuantity(profile.id!, wantItem.id), 1);
      expect(
        await games.getTransactions(profile.id!, periodId: period.id),
        hasLength(5),
      );

      await expectLater(
        purchases.purchase(
          profileId: profile.id!,
          periodId: period.id!,
          itemId: tooExpensiveItem.id,
          operationId: 'insufficient',
        ),
        throwsStateError,
      );
      expect((await games.getGameState(profile.id!))?.walletBalance, 180);
      expect(
        await games.getInventoryQuantity(profile.id!, tooExpensiveItem.id),
        0,
      );

      await expectLater(
        savings.deposit(
          profileId: profile.id!,
          periodId: period.id!,
          amount: 181,
          operationId: 'insufficient-savings',
        ),
        throwsA(isA<SavingsInsufficientWalletFundsException>()),
      );
      expect(
        () => savings.deposit(
          profileId: profile.id!,
          periodId: period.id!,
          amount: 0,
          operationId: 'zero-savings',
        ),
        throwsArgumentError,
      );
      expect((await games.getGameState(profile.id!))?.walletBalance, 180);
    },
  );

  test(
    'explicit income operationId survives replay and rejects conflicts',
    () async {
      final profile = await createPlayer();
      final period = await startActivePeriod(profile.id!);

      for (var attempt = 0; attempt < 2; attempt++) {
        await periods.addExplicitIncome(
          profileId: profile.id!,
          periodId: period.id!,
          amount: 25,
          operationId: 'income-1',
          source: 'allowance_adjustment',
          description: 'Явный дополнительный доход',
        );
      }
      await expectLater(
        periods.addExplicitIncome(
          profileId: profile.id!,
          periodId: period.id!,
          amount: 30,
          operationId: 'income-1',
          source: 'allowance_adjustment',
          description: 'Явный дополнительный доход',
        ),
        throwsStateError,
      );

      expect((await games.getGameState(profile.id!))?.walletBalance, 525);
      final summary = await periods.getSummary(
        profileId: profile.id!,
        periodId: period.id!,
      );
      expect(summary.additionalIncome, 25);
      expect(summary.startingBudget, 500);
    },
  );

  test(
    'checkpoints drive ready state and completed period is immutable',
    () async {
      final profile = await createPlayer();
      var period = await startActivePeriod(profile.id!);

      await expectLater(
        periods.completePeriod(profileId: profile.id!, periodId: period.id!),
        throwsStateError,
      );

      period = (await tasks.submitAnswer(
        profileId: profile.id!,
        periodId: period.id!,
        taskId: 'task_period_1',
        answerId: 'apple',
      ) as TaskAnswerCompleted).period;
      expect(period.status, GamePeriodStatus.active);
      period = await periods.resolveCheckpoint(
        profileId: profile.id!,
        periodId: period.id!,
        checkpointId: 'mandatory_need',
      );
      period = await periods.resolveCheckpoint(
        profileId: profile.id!,
        periodId: period.id!,
        checkpointId: 'savings_decision',
      );
      expect(period.status, GamePeriodStatus.readyToFinish);
      expect((await games.getGameState(profile.id!))?.savedAmount, 0);

      final repeated = await periods.resolveCheckpoint(
        profileId: profile.id!,
        periodId: period.id!,
        checkpointId: 'savings_decision',
      );
      expect(repeated.resolvedCheckpoints, period.resolvedCheckpoints);
      await expectLater(
        periods.resolveCheckpoint(
          profileId: profile.id!,
          periodId: period.id!,
          checkpointId: 'optional_purchase',
        ),
        throwsStateError,
      );

      await purchases.purchase(
        profileId: profile.id!,
        periodId: period.id!,
        itemId: needItem.id,
        operationId: 'ready-purchase',
      );
      await savings.deposit(
        profileId: profile.id!,
        periodId: period.id!,
        amount: 10,
        operationId: 'ready-savings',
      );
      await periods.addExplicitIncome(
        profileId: profile.id!,
        periodId: period.id!,
        amount: 15,
        operationId: 'ready-income',
        source: 'test_income',
        description: 'Доход в readyToFinish',
      );
      final taskReplay = await tasks.submitAnswer(
        profileId: profile.id!,
        periodId: period.id!,
        taskId: 'task_period_1',
        answerId: 'apple',
      );
      expect((taskReplay as TaskAnswerCompleted).wasAlreadyCompleted, isTrue);
      final beforeCompletion = await periods.getSummary(
        profileId: profile.id!,
        periodId: period.id!,
      );
      expect(beforeCompletion.factNeed, 150);
      expect(beforeCompletion.factSavings, 10);
      expect(beforeCompletion.additionalIncome, 65);
      expect(beforeCompletion.factRemainder, 405);

      final completed = await periods.completePeriod(
        profileId: profile.id!,
        periodId: period.id!,
      );
      expect(completed.status, GamePeriodStatus.completed);
      expect(completed.endWalletBalance, 405);
      final stateAtCompletion = await games.getGameState(profile.id!);
      final transactionCountAtCompletion = (await games.getTransactions(
        profile.id!,
        periodId: period.id,
      )).length;

      await expectLater(
        purchases.purchase(
          profileId: profile.id!,
          periodId: period.id!,
          itemId: wantItem.id,
          operationId: 'after-completed',
        ),
        throwsStateError,
      );
      await expectLater(
        savings.deposit(
          profileId: profile.id!,
          periodId: period.id!,
          amount: 10,
          operationId: 'after-completed-savings',
        ),
        throwsA(isA<SavingsPeriodNotAvailableException>()),
      );
      await expectLater(
        periods.addExplicitIncome(
          profileId: profile.id!,
          periodId: period.id!,
          amount: 10,
          operationId: 'after-completed-income',
          source: 'test',
          description: 'Недопустимый доход',
        ),
        throwsStateError,
      );
      expect(
        (await tasks.submitAnswer(
          profileId: profile.id!,
          periodId: period.id!,
          taskId: 'task_period_1',
          answerId: 'apple',
        ) as TaskAnswerCompleted).wasAlreadyCompleted,
        isTrue,
      );
      await expectLater(
        periods.resolveCheckpoint(
          profileId: profile.id!,
          periodId: period.id!,
          checkpointId: 'financial_task',
        ),
        throwsStateError,
      );
      await expectLater(
        periods.completePeriod(profileId: profile.id!, periodId: period.id!),
        throwsStateError,
      );

      final afterCompletion = await periods.getSummary(
        profileId: profile.id!,
        periodId: period.id!,
      );
      expect(afterCompletion.factRemainder, beforeCompletion.factRemainder);
      expect(afterCompletion.factNeed, beforeCompletion.factNeed);
      expect(afterCompletion.factSavings, beforeCompletion.factSavings);
      expect(
        afterCompletion.additionalIncome,
        beforeCompletion.additionalIncome,
      );
      expect(
        (await games.getGameState(profile.id!))?.toMap(),
        stateAtCompletion?.toMap(),
      );
      expect(await games.getInventoryQuantity(profile.id!, wantItem.id), 0);
      expect(
        await games.getTransactions(profile.id!, periodId: period.id),
        hasLength(transactionCountAtCompletion),
      );

      final next = await periods.startNextPeriod(profileId: profile.id!);
      final activeNext = await budgets.confirmPlan(
        profileId: profile.id!,
        periodId: next!.id!,
      );
      await purchases.purchase(
        profileId: profile.id!,
        periodId: activeNext.id!,
        itemId: wantItem.id,
        operationId: 'next-period-purchase',
      );
      expect((await games.getGameState(profile.id!))?.walletBalance, 785);

      final historicalSummary = await periods.getSummary(
        profileId: profile.id!,
        periodId: period.id!,
      );
      expect(historicalSummary.factRemainder, 405);
      expect(historicalSummary.factNeed, beforeCompletion.factNeed);
      expect(historicalSummary.factWant, beforeCompletion.factWant);
      expect(historicalSummary.factSavings, beforeCompletion.factSavings);
      expect(
        historicalSummary.additionalIncome,
        beforeCompletion.additionalIncome,
      );
    },
  );

  test(
    'wallet and savings carry over while checkpoints stay isolated',
    () async {
      final profile = await createPlayer();
      var period = await startActivePeriod(profile.id!);
      await purchases.purchase(
        profileId: profile.id!,
        periodId: period.id!,
        itemId: carryExpenseItem.id,
        operationId: 'carry-expense',
      );
      await savings.deposit(
        profileId: profile.id!,
        periodId: period.id!,
        amount: 100,
        operationId: 'carry-savings',
      );
      period = await resolveAll(period);
      await periods.completePeriod(
        profileId: profile.id!,
        periodId: period.id!,
      );

      var next = await periods.startNextPeriod(profileId: profile.id!);
      expect(next!.periodNumber, 2);
      expect(next.startWalletBalance, 230);
      expect(next.startingBudget, 730);
      expect(next.resolvedCheckpoints, isEmpty);
      expect((await games.getGameState(profile.id!))?.savedAmount, 100);
      final secondSummary = await periods.getSummary(
        profileId: profile.id!,
        periodId: next.id!,
      );
      expect(secondSummary.additionalIncome, 0);
      expect(secondSummary.factNeed, 0);
      expect(secondSummary.factWant, 0);
      expect(secondSummary.factSavings, 0);
      expect(secondSummary.totalExpenses, 0);

      for (var number = 2; number <= 5; number++) {
        next = await budgets.confirmPlan(
          profileId: profile.id!,
          periodId: next!.id!,
        );
        next = await resolveAll(next);
        await periods.completePeriod(
          profileId: profile.id!,
          periodId: next.id!,
        );
        if (number < 5) {
          next = await periods.startNextPeriod(profileId: profile.id!);
        }
      }

      expect(await periods.startNextPeriod(profileId: profile.id!), isNull);
      expect(await games.getPeriods(profile.id!), hasLength(5));
      expect((await games.getGameState(profile.id!))?.savedAmount, 100);
    },
  );

  test('NORMAL and DEMO Core state stay isolated', () async {
    final normal = await createPlayer();
    final demo = await createPlayer(
      type: ProfileType.demo,
      wallet: 100,
      saved: 10,
    );

    final normalPeriod = await startActivePeriod(normal.id!);
    await purchases.purchase(
      profileId: normal.id!,
      periodId: normalPeriod.id!,
      itemId: needItem.id,
      operationId: 'normal-purchase',
    );
    await savings.deposit(
      profileId: normal.id!,
      periodId: normalPeriod.id!,
      amount: 50,
      operationId: 'normal-savings',
    );
    await tasks.submitAnswer(
      profileId: normal.id!,
      periodId: normalPeriod.id!,
      taskId: 'task_period_1',
      answerId: 'apple',
    );

    expect((await games.getGameState(demo.id!))?.walletBalance, 100);
    expect((await games.getGameState(demo.id!))?.savedAmount, 10);
    expect(await games.getPeriods(demo.id!), isEmpty);
    expect(await games.getTransactions(demo.id!), isEmpty);

    final demoPeriod = await periods.startNextPeriod(profileId: demo.id!);
    expect(demoPeriod?.startWalletBalance, 100);
    expect((await games.getGameState(normal.id!))?.walletBalance, 350);
    expect((await games.getGameState(normal.id!))?.savedAmount, 50);
    expect(
      (await games.getPeriodById(
        normal.id!,
        normalPeriod.id!,
      ))?.resolvedCheckpoints,
      ['financial_task', 'savings_decision'],
    );
  });

  test(
    'unfinished Core state and operation IDs survive SQLite reopen',
    () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp('finny_core_');
      final path = '${directory.path}/finny.sqlite';
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      sqfliteFfiInit();
      final firstDatabase = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final firstProfiles = SqliteProfileRepository(firstDatabase);
      final firstGames = SqliteGameRepository(firstDatabase);
      final persistentContent = TestContentRepository(
        testPeriodDefinitions(),
        shopItems: const [needItem, wantItem],
        goals: const [testSavingsGoal],
      );
      final firstPeriods = PeriodService(firstGames, persistentContent);
      final firstBudgets = BudgetService(firstGames);
      final firstPurchases = PurchaseService(
        SqlitePurchasePort(firstDatabase),
        persistentContent,
      );
      final firstSavings = SavingsService(firstGames, persistentContent);
      final profile = await firstProfiles.create(
        Profile(
          gameName: 'Persistent',
          profileType: ProfileType.normal,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await firstGames.createInitialState(
        GameState(
          profileId: profile.id!,
          walletBalance: 0,
          currentPeriod: 0,
          savedAmount: 0,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final started = await firstPeriods.startNextPeriod(
        profileId: profile.id!,
      );
      await firstBudgets.saveDraft(
        profileId: profile.id!,
        periodId: started!.id!,
        allocation: const BudgetAllocation(need: 200, want: 100, savings: 50),
      );
      await firstBudgets.confirmPlan(
        profileId: profile.id!,
        periodId: started.id!,
      );
      await firstPeriods.addExplicitIncome(
        profileId: profile.id!,
        periodId: started.id!,
        amount: 25,
        operationId: 'persistent-income',
        source: 'test_income',
        description: 'Сохраняемый доход',
      );
      await firstPurchases.purchase(
        profileId: profile.id!,
        periodId: started.id!,
        itemId: needItem.id,
        operationId: 'persistent-purchase',
      );
      await firstSavings.selectGoal(
        profileId: profile.id!,
        goalId: testSavingsGoal.id,
      );
      await firstSavings.deposit(
        profileId: profile.id!,
        periodId: started.id!,
        amount: 50,
        operationId: 'persistent-savings',
      );
      await TaskService(
        firstGames,
        SqliteTaskCompletionPort(firstDatabase),
        persistentContent,
      ).submitAnswer(
        profileId: profile.id!,
        periodId: started.id!,
        taskId: 'task_period_1',
        answerId: 'apple',
      );
      await firstDatabase.close();

      final reopenedDatabase = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final reopenedGames = SqliteGameRepository(reopenedDatabase);
      final reopenedContent = TestContentRepository(
        testPeriodDefinitions(),
        shopItems: const [needItem, wantItem],
        goals: const [testSavingsGoal],
      );
      final reopenedPeriods = PeriodService(reopenedGames, reopenedContent);
      final reopenedPurchases = PurchaseService(
        SqlitePurchasePort(reopenedDatabase),
        reopenedContent,
      );
      final reopenedSavings = SavingsService(reopenedGames, reopenedContent);
      addTearDown(reopenedDatabase.close);

      final restored = await reopenedGames.getCurrentPeriod(profile.id!);
      expect(restored?.status, GamePeriodStatus.active);
      expect(restored?.plannedNeed, 200);
      expect(restored?.plannedWant, 100);
      expect(restored?.plannedSavings, 50);
      expect(restored?.resolvedCheckpoints, [
        'financial_task',
        'savings_decision',
      ]);
      expect(
        (await reopenedGames.getGameState(profile.id!))?.walletBalance,
        375,
      );
      expect((await reopenedGames.getGameState(profile.id!))?.savedAmount, 50);
      expect(
        await reopenedGames.getInventoryQuantity(profile.id!, needItem.id),
        1,
      );

      await reopenedPeriods.addExplicitIncome(
        profileId: profile.id!,
        periodId: started.id!,
        amount: 25,
        operationId: 'persistent-income',
        source: 'test_income',
        description: 'Сохраняемый доход',
      );
      await reopenedPurchases.purchase(
        profileId: profile.id!,
        periodId: started.id!,
        itemId: needItem.id,
        operationId: 'persistent-purchase',
      );
      await reopenedSavings.deposit(
        profileId: profile.id!,
        periodId: started.id!,
        amount: 50,
        operationId: 'persistent-savings',
      );
      expect(
        (await reopenedGames.getGameState(profile.id!))?.walletBalance,
        375,
      );
      expect((await reopenedGames.getGameState(profile.id!))?.savedAmount, 50);
      expect(
        await reopenedGames.getInventoryQuantity(profile.id!, needItem.id),
        1,
      );
      expect(
        await reopenedGames.getTransactions(profile.id!, periodId: started.id!),
        hasLength(5),
      );

      await expectLater(
        reopenedPeriods.addExplicitIncome(
          profileId: profile.id!,
          periodId: started.id!,
          amount: 30,
          operationId: 'persistent-income',
          source: 'test_income',
          description: 'Сохраняемый доход',
        ),
        throwsStateError,
      );
      await expectLater(
        reopenedPurchases.purchase(
          profileId: profile.id!,
          periodId: started.id!,
          itemId: wantItem.id,
          operationId: 'persistent-purchase',
        ),
        throwsStateError,
      );
      await expectLater(
        reopenedSavings.deposit(
          profileId: profile.id!,
          periodId: started.id!,
          amount: 60,
          operationId: 'persistent-savings',
        ),
        throwsA(isA<SavingsOperationConflictException>()),
      );
      expect(
        (await reopenedGames.getGameState(profile.id!))?.walletBalance,
        375,
      );
      expect((await reopenedGames.getGameState(profile.id!))?.savedAmount, 50);
      expect(
        await reopenedGames.getInventoryQuantity(profile.id!, needItem.id),
        1,
      );
      expect(
        await reopenedGames.getTransactions(profile.id!, periodId: started.id!),
        hasLength(5),
      );
    },
  );
}
