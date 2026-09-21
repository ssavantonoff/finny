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
  const taskId = 'task_need_or_want_01';
  const correct = {'food': 'need', 'ball': 'want'};
  const wrong = {'food': 'want', 'ball': 'need'};

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
        testPeriodDefinitions(count: 1),
        tasks: [testCategorizationTask()],
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
      definitionId: 'period_1',
      periodNumber: 1,
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
  ) => tasks.submitCategorization(
    profileId: player.profileId,
    periodId: player.period.id!,
    taskId: taskId,
    assignments: assignments,
  );

  test('incorrect categorization returns IDs and makes no mutations', () async {
    final player = await createPlayer();
    final beforeState = (await games.getGameState(player.profileId))!.toMap();
    final beforePeriod = (await games.getPeriodById(
      player.profileId,
      player.period.id!,
    ))!.toMap();
    final beforePet = (await games.getPet(player.profileId))!.toMap();
    final beforeTransactions = (await games.getTransactions(player.profileId))
        .map((entry) => entry.toMap())
        .toList();

    final result = await submit(player, wrong);

    expect(result, isA<TaskCategorizationIncorrect>());
    expect((result as TaskCategorizationIncorrect).incorrectItemIds, {
      'food',
      'ball',
    });
    expect((await games.getGameState(player.profileId))?.toMap(), beforeState);
    expect(
      (await games.getPeriodById(player.profileId, player.period.id!))?.toMap(),
      beforePeriod,
    );
    expect((await games.getPet(player.profileId))?.toMap(), beforePet);
    expect(
      (await games.getTransactions(player.profileId))
          .map((entry) => entry.toMap())
          .toList(),
      beforeTransactions,
    );
    expect(await games.getTaskProgress(player.profileId, taskId), isNull);
  });

  test(
    'correct categorization rewards and advances canonical time once',
    () async {
      final player = await createPlayer();
      final petBefore = (await games.getPet(player.profileId))!;
      final expectedPet = VirtualDayRules.applyAction(
        pet: petBefore,
        oldProgress: player.period.dayProgress,
        timeCost: VirtualDayRules.requiredTaskCost,
      ).pet;

      final completed = await submit(player, correct) as TaskAnswerCompleted;

      expect(completed.canonicalReward, 50);
      expect(completed.rewardAppliedNow, isTrue);
      expect(completed.wasAlreadyCompleted, isFalse);
      expect(completed.gameState.walletBalance, 550);
      expect(completed.period.dayProgress, 40);
      expect(completed.period.resolvedCheckpoints, ['financial_task']);
      expect(
        (await games.getPet(player.profileId))?.toMap(),
        expectedPet.toMap(),
      );
      final progress = await games.getTaskProgress(player.profileId, taskId);
      expect(progress?.status, TaskProgressStatus.completed);
      expect(progress?.rewardClaimed, isTrue);
      expect(progress?.scenarioState, {
        'type': 'categorization',
        'assignments': correct,
      });
      final rewards = (await games.getTransactions(player.profileId))
          .where((entry) => entry.type == GameTransactionType.taskReward);
      expect(rewards, hasLength(1));
      expect(rewards.single.amount, 50);
    },
  );

  test('correct categorization retry does not duplicate effects', () async {
    final player = await createPlayer();
    await submit(player, correct);

    final replay = await submit(player, correct) as TaskAnswerCompleted;

    expect(replay.rewardAppliedNow, isFalse);
    expect(replay.wasAlreadyCompleted, isTrue);
    expect(replay.gameState.walletBalance, 550);
    expect(replay.period.dayProgress, 40);
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

  test('malformed categorization submissions are inert', () async {
    final player = await createPlayer();
    final invalid = <Map<String, String>>[
      const {'food': 'need'},
      const {'food': 'need', 'ball': 'want', 'extra': 'want'},
      const {'food': 'need', 'unknown': 'want'},
      const {'food': 'need', 'ball': 'other'},
      const {'food': 'need', 'ball': ''},
    ];
    final beforeState = (await games.getGameState(player.profileId))!.toMap();
    final beforePeriod = (await games.getPeriodById(
      player.profileId,
      player.period.id!,
    ))!.toMap();
    final beforePet = (await games.getPet(player.profileId))!.toMap();
    final beforeTransactions = await games.getTransactions(player.profileId);

    for (final assignments in invalid) {
      await expectLater(submit(player, assignments), throwsArgumentError);
    }

    expect((await games.getGameState(player.profileId))?.toMap(), beforeState);
    expect(
      (await games.getPeriodById(player.profileId, player.period.id!))?.toMap(),
      beforePeriod,
    );
    expect((await games.getPet(player.profileId))?.toMap(), beforePet);
    expect(
      (await games.getTransactions(player.profileId)).length,
      beforeTransactions.length,
    );
    expect(await games.getTaskProgress(player.profileId, taskId), isNull);
  });

  test('legacy Day 1 choice completion remains a valid replay', () async {
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
        scenarioState: const {'answerId': 'apple'},
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

    final replay = await submit(player, correct) as TaskAnswerCompleted;

    expect(replay.wasAlreadyCompleted, isTrue);
    expect(replay.rewardAppliedNow, isFalse);
    expect(replay.gameState.walletBalance, 550);
    expect(
      (await games.getTaskProgress(player.profileId, taskId))?.scenarioState,
      {'answerId': 'apple'},
    );
    expect(
      (await games.getTransactions(player.profileId))
          .where((entry) => entry.type == GameTransactionType.taskReward),
      hasLength(1),
    );
  });
}
