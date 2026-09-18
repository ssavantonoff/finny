import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/savings_exception.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/budget_service.dart';
import 'package:finny/services/period_service.dart';
import 'package:finny/services/savings_service.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_content_repository.dart';
import '../../helpers/test_database.dart';

const goals = [
  SavingsGoal(
    id: 'goal_night_light',
    name: 'Ночник',
    price: 400,
    description: 'Описание',
    rewardAssetId: 'reward_night_light',
  ),
  SavingsGoal(
    id: 'goal_scooter',
    name: 'Самокат',
    price: 600,
    description: 'Описание',
    rewardAssetId: 'reward_scooter',
  ),
  SavingsGoal(
    id: 'goal_play_house',
    name: 'Домик',
    price: 900,
    description: 'Описание',
    rewardAssetId: 'reward_play_house',
  ),
];

class _TrackingGameRepository extends SqliteGameRepository {
  _TrackingGameRepository(super.database);

  int skipCalls = 0;

  @override
  Future<GamePeriod> skipSavingsDecision({
    required int profileId,
    required int periodId,
  }) {
    skipCalls++;
    return super.skipSavingsDecision(profileId: profileId, periodId: periodId);
  }
}

void main() {
  late AppDatabase database;
  late SqliteProfileRepository profiles;
  late SqliteGameRepository games;
  late SavingsService savings;
  late PeriodService periods;
  late BudgetService budgets;
  late TestContentRepository content;

  setUp(() {
    database = createTestDatabase();
    profiles = SqliteProfileRepository(database);
    games = SqliteGameRepository(database);
    content = TestContentRepository(
      testPeriodDefinitions(count: 2),
      goals: goals,
    );
    savings = SavingsService(games, content);
    periods = PeriodService(games, content);
    budgets = BudgetService(games);
  });

  tearDown(() => database.close());

  Future<int> createPlayer({
    int wallet = 500,
    int saved = 0,
    String? activeGoalId,
    bool goalChangeUsed = false,
    ProfileType profileType = ProfileType.normal,
  }) async {
    final profile = await profiles.create(
      Profile(
        gameName: 'Игрок',
        profileType: profileType,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await games.createInitialState(
      GameState(
        profileId: profile.id!,
        walletBalance: wallet,
        currentPeriod: 0,
        activeGoalId: activeGoalId,
        savedAmount: saved,
        goalChangeUsed: goalChangeUsed,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    return profile.id!;
  }

  Future<GamePeriod> startActive(int profileId) async {
    final started = await periods.startNextPeriod(profileId: profileId);
    return budgets.confirmPlan(profileId: profileId, periodId: started!.id!);
  }

  test(
    'selection and one change preserve savings and derive reached',
    () async {
      final profileId = await createPlayer(saved: 700);

      final selected = await savings.selectGoal(
        profileId: profileId,
        goalId: 'goal_play_house',
      );
      expect(selected.savedAmount, 700);
      expect(selected.goalChangeUsed, isFalse);
      expect(
        (await savings.selectGoal(
          profileId: profileId,
          goalId: 'goal_play_house',
        )).activeGoalId,
        'goal_play_house',
      );

      final changed = await savings.changeGoal(
        profileId: profileId,
        goalId: 'goal_night_light',
      );
      expect(changed.savedAmount, 700);
      expect(changed.goalChangeUsed, isTrue);
      expect(changed.activeGoalId, 'goal_night_light');
      expect(
        (await savings.changeGoal(
          profileId: profileId,
          goalId: 'goal_night_light',
        )).activeGoalId,
        'goal_night_light',
      );
      await expectLater(
        savings.changeGoal(profileId: profileId, goalId: 'goal_scooter'),
        throwsA(isA<SavingsGoalChangeAlreadyUsedException>()),
      );
    },
  );

  test(
    'deposit is atomic, capped, idempotent and updates period fact',
    () async {
      final profileId = await createPlayer(saved: 100);
      await savings.selectGoal(profileId: profileId, goalId: 'goal_scooter');
      var period = await startActive(profileId);

      final first = await savings.deposit(
        profileId: profileId,
        periodId: period.id!,
        amount: 150,
        operationId: 'dep-1',
      );
      expect(first.walletBalance, 850);
      expect(first.savedAmount, 250);
      period = (await games.getPeriodById(profileId, period.id!))!;
      expect(period.actualSavings, 150);
      expect(period.resolvedCheckpoints, contains('savings_decision'));

      final replay = await savings.deposit(
        profileId: profileId,
        periodId: period.id!,
        amount: 150,
        operationId: 'dep-1',
      );
      expect(replay.walletBalance, 850);
      expect(
        (await games.getPeriodById(profileId, period.id!))!.actualSavings,
        150,
      );
      expect(
        await games.getTransactions(profileId, periodId: period.id),
        hasLength(2),
      );

      await expectLater(
        savings.deposit(
          profileId: profileId,
          periodId: period.id!,
          amount: 151,
          operationId: 'dep-1',
        ),
        throwsA(isA<SavingsOperationConflictException>()),
      );
      await expectLater(
        savings.deposit(
          profileId: profileId,
          periodId: period.id!,
          amount: 351,
          operationId: 'dep-too-much',
        ),
        throwsA(isA<SavingsDepositExceedsGoalException>()),
      );
      expect((await games.getGameState(profileId))!.walletBalance, 850);
      expect((await games.getGameState(profileId))!.savedAmount, 250);
    },
  );

  test('deposit cannot exceed the missing amount', () async {
    final profileId = await createPlayer(saved: 550);
    await savings.selectGoal(profileId: profileId, goalId: 'goal_scooter');
    final period = await startActive(profileId);
    await expectLater(
      savings.deposit(
        profileId: profileId,
        periodId: period.id!,
        amount: 51,
        operationId: 'over-goal',
      ),
      throwsA(
        isA<SavingsDepositExceedsGoalException>()
            .having((error) => error.requestedAmount, 'requestedAmount', 51)
            .having((error) => error.remainingAmount, 'remainingAmount', 50),
      ),
    );
    expect((await games.getGameState(profileId))!.savedAmount, 550);
    expect(
      (await games.getPeriodById(profileId, period.id!))!.actualSavings,
      0,
    );
  });

  test(
    'multiple deposits aggregate once and reached goal blocks new money',
    () async {
      final profileId = await createPlayer(saved: 480);
      await savings.selectGoal(profileId: profileId, goalId: 'goal_scooter');
      final period = await startActive(profileId);
      for (final entry in const [
        (40, 'multi-1'),
        (30, 'multi-2'),
        (50, 'multi-3'),
      ]) {
        await savings.deposit(
          profileId: profileId,
          periodId: period.id!,
          amount: entry.$1,
          operationId: entry.$2,
        );
      }
      final state = (await games.getGameState(profileId))!;
      final updated = (await games.getPeriodById(profileId, period.id!))!;
      expect(state.savedAmount, 600);
      expect(updated.actualSavings, 120);
      expect(
        await games.getTransactions(profileId, periodId: period.id),
        hasLength(4),
      );
      await expectLater(
        savings.deposit(
          profileId: profileId,
          periodId: period.id!,
          amount: 1,
          operationId: 'after-reached',
        ),
        throwsA(isA<SavingsGoalReachedException>()),
      );
    },
  );

  test(
    'skip can be followed by a deposit and ready status stays ready',
    () async {
      final profileId = await createPlayer();
      await savings.selectGoal(profileId: profileId, goalId: 'goal_scooter');
      var period = await startActive(profileId);
      await TaskService(games, content).submitAnswer(
        profileId: profileId,
        periodId: period.id!,
        taskId: 'task_period_1',
        answerId: 'need_lunch',
      );
      period = await periods.resolveCheckpoint(
        profileId: profileId,
        periodId: period.id!,
        checkpointId: 'mandatory_need',
      );
      period = await savings.skipToday(
        profileId: profileId,
        periodId: period.id!,
      );
      expect(period.status, GamePeriodStatus.readyToFinish);
      expect(period.actualSavings, 0);
      expect(
        await games.getTransactions(profileId, periodId: period.id),
        hasLength(2),
      );

      await savings.deposit(
        profileId: profileId,
        periodId: period.id!,
        amount: 50,
        operationId: 'after-skip',
      );
      final updated = (await games.getPeriodById(profileId, period.id!))!;
      expect(updated.status, GamePeriodStatus.readyToFinish);
      expect(updated.actualSavings, 50);
      expect(
        updated.resolvedCheckpoints.where((id) => id == 'savings_decision'),
        hasLength(1),
      );
      await expectLater(
        savings.skipToday(profileId: profileId, periodId: period.id!),
        throwsA(isA<SavingsDecisionAlreadyMadeException>()),
      );
    },
  );

  test('skip rejects an active goal missing from canonical content', () async {
    final profileId = await createPlayer(
      wallet: 275,
      saved: 125,
      activeGoalId: 'unknown_or_deleted_goal',
    );
    final period = await startActive(profileId);
    final stateBefore = (await games.getGameState(profileId))!;
    final periodBefore = (await games.getPeriodById(profileId, period.id!))!;
    final transactionsBefore = await games.getTransactions(
      profileId,
      periodId: period.id,
    );
    final trackingGames = _TrackingGameRepository(database);
    final boundary = SavingsService(trackingGames, content);

    await expectLater(
      boundary.skipToday(profileId: profileId, periodId: period.id!),
      throwsA(
        isA<SavingsGoalNotFoundException>().having(
          (error) => error.goalId,
          'goalId',
          'unknown_or_deleted_goal',
        ),
      ),
    );

    expect(trackingGames.skipCalls, 0);
    final stateAfter = (await games.getGameState(profileId))!;
    final periodAfter = (await games.getPeriodById(profileId, period.id!))!;
    expect(periodAfter.resolvedCheckpoints, periodBefore.resolvedCheckpoints);
    expect(periodAfter.status, periodBefore.status);
    expect(stateAfter.walletBalance, stateBefore.walletBalance);
    expect(stateAfter.savedAmount, stateBefore.savedAmount);
    expect(periodAfter.actualSavings, periodBefore.actualSavings);
    expect(
      await games.getTransactions(profileId, periodId: period.id),
      hasLength(transactionsBefore.length),
    );
  });

  test(
    'claim preserves excess, gives one reward and has durable replay',
    () async {
      final profileId = await createPlayer(
        wallet: 25,
        saved: 700,
        activeGoalId: 'goal_night_light',
        goalChangeUsed: true,
      );

      final claimed = await savings.claimGoal(
        profileId: profileId,
        goalId: 'goal_night_light',
        operationId: 'claim-1',
      );
      expect(claimed.walletBalance, 25);
      expect(claimed.savedAmount, 300);
      expect(claimed.activeGoalId, isNull);
      expect(claimed.goalChangeUsed, isFalse);
      expect(
        await games.getInventoryQuantity(profileId, 'reward_night_light'),
        1,
      );
      expect(await games.getTransactions(profileId), isEmpty);
      expect(await games.getCompletedGoals(profileId), hasLength(1));

      await savings.selectGoal(profileId: profileId, goalId: 'goal_scooter');
      final replay = await savings.claimGoal(
        profileId: profileId,
        goalId: 'goal_night_light',
        operationId: 'claim-1',
      );
      expect(replay.savedAmount, 300);
      expect(replay.activeGoalId, 'goal_scooter');
      expect(
        await games.getInventoryQuantity(profileId, 'reward_night_light'),
        1,
      );
      await expectLater(
        savings.claimGoal(
          profileId: profileId,
          goalId: 'goal_scooter',
          operationId: 'claim-1',
        ),
        throwsA(isA<SavingsOperationConflictException>()),
      );
      await expectLater(
        savings.selectGoal(profileId: profileId, goalId: 'goal_night_light'),
        throwsA(isA<SavingsGoalAlreadyCompletedException>()),
      );
    },
  );

  test(
    'deposit replay stays exact after claim and a new active goal',
    () async {
      final profileId = await createPlayer(activeGoalId: 'goal_night_light');
      final period = await startActive(profileId);
      await savings.deposit(
        profileId: profileId,
        periodId: period.id!,
        amount: 400,
        operationId: 'deposit-before-claim',
      );
      await savings.claimGoal(
        profileId: profileId,
        goalId: 'goal_night_light',
        operationId: 'claim-after-deposit',
      );
      await savings.selectGoal(profileId: profileId, goalId: 'goal_scooter');

      final replay = await savings.deposit(
        profileId: profileId,
        periodId: period.id!,
        amount: 400,
        operationId: 'deposit-before-claim',
      );
      expect(replay.activeGoalId, 'goal_scooter');
      expect(replay.savedAmount, 0);
      expect(
        (await games.getPeriodById(profileId, period.id!))!.actualSavings,
        400,
      );
      expect(
        await games.getTransactions(profileId, periodId: period.id),
        hasLength(2),
      );
    },
  );

  test('claim business failure rolls back every step', () async {
    final profileId = await createPlayer(
      saved: 600,
      activeGoalId: 'goal_scooter',
    );
    final db = await database.database;
    await db.insert('inventory', {
      'profile_id': profileId,
      'item_id': 'reward_scooter',
      'quantity': 1,
      'acquired_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    });

    await expectLater(
      savings.claimGoal(
        profileId: profileId,
        goalId: 'goal_scooter',
        operationId: 'claim-owned',
      ),
      throwsA(isA<SavingsRewardAlreadyOwnedException>()),
    );
    final state = (await games.getGameState(profileId))!;
    expect(state.savedAmount, 600);
    expect(state.activeGoalId, 'goal_scooter');
    expect(await games.getCompletedGoals(profileId), isEmpty);
  });

  test(
    'failure during claim transaction rolls back completed row and state',
    () async {
      final profileId = await createPlayer(
        saved: 600,
        activeGoalId: 'goal_scooter',
        goalChangeUsed: true,
      );
      final db = await database.database;
      await db.execute('''
      CREATE TRIGGER fail_savings_reward
      BEFORE INSERT ON inventory
      WHEN NEW.item_id = 'reward_scooter'
      BEGIN
        SELECT RAISE(ABORT, 'forced reward failure');
      END
    ''');

      await expectLater(
        savings.claimGoal(
          profileId: profileId,
          goalId: 'goal_scooter',
          operationId: 'claim-rollback',
        ),
        throwsA(anything),
      );
      final state = (await games.getGameState(profileId))!;
      expect(state.savedAmount, 600);
      expect(state.activeGoalId, 'goal_scooter');
      expect(state.goalChangeUsed, isTrue);
      expect(await games.getCompletedGoals(profileId), isEmpty);
      expect(await games.getInventoryQuantity(profileId, 'reward_scooter'), 0);
    },
  );

  test(
    'claim not reached exposes missing amount and changes nothing',
    () async {
      final profileId = await createPlayer(
        saved: 450,
        activeGoalId: 'goal_scooter',
      );
      await expectLater(
        savings.claimGoal(
          profileId: profileId,
          goalId: 'goal_scooter',
          operationId: 'claim-too-soon',
        ),
        throwsA(
          isA<SavingsGoalNotReachedException>()
              .having((error) => error.goalPrice, 'goalPrice', 600)
              .having((error) => error.savedAmount, 'savedAmount', 450)
              .having((error) => error.missingAmount, 'missingAmount', 150),
        ),
      );
      expect((await games.getGameState(profileId))!.savedAmount, 450);
      expect(await games.getCompletedGoals(profileId), isEmpty);
    },
  );

  test('all completed goals can resolve the special period decision', () async {
    final profileId = await createPlayer(saved: 1900);
    for (var index = 0; index < goals.length; index++) {
      final goal = goals[index];
      await savings.selectGoal(profileId: profileId, goalId: goal.id);
      await savings.claimGoal(
        profileId: profileId,
        goalId: goal.id,
        operationId: 'claim-$index',
      );
    }
    final before = (await games.getGameState(profileId))!;
    final period = await startActive(profileId);
    final resolved = await savings.resolveAllGoalsCompletedDecision(
      profileId: profileId,
      periodId: period.id!,
    );
    final after = (await games.getGameState(profileId))!;
    expect(resolved.resolvedCheckpoints, contains('savings_decision'));
    expect(after.walletBalance, before.walletBalance + 500);
    expect(after.savedAmount, before.savedAmount);
    expect(
      await games.getTransactions(profileId, periodId: period.id),
      hasLength(1),
    );
  });

  test('special all-goals decision rejects an incomplete catalog', () async {
    final profileId = await createPlayer();
    final period = await startActive(profileId);
    await expectLater(
      savings.resolveAllGoalsCompletedDecision(
        profileId: profileId,
        periodId: period.id!,
      ),
      throwsA(isA<SavingsAllGoalsNotCompletedException>()),
    );
    expect(
      (await games.getPeriodById(profileId, period.id!))!.resolvedCheckpoints,
      isNot(contains('savings_decision')),
    );
  });

  test('DEMO reset removes completed savings goals and rewards', () async {
    final profileId = await createPlayer(
      saved: 400,
      activeGoalId: 'goal_night_light',
      profileType: ProfileType.demo,
    );
    await savings.claimGoal(
      profileId: profileId,
      goalId: 'goal_night_light',
      operationId: 'demo-claim',
    );
    expect(await games.getCompletedGoals(profileId), hasLength(1));

    await games.clearDemoRuntimeData(profileId);
    expect(await games.getCompletedGoals(profileId), isEmpty);
    expect(
      await games.getInventoryQuantity(profileId, 'reward_night_light'),
      0,
    );
    expect(await games.getGameState(profileId), isNull);
    expect((await games.ensureInitialState(profileId)).goalChangeUsed, isFalse);
  });

  test('savings goal state and rewards survive database reopen', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('finny_savings_');
    final path = '${directory.path}/finny.sqlite';
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final firstDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    final firstProfiles = SqliteProfileRepository(firstDatabase);
    final firstGames = SqliteGameRepository(firstDatabase);
    final content = TestContentRepository(
      testPeriodDefinitions(),
      goals: goals,
    );
    final firstSavings = SavingsService(firstGames, content);
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
        activeGoalId: 'goal_play_house',
        savedAmount: 700,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await firstSavings.changeGoal(
      profileId: profile.id!,
      goalId: 'goal_scooter',
    );
    await firstSavings.claimGoal(
      profileId: profile.id!,
      goalId: 'goal_scooter',
      operationId: 'persistent-claim',
    );
    await firstSavings.selectGoal(
      profileId: profile.id!,
      goalId: 'goal_play_house',
    );
    final firstPeriods = PeriodService(firstGames, content);
    final started = await firstPeriods.startNextPeriod(profileId: profile.id!);
    await BudgetService(firstGames)
        .confirmPlan(profileId: profile.id!, periodId: started!.id!);
    await firstSavings.deposit(
      profileId: profile.id!,
      periodId: started.id!,
      amount: 300,
      operationId: 'persistent-deposit',
    );
    await firstSavings.changeGoal(
      profileId: profile.id!,
      goalId: 'goal_night_light',
    );
    await firstDatabase.close();

    final reopened = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    final reopenedGames = SqliteGameRepository(reopened);
    final restored = (await reopenedGames.getGameState(profile.id!))!;
    expect(restored.activeGoalId, 'goal_night_light');
    expect(restored.savedAmount, 400);
    expect(restored.goalChangeUsed, isTrue);
    expect(await reopenedGames.getCompletedGoals(profile.id!), hasLength(1));
    expect(
      await reopenedGames.getInventoryQuantity(profile.id!, 'reward_scooter'),
      1,
    );
    await reopened.close();
  });
}
