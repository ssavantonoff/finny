import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/task_progress.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/models/virtual_day_rules.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

void main() {
  const taskId = 'task_priority_02';
  const correct = {'food': 'buy_now', 'shampoo': 'buy_now', 'bow': 'later'};
  const wrongAffordable = {
    'food': 'later',
    'shampoo': 'buy_now',
    'bow': 'buy_now',
  };

  late AppDatabase database;
  late SqliteProfileRepository profiles;
  late SqliteGameRepository games;
  late TaskService tasks;

  setUp(() {
    database = createTestDatabase();
    profiles = SqliteProfileRepository(database);
    games = SqliteGameRepository(database);
    tasks = TaskService(
      games,
      SqliteTaskCompletionPort(database),
      TestContentRepository(
        testPeriodDefinitions(count: 2),
        tasks: [testBudgetPriorityTask()],
      ),
    );
  });

  tearDown(() => database.close());

  Future<({int profileId, GamePeriod period})> createPlayer() async {
    final profile = await profiles.create(
      Profile(
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final profileId = profile.id!;
    await games.ensureInitialState(profileId);
    await games.savePet(
      Pet(
        profileId: profileId,
        name: 'Финни',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 1,
        growthPoints: 0,
        satiety: 55,
        care: 80,
        mood: 80,
      ),
    );
    var period = await games.startPeriod(
      profileId: profileId,
      definitionId: 'period_2',
      periodNumber: 2,
      baseIncome: 500,
      requiredCheckpoints: const ['financial_task', 'savings_decision'],
      createdAt: DateTime.utc(2026, 1, 2),
    );
    period = await confirmBudgetForTest(
      games,
      profileId: profileId,
      periodId: period.id!,
    );
    return (profileId: profileId, period: period);
  }

  Future<TaskSubmissionResult> submit(
    ({int profileId, GamePeriod period}) player,
    Map<String, String> assignments,
  ) => tasks.submitBudgetPriority(
    profileId: player.profileId,
    periodId: player.period.id!,
    taskId: taskId,
    assignments: assignments,
  );

  Future<
    ({
      Map<String, Object?> state,
      Map<String, Object?> period,
      Map<String, Object?> pet,
      List<Map<String, Object?>> transactions,
      List<Map<String, Object?>> inventory,
    })
  >
  snapshot(({int profileId, GamePeriod period}) player) async => (
    state: (await games.getGameState(player.profileId))!.toMap(),
    period: (await games.getPeriodById(
      player.profileId,
      player.period.id!,
    ))!.toMap(),
    pet: (await games.getPet(player.profileId))!.toMap(),
    transactions: (await games.getTransactions(player.profileId))
        .map((entry) => entry.toMap())
        .toList(),
    inventory: await (await database.database).query(
      'inventory',
      where: 'profile_id = ?',
      whereArgs: [player.profileId],
    ),
  );

  Future<void> expectUnchanged(
    ({int profileId, GamePeriod period}) player,
    ({
      Map<String, Object?> state,
      Map<String, Object?> period,
      Map<String, Object?> pet,
      List<Map<String, Object?>> transactions,
      List<Map<String, Object?>> inventory,
    })
    before,
  ) async {
    final after = await snapshot(player);
    expect(after.state, before.state);
    expect(after.period, before.period);
    expect(after.pet, before.pet);
    expect(after.transactions, before.transactions);
    expect(after.inventory, before.inventory);
    expect(await games.getTaskProgress(player.profileId, taskId), isNull);
  }

  test(
    'wrong affordable priority returns canonical IDs with no mutations',
    () async {
      final player = await createPlayer();
      final before = await snapshot(player);

      final result = await submit(player, wrongAffordable);

      expect(result, isA<TaskBudgetPriorityIncorrect>());
      final incorrect = result as TaskBudgetPriorityIncorrect;
      expect(incorrect.incorrectItemIds, {'food', 'bow'});
      expect(incorrect.overBudgetBy, 0);
      await expectUnchanged(player, before);
    },
  );

  test('correct priority grants only canonical reward and time once', () async {
    final player = await createPlayer();
    final stateBefore = (await games.getGameState(player.profileId))!;
    final petBefore = (await games.getPet(player.profileId))!;
    final inventoryBefore = await (await database.database).query(
      'inventory',
      where: 'profile_id = ?',
      whereArgs: [player.profileId],
    );
    final expectedPet = VirtualDayRules.applyAction(
      pet: petBefore,
      oldProgress: player.period.dayProgress,
      timeCost: VirtualDayRules.requiredTaskCost,
    ).pet;

    final completed = await submit(player, correct) as TaskAnswerCompleted;

    expect(completed.canonicalReward, 50);
    expect(completed.rewardAppliedNow, isTrue);
    expect(completed.wasAlreadyCompleted, isFalse);
    expect(completed.gameState.walletBalance, stateBefore.walletBalance + 50);
    expect(completed.gameState.savedAmount, stateBefore.savedAmount);
    expect(completed.period.dayProgress, player.period.dayProgress + 30);
    expect(completed.period.actualNeed, player.period.actualNeed);
    expect(completed.period.actualWant, player.period.actualWant);
    expect(completed.period.actualSavings, player.period.actualSavings);
    expect(completed.period.resolvedCheckpoints, ['financial_task']);
    expect(
      (await games.getPet(player.profileId))?.toMap(),
      expectedPet.toMap(),
    );
    expect(
      await (await database.database).query(
        'inventory',
        where: 'profile_id = ?',
        whereArgs: [player.profileId],
      ),
      inventoryBefore,
    );
    final progress = await games.getTaskProgress(player.profileId, taskId);
    expect(progress?.status, TaskProgressStatus.completed);
    expect(progress?.rewardClaimed, isTrue);
    expect(progress?.scenarioState, {
      'type': 'budget_priority',
      'assignments': correct,
    });
    final transactions = await games.getTransactions(player.profileId);
    final rewards = transactions.where(
      (entry) => entry.type == GameTransactionType.taskReward,
    );
    expect(rewards, hasLength(1));
    expect(rewards.single.amount, 50);
    expect(
      transactions.where(
        (entry) =>
            entry.type == GameTransactionType.needExpense ||
            entry.type == GameTransactionType.wantExpense,
      ),
      isEmpty,
    );
  });

  test('correct priority retry does not duplicate effects', () async {
    final player = await createPlayer();
    await submit(player, correct);
    final beforeReplay = await snapshot(player);

    final replay = await submit(player, correct) as TaskAnswerCompleted;

    expect(replay.rewardAppliedNow, isFalse);
    expect(replay.wasAlreadyCompleted, isTrue);
    final afterReplay = await snapshot(player);
    expect(afterReplay.state, beforeReplay.state);
    expect(afterReplay.period, beforeReplay.period);
    expect(afterReplay.pet, beforeReplay.pet);
    expect(afterReplay.transactions, beforeReplay.transactions);
    expect(afterReplay.inventory, beforeReplay.inventory);
    expect(
      (await games.getTransactions(player.profileId))
          .where((entry) => entry.type == GameTransactionType.taskReward),
      hasLength(1),
    );
    final rows = await (await database.database).query(
      'task_progress',
      where: 'profile_id = ? AND task_id = ?',
      whereArgs: [player.profileId, taskId],
    );
    expect(rows, hasLength(1));
  });

  test('malformed budget priority submissions are inert', () async {
    final player = await createPlayer();
    final before = await snapshot(player);
    final invalid = <Map<String, String>>[
      const {'food': 'buy_now', 'shampoo': 'buy_now'},
      const {
        'food': 'buy_now',
        'shampoo': 'buy_now',
        'bow': 'later',
        'extra': 'later',
      },
      const {'food': 'buy_now', 'shampoo': 'buy_now', 'unknown': 'later'},
      const {'food': 'buy_now', 'shampoo': 'other', 'bow': 'later'},
      const {'': 'buy_now', 'shampoo': 'buy_now', 'bow': 'later'},
      const {'food': 'buy_now', 'shampoo': '', 'bow': 'later'},
    ];

    for (final assignments in invalid) {
      await expectLater(submit(player, assignments), throwsArgumentError);
    }

    await expectUnchanged(player, before);
  });

  test('direct over-budget assignment is rejected without mutations', () async {
    final player = await createPlayer();
    final before = await snapshot(player);

    final result = await submit(player, const {
      'food': 'buy_now',
      'shampoo': 'buy_now',
      'bow': 'buy_now',
    });

    expect(result, isA<TaskBudgetPriorityIncorrect>());
    final incorrect = result as TaskBudgetPriorityIncorrect;
    expect(incorrect.incorrectItemIds, {'bow'});
    expect(incorrect.overBudgetBy, 80);
    await expectUnchanged(player, before);
  });

  test('legacy Day 2 choice completion remains a valid replay', () async {
    final player = await createPlayer();
    final db = await database.database;
    await db.insert(
      'transactions',
      GameTransaction(
        profileId: player.profileId,
        periodId: player.period.id!,
        type: GameTransactionType.taskReward,
        amount: 50,
        source: 'task_reward_$taskId',
        description: 'Legacy task reward',
        createdAt: DateTime.utc(2026, 1, 3),
        deduplicationKey: 'task_reward_${player.period.id}_$taskId',
      ).toMap(),
    );
    await db.insert(
      'task_progress',
      TaskProgress(
        profileId: player.profileId,
        taskId: taskId,
        status: TaskProgressStatus.completed,
        rewardClaimed: true,
        scenarioState: const {'answerId': 'food'},
        updatedAt: DateTime.utc(2026, 1, 3),
      ).toMap(),
    );
    await db.update(
      'game_periods',
      {'resolved_checkpoints': '["financial_task"]'},
      where: 'id = ? AND profile_id = ?',
      whereArgs: [player.period.id!, player.profileId],
    );
    await db.update(
      'game_states',
      {'wallet_balance': 550},
      where: 'profile_id = ?',
      whereArgs: [player.profileId],
    );
    final periodBefore = (await games.getPeriodById(
      player.profileId,
      player.period.id!,
    ))!;

    final replay = await submit(player, correct) as TaskAnswerCompleted;

    expect(replay.wasAlreadyCompleted, isTrue);
    expect(replay.rewardAppliedNow, isFalse);
    expect(replay.gameState.walletBalance, 550);
    expect(replay.period.dayProgress, periodBefore.dayProgress);
    expect(
      (await games.getTaskProgress(player.profileId, taskId))?.scenarioState,
      {'answerId': 'food'},
    );
    expect(
      (await games.getTransactions(player.profileId))
          .where((entry) => entry.type == GameTransactionType.taskReward),
      hasLength(1),
    );
  });
}
