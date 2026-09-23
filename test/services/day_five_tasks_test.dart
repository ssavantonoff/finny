import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

const _budget = 'task_independent_budget_05';
const _repair = 'task_plan_repair_05';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late SqliteGameRepository games;
  late TaskService tasks;
  late int profileId;
  late int periodId;

  setUp(() async {
    database = createTestDatabase();
    games = SqliteGameRepository(database);
    tasks = TaskService(
      games,
      SqliteTaskCompletionPort(database),
      AssetContentRepository(),
    );
    final profile = await SqliteProfileRepository(database).create(
      Profile(
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026),
      ),
    );
    profileId = profile.id!;
    await games.ensureInitialState(profileId);
    final period = await games.startPeriod(
      profileId: profileId,
      definitionId: 'period_5',
      periodNumber: 5,
      baseIncome: 500,
      requiredCheckpoints: const ['financial_task', 'savings_decision'],
      createdAt: DateTime.utc(2026),
    );
    periodId = period.id!;
    await confirmBudgetForTest(games, profileId: profileId, periodId: periodId);
  });
  tearDown(() => database.close());

  Future<TaskSubmissionResult> budget({
    Set<String> items = const {'food_feed', 'care_comb'},
    int savings = 50,
  }) => tasks.submitIndependentBudget(
    profileId: profileId,
    periodId: periodId,
    taskId: _budget,
    selectedItemIds: items,
    savingsAmount: savings,
  );

  Future<TaskSubmissionResult> repair({
    Set<String> items = const {'food_feed', 'care_comb', 'scenario_waterer_05'},
    int savings = 50,
  }) => tasks.submitPlanRepair(
    profileId: profileId,
    periodId: periodId,
    taskId: _repair,
    nowItemIds: items,
    savingsAmount: savings,
  );

  test(
    'each task evaluates its own rules with canonical shop prices',
    () async {
      for (final result in [
        await budget(items: const {'toy_ball'}),
        await budget(savings: 40),
        await budget(
          items: const {'food_feed', 'care_comb', 'toy_ball', 'accessory_bow'},
        ),
        await repair(items: const {'food_feed', 'care_comb'}),
        await repair(savings: 0),
        await repair(
          items: const {
            'food_feed',
            'care_comb',
            'toy_ball',
            'scenario_waterer_05',
          },
          savings: 70,
        ),
      ]) {
        expect(result, isA<TaskDayFiveIncorrect>());
      }
      expect(
        (await tasks.loadDayFiveCompletion(
          profileId: profileId,
          periodId: periodId,
        )).completedCount,
        0,
      );
      expect((await games.getGameState(profileId))!.walletBalance, 500);
      expect((await games.getPeriodById(profileId, periodId))!.dayProgress, 10);
      expect(await games.getTaskProgress(profileId, _budget), isNull);
      expect(await games.getTaskProgress(profileId, _repair), isNull);
    },
  );

  for (final reverse in [false, true]) {
    test(
      'two proofs award 25+25 and 15+15 in ${reverse ? 'reverse' : 'normal'} order',
      () async {
        final first =
            (reverse ? await repair() : await budget()) as TaskAnswerCompleted;
        expect(first.canonicalReward, 25);
        expect(first.rewardAppliedNow, isTrue);
        expect(first.period.dayProgress, 25);
        expect(
          first.period.resolvedCheckpoints,
          isNot(contains('financial_task')),
        );
        expect(
          (await tasks.loadDayFiveCompletion(
            profileId: profileId,
            periodId: periodId,
          )).completedCount,
          1,
        );
        final firstReplay =
            (reverse
                    ? await repair(items: const {})
                    : await budget(items: const {}))
                as TaskAnswerCompleted;
        expect(firstReplay.wasAlreadyCompleted, isTrue);
        expect(firstReplay.period.dayProgress, 25);
        expect((await games.getGameState(profileId))!.walletBalance, 525);
        final second =
            (reverse ? await budget() : await repair()) as TaskAnswerCompleted;
        expect(second.period.dayProgress, 40);
        expect(second.period.resolvedCheckpoints, contains('financial_task'));
        expect((await games.getGameState(profileId))!.walletBalance, 550);
        final rewards = (await games.getTransactions(profileId))
            .where((entry) => entry.type == GameTransactionType.taskReward)
            .toList();
        expect(rewards.map((entry) => entry.amount), [25, 25]);
        expect(
          (await tasks.loadDayFiveCompletion(
            profileId: profileId,
            periodId: periodId,
          )).completedCount,
          2,
        );
        final replay = (await budget(items: const {})) as TaskAnswerCompleted;
        expect(replay.wasAlreadyCompleted, isTrue);
        expect(replay.rewardAppliedNow, isFalse);
        expect((await games.getGameState(profileId))!.walletBalance, 550);
        expect(
          (await games.getTransactions(profileId))
              .where((entry) => entry.type == GameTransactionType.taskReward),
          hasLength(2),
        );
        expect(
          (await games.getTaskProgress(
            profileId,
            _budget,
          ))!.scenarioState['selectedItemIds'],
          containsAll(['food_feed', 'care_comb']),
        );
        expect(
          (await games.getTaskProgress(
            profileId,
            _repair,
          ))!.scenarioState['selectedItemIds'],
          containsAll(['food_feed', 'care_comb', 'scenario_waterer_05']),
        );
      },
    );
  }

  test(
    'different independent budget choices persist as actually submitted',
    () async {
      final completed = await budget(
        items: const {'food_feed', 'care_comb', 'toy_ball'},
        savings: 50,
      );
      expect(completed, isA<TaskAnswerCompleted>());
      final stored = (await games.getTaskProgress(
        profileId,
        _budget,
      ))!.scenarioState;
      expect(
        stored['selectedItemIds'],
        containsAll(['food_feed', 'care_comb', 'toy_ball']),
      );
      expect(stored['savingsAmount'], 50);
      expect(
        (await tasks.loadDayFiveCompletion(
          profileId: profileId,
          periodId: periodId,
        )).completedCount,
        1,
      );
    },
  );

  test(
    'ball can stay Now when plan repair savings are reduced to 10',
    () async {
      final completed = await repair(
        items: const {
          'food_feed',
          'care_comb',
          'toy_ball',
          'scenario_waterer_05',
        },
        savings: 10,
      );
      expect(completed, isA<TaskAnswerCompleted>());
      final stored = (await games.getTaskProgress(
        profileId,
        _repair,
      ))!.scenarioState;
      expect(stored['selectedItemIds'], contains('toy_ball'));
      expect(stored['savingsAmount'], 10);
      expect(
        (await tasks.loadDayFiveCompletion(
          profileId: profileId,
          periodId: periodId,
        )).completedCount,
        1,
      );
    },
  );

  test(
    'bonus-only history does not count toward either required task',
    () async {
      final db = await database.database;
      await db.insert('task_progress', {
        'profile_id': profileId,
        'task_id': 'task_bonus_reserve_05',
        'status': 'completed',
        'reward_claimed': 1,
        'scenario_state': '{"answerId":"reserve"}',
        'updated_at': DateTime.utc(2026).toIso8601String(),
      });
      await db.insert(
        'transactions',
        GameTransaction(
          profileId: profileId,
          periodId: periodId,
          type: GameTransactionType.taskReward,
          amount: 30,
          source: 'task_reward_task_bonus_reserve_05',
          description: 'Legacy bonus',
          createdAt: DateTime.utc(2026),
          deduplicationKey: 'task_reward_${periodId}_task_bonus_reserve_05',
        ).toMap(),
      );
      expect(
        (await tasks.loadDayFiveCompletion(
          profileId: profileId,
          periodId: periodId,
        )).completedCount,
        0,
      );
      expect(await budget(), isA<TaskAnswerCompleted>());
      expect(
        (await tasks.loadDayFiveCompletion(
          profileId: profileId,
          periodId: periodId,
        )).completedCount,
        1,
      );
      expect(
        (await games.getTransactions(profileId))
            .where((entry) => entry.type == GameTransactionType.taskReward),
        hasLength(2),
      );
    },
  );

  test('progress without reward is an integrity error', () async {
    await (await database.database).insert('task_progress', {
      'profile_id': profileId,
      'task_id': _budget,
      'status': 'completed',
      'reward_claimed': 1,
      'scenario_state': '{"type":"independent_budget","selectedItemIds":["food_feed","care_comb"],"savingsAmount":50}',
      'updated_at': DateTime.utc(2026).toIso8601String(),
    });
    await expectLater(
      tasks.loadDayFiveCompletion(profileId: profileId, periodId: periodId),
      throwsA(isA<TaskIntegrityException>()),
    );
    await expectLater(repair(), throwsA(isA<TaskIntegrityException>()));
  });

  test(
    'completed legacy main and bonus stay historical without new proofs',
    () async {
      final db = await database.database;
      await db.insert('task_progress', {
        'profile_id': profileId,
        'task_id': 'task_final_choice_05',
        'status': 'completed',
        'reward_claimed': 1,
        'scenario_state': '{"answerId":"balanced"}',
        'updated_at': DateTime.utc(2026).toIso8601String(),
      });
      await db.insert('task_progress', {
        'profile_id': profileId,
        'task_id': 'task_bonus_reserve_05',
        'status': 'completed',
        'reward_claimed': 1,
        'scenario_state': '{"answerId":"reserve"}',
        'updated_at': DateTime.utc(2026).toIso8601String(),
      });
      for (final (id, amount) in [
        ('task_final_choice_05', 50),
        ('task_bonus_reserve_05', 30),
      ]) {
        await db.insert(
          'transactions',
          GameTransaction(
            profileId: profileId,
            periodId: periodId,
            type: GameTransactionType.taskReward,
            amount: amount,
            source: 'task_reward_$id',
            description: 'Legacy reward',
            createdAt: DateTime.utc(2026),
            deduplicationKey: 'task_reward_${periodId}_$id',
          ).toMap(),
        );
      }
      await db.update(
        'game_periods',
        {'resolved_checkpoints': '["financial_task"]', 'day_progress': 40},
        where: 'id = ?',
        whereArgs: [periodId],
      );
      await db.update(
        'game_states',
        {'wallet_balance': 580},
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      final completion = await tasks.loadDayFiveCompletion(
        profileId: profileId,
        periodId: periodId,
      );
      expect(completion.legacyCompleted, isTrue);
      expect(completion.completedCount, 2);
      expect(completion.completedTaskIds, isEmpty);
      await expectLater(budget(), throwsStateError);
      expect(await games.getTaskProgress(profileId, _budget), isNull);
      expect(await games.getTaskProgress(profileId, _repair), isNull);
      expect((await games.getGameState(profileId))!.walletBalance, 580);
      expect(
        (await games.getTransactions(profileId))
            .where((entry) => entry.type == GameTransactionType.taskReward),
        hasLength(2),
      );
    },
  );

  test(
    'resolved checkpoint without either valid proof is integrity error',
    () async {
      await (await database.database).update(
        'game_periods',
        {'resolved_checkpoints': '["financial_task"]'},
        where: 'id = ?',
        whereArgs: [periodId],
      );
      await expectLater(
        tasks.loadDayFiveCompletion(profileId: profileId, periodId: periodId),
        throwsA(isA<TaskIntegrityException>()),
      );
      await expectLater(budget(), throwsA(isA<TaskIntegrityException>()));
    },
  );
}
