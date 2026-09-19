import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/task_progress.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

const _taskId = 'task_period_1';
const _correct = 'apple';
const _wrong = 'ball';

void main() {
  late AppDatabase database;
  late SqliteProfileRepository profiles;
  late SqliteGameRepository games;
  late TestContentRepository content;
  late TaskService tasks;

  setUp(() {
    database = createTestDatabase();
    profiles = SqliteProfileRepository(database);
    games = SqliteGameRepository(database);
    content = TestContentRepository(testPeriodDefinitions(count: 1));
    tasks = TaskService(games, SqliteTaskCompletionPort(database), content);
  });
  tearDown(() => database.close());

  Future<({int profileId, GamePeriod period})> createPeriod({
    ProfileType type = ProfileType.normal,
    bool active = true,
    List<String> checkpoints = const [
      'financial_task',
      'mandatory_need',
      'savings_decision',
    ],
  }) async {
    final profile = await profiles.create(
      Profile(
        gameName: type == ProfileType.normal ? 'Игрок' : 'Демо',
        profileType: type,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await games.ensureInitialState(profile.id!);
    var period = await games.startPeriod(
      profileId: profile.id!,
      definitionId: 'period_1',
      periodNumber: 1,
      baseIncome: 500,
      requiredCheckpoints: checkpoints,
      createdAt: DateTime.utc(2026, 1, 2),
    );
    if (active) {
      period = await games.confirmBudget(
        profileId: profile.id!,
        periodId: period.id!,
      );
    }
    return (profileId: profile.id!, period: period);
  }

  Future<TaskSubmissionResult> submit(
    ({int profileId, GamePeriod period}) player, {
    String answerId = _correct,
  }) => tasks.submitAnswer(
    profileId: player.profileId,
    periodId: player.period.id!,
    taskId: _taskId,
    answerId: answerId,
  );

  Future<void> seedReward(
    int profileId,
    int periodId, {
    int amount = 50,
  }) async {
    await (await database.database).insert(
      'transactions',
      GameTransaction(
        profileId: profileId,
        periodId: periodId,
        type: GameTransactionType.taskReward,
        amount: amount,
        source: 'task_reward_$_taskId',
        description: 'Legacy task reward',
        createdAt: DateTime.utc(2026, 1, 3),
        deduplicationKey: 'task_reward_${periodId}_$_taskId',
      ).toMap(),
    );
  }

  Future<void> seedProgress(
    int profileId, {
    bool claimed = true,
    String answerId = _correct,
    String status = 'completed',
    String? rawScenario,
  }) async {
    await (await database.database).insert('task_progress', {
      'profile_id': profileId,
      'task_id': _taskId,
      'status': status,
      'reward_claimed': claimed ? 1 : 0,
      'scenario_state': rawScenario ?? '{"answerId":"$answerId"}',
      'updated_at': DateTime.utc(2026, 1, 3).toIso8601String(),
    });
  }

  Future<void> seedResolved(int profileId, int periodId) async {
    await (await database.database).update(
      'game_periods',
      {'resolved_checkpoints': '["financial_task"]'},
      where: 'id = ? AND profile_id = ?',
      whereArgs: [periodId, profileId],
    );
  }

  test(
    'wrong and unknown answers make no Core mutations; correct works',
    () async {
      final player = await createPeriod();
      final stateBefore = (await games.getGameState(player.profileId))!.toMap();
      final periodBefore = (await games.getPeriodById(
        player.profileId,
        player.period.id!,
      ))!.toMap();
      final transactionsBefore = (await games.getTransactions(player.profileId))
          .map((entry) => entry.toMap())
          .toList();

      for (final answerId in [_wrong, 'decoration']) {
        final wrong = await submit(player, answerId: answerId);
        expect(wrong, isA<TaskAnswerIncorrect>());
        expect(
          wrong.explanation,
          testFinancialTask(1).choiceScenario.explanation,
        );
        expect((wrong as TaskAnswerIncorrect).rewardAppliedNow, isFalse);
        expect(
          (await games.getGameState(player.profileId))?.toMap(),
          stateBefore,
        );
        expect(
          (await games.getPeriodById(
            player.profileId,
            player.period.id!,
          ))?.toMap(),
          periodBefore,
        );
        expect(
          (await games.getTransactions(player.profileId))
              .map((entry) => entry.toMap())
              .toList(),
          transactionsBefore,
        );
        expect(await games.getTaskProgress(player.profileId, _taskId), isNull);
      }
      await expectLater(
        submit(player, answerId: 'unknown'),
        throwsArgumentError,
      );
      expect(
        (await games.getGameState(player.profileId))?.toMap(),
        stateBefore,
      );
      expect(
        (await games.getPeriodById(
          player.profileId,
          player.period.id!,
        ))?.toMap(),
        periodBefore,
      );
      expect(
        (await games.getTransactions(player.profileId))
            .map((entry) => entry.toMap())
            .toList(),
        transactionsBefore,
      );
      expect(await games.getTaskProgress(player.profileId, _taskId), isNull);

      final completed = await submit(player) as TaskAnswerCompleted;
      expect(completed.rewardAppliedNow, isTrue);
      expect(completed.gameState.walletBalance, 550);
    },
  );

  test(
    'correct answer atomically grants canonical reward and progress',
    () async {
      final player = await createPeriod();
      final completed = await submit(player) as TaskAnswerCompleted;
      expect(completed.canonicalReward, 50);
      expect(completed.rewardAppliedNow, isTrue);
      expect(completed.wasAlreadyCompleted, isFalse);
      expect(completed.gameState.walletBalance, 550);
      expect(completed.period.status, GamePeriodStatus.active);
      expect(completed.period.resolvedCheckpoints, ['financial_task']);
      final rewards = (await games.getTransactions(player.profileId))
          .where((entry) => entry.type == GameTransactionType.taskReward)
          .toList();
      expect(rewards, hasLength(1));
      expect(rewards.single.amount, 50);
      expect(rewards.single.profileId, player.profileId);
      expect(rewards.single.periodId, player.period.id);
      expect(rewards.single.source, 'task_reward_$_taskId');
      expect(
        rewards.single.deduplicationKey,
        'task_reward_${player.period.id}_$_taskId',
      );
      final progress = await games.getTaskProgress(player.profileId, _taskId);
      expect(progress?.status, TaskProgressStatus.completed);
      expect(progress?.rewardClaimed, isTrue);
      expect(progress?.scenarioState, {'answerId': _correct});
      expect(progress?.updatedAt.isUtc, isTrue);
    },
  );

  test(
    'final task checkpoint makes period ready and replay survives completion',
    () async {
      final player = await createPeriod(checkpoints: const ['financial_task']);
      final first = await submit(player) as TaskAnswerCompleted;
      expect(first.period.status, GamePeriodStatus.readyToFinish);
      final readyReplay =
          await submit(player, answerId: _wrong) as TaskAnswerCompleted;
      expect(readyReplay.wasAlreadyCompleted, isTrue);
      expect(readyReplay.rewardAppliedNow, isFalse);
      expect(readyReplay.gameState.walletBalance, 550);
      await completePeriodForTest(
        database,
        profileId: player.profileId,
        periodId: player.period.id!,
      );
      final completedReplay =
          await submit(player, answerId: _wrong) as TaskAnswerCompleted;
      expect(completedReplay.wasAlreadyCompleted, isTrue);
      expect(completedReplay.period.status, GamePeriodStatus.completed);
      expect(completedReplay.gameState.walletBalance, 550);
      expect(
        (await games.getTransactions(player.profileId))
            .where((entry) => entry.type == GameTransactionType.taskReward),
        hasLength(1),
      );
    },
  );

  test('concurrent correct submissions grant one reward', () async {
    final player = await createPeriod();
    final results = await Future.wait([submit(player), submit(player)]);
    final completed = results.cast<TaskAnswerCompleted>();
    expect(completed.where((result) => result.rewardAppliedNow), hasLength(1));
    expect(
      completed.where((result) => result.wasAlreadyCompleted),
      hasLength(1),
    );
    expect((await games.getGameState(player.profileId))?.walletBalance, 550);
    expect(
      (await games.getTransactions(player.profileId))
          .where((entry) => entry.type == GameTransactionType.taskReward),
      hasLength(1),
    );
    final rows = await (await database.database).query(
      'task_progress',
      where: 'profile_id = ? AND task_id = ?',
      whereArgs: [player.profileId, _taskId],
    );
    expect(rows, hasLength(1));
    expect(
      (await games.getPeriodById(
        player.profileId,
        player.period.id!,
      ))!.resolvedCheckpoints,
      ['financial_task'],
    );
  });

  test('generic checkpoint and reward APIs cannot bypass answer', () async {
    final player = await createPeriod();
    await expectLater(
      games.resolveCheckpoint(
        profileId: player.profileId,
        periodId: player.period.id!,
        checkpointId: 'financial_task',
      ),
      throwsStateError,
    );
    await expectLater(
      games.applyWalletChange(
        GameTransaction(
          profileId: player.profileId,
          periodId: player.period.id!,
          type: GameTransactionType.taskReward,
          amount: 50,
          source: 'task_reward_$_taskId',
          description: 'Forbidden',
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      ),
      throwsStateError,
    );
    await expectLater(
      games.applyIdempotentWalletChange(
        GameTransaction(
          profileId: player.profileId,
          periodId: player.period.id!,
          type: GameTransactionType.taskReward,
          amount: 50,
          source: 'task_reward_$_taskId',
          description: 'Forbidden',
          createdAt: DateTime.utc(2026, 1, 2),
          deduplicationKey: 'forbidden-task-reward',
        ),
      ),
      throwsStateError,
    );
    final ordinary = await games.resolveCheckpoint(
      profileId: player.profileId,
      periodId: player.period.id!,
      checkpointId: 'mandatory_need',
    );
    expect(ordinary.resolvedCheckpoints, ['mandatory_need']);
    final completed = await submit(player) as TaskAnswerCompleted;
    expect(completed.period.resolvedCheckpoints, [
      'financial_task',
      'mandatory_need',
    ]);
  });

  for (final variant in [
    'reward without progress',
    'checkpoint without progress or reward',
    'progress without reward',
    'progress without checkpoint',
    'unclaimed reward',
    'wrong stored answer',
    'malformed status',
    'malformed scenario',
    'changed canonical reward',
  ]) {
    test('inconsistent state: $variant fails without new mutations', () async {
      final player = await createPeriod();
      final profileId = player.profileId;
      final periodId = player.period.id!;
      if (variant != 'progress without reward' &&
          variant != 'checkpoint without progress or reward') {
        await seedReward(
          profileId,
          periodId,
          amount: variant == 'changed canonical reward' ? 51 : 50,
        );
      }
      if (variant != 'reward without progress' &&
          variant != 'checkpoint without progress or reward') {
        await seedProgress(
          profileId,
          claimed: variant != 'unclaimed reward',
          answerId: variant == 'wrong stored answer' ? _wrong : _correct,
          status: variant == 'malformed status' ? 'unknown' : 'completed',
          rawScenario: variant == 'malformed scenario' ? 'not-json' : null,
        );
      }
      if (variant == 'checkpoint without progress or reward' ||
          (variant != 'reward without progress' &&
              variant != 'progress without reward' &&
              variant != 'progress without checkpoint')) {
        await seedResolved(profileId, periodId);
      }
      final db = await database.database;
      final beforeState = (await games.getGameState(profileId))!.toMap();
      final beforePeriod = (await games.getPeriodById(
        profileId,
        periodId,
      ))!.toMap();
      final beforeTransactions = await db.query('transactions');
      final beforeProgress = await db.query('task_progress');

      await expectLater(submit(player), throwsA(isA<TaskIntegrityException>()));
      expect((await games.getGameState(profileId))?.toMap(), beforeState);
      expect(
        (await games.getPeriodById(profileId, periodId))?.toMap(),
        beforePeriod,
      );
      expect(await db.query('transactions'), beforeTransactions);
      expect(await db.query('task_progress'), beforeProgress);
    });
  }

  test('changed meaning cannot reuse a persisted task ID', () async {
    final player = await createPeriod();
    await submit(player);
    final original = testFinancialTask(1);
    final changedReward = FinancialTask(
      id: original.id,
      title: original.title,
      topic: original.topic,
      description: original.description,
      type: original.type,
      reward: 75,
      period: original.period,
      choiceScenario: original.choiceScenario,
    );
    final changedAnswer = FinancialTask(
      id: original.id,
      title: original.title,
      topic: original.topic,
      description: original.description,
      type: original.type,
      reward: original.reward,
      period: original.period,
      choiceScenario: ChoiceTaskScenario(
        prompt: original.choiceScenario.prompt,
        options: original.choiceScenario.options,
        correctOptionId: _wrong,
        explanation: original.choiceScenario.explanation,
      ),
    );
    for (final changed in [changedReward, changedAnswer]) {
      final changedService = TaskService(
        games,
        SqliteTaskCompletionPort(database),
        TestContentRepository(
          testPeriodDefinitions(count: 1),
          tasks: [changed],
        ),
      );
      await expectLater(
        changedService.submitAnswer(
          profileId: player.profileId,
          periodId: player.period.id!,
          taskId: _taskId,
          answerId: _correct,
        ),
        throwsA(isA<TaskIntegrityException>()),
      );
    }
    expect((await games.getGameState(player.profileId))?.walletBalance, 550);
  });

  test('period ownership, task period and checkpoint are validated', () async {
    final normal = await createPeriod();
    final demo = await createPeriod(type: ProfileType.demo);
    await expectLater(
      tasks.submitAnswer(
        profileId: normal.profileId,
        periodId: 9999,
        taskId: _taskId,
        answerId: _correct,
      ),
      throwsStateError,
    );
    await expectLater(
      tasks.submitAnswer(
        profileId: demo.profileId,
        periodId: normal.period.id!,
        taskId: _taskId,
        answerId: _correct,
      ),
      throwsStateError,
    );
    await expectLater(
      TaskService(
        games,
        SqliteTaskCompletionPort(database),
        TestContentRepository(
          testPeriodDefinitions(count: 1),
          tasks: [testFinancialTask(2)],
        ),
      ).submitAnswer(
        profileId: normal.profileId,
        periodId: normal.period.id!,
        taskId: 'task_period_2',
        answerId: _correct,
      ),
      throwsStateError,
    );
    expect(await games.getTaskProgress(demo.profileId, _taskId), isNull);
  });

  test('a period without financial_task cannot accept an answer', () async {
    final player = await createPeriod(checkpoints: const ['mandatory_need']);
    await expectLater(submit(player), throwsStateError);
    expect((await games.getGameState(player.profileId))?.walletBalance, 500);
  });

  for (final status in [
    GamePeriodStatus.planning,
    GamePeriodStatus.readyToFinish,
    GamePeriodStatus.completed,
  ]) {
    test('new completion is rejected in ${status.name}', () async {
      final player = await createPeriod(
        active: status != GamePeriodStatus.planning,
      );
      if (status != GamePeriodStatus.planning) {
        await (await database.database).update(
          'game_periods',
          {'status': status.name},
          where: 'id = ?',
          whereArgs: [player.period.id!],
        );
      }
      await expectLater(submit(player), throwsStateError);
      expect((await games.getGameState(player.profileId))?.walletBalance, 500);
      expect(await games.getTaskProgress(player.profileId, _taskId), isNull);
      expect(await games.getTransactions(player.profileId), hasLength(1));
    });
  }

  test('NORMAL and DEMO task completion stay isolated', () async {
    final normal = await createPeriod();
    final demo = await createPeriod(type: ProfileType.demo);
    await submit(normal);
    expect((await games.getGameState(normal.profileId))?.walletBalance, 550);
    expect((await games.getGameState(demo.profileId))?.walletBalance, 500);
    expect(await games.getTaskProgress(demo.profileId, _taskId), isNull);
    expect(
      (await games.getPeriodById(
        demo.profileId,
        demo.period.id!,
      ))!.resolvedCheckpoints,
      isEmpty,
    );
    await submit(demo);
    expect((await games.getGameState(normal.profileId))?.walletBalance, 550);
    expect((await games.getGameState(demo.profileId))?.walletBalance, 550);
    expect(
      (await games.getTransactions(normal.profileId))
          .where((entry) => entry.type == GameTransactionType.taskReward),
      hasLength(1),
    );
    expect(
      (await games.getTransactions(demo.profileId))
          .where((entry) => entry.type == GameTransactionType.taskReward),
      hasLength(1),
    );
  });

  test('invalid canonical task list is rejected before mutations', () async {
    final player = await createPeriod();
    final duplicateContent = TestContentRepository(
      testPeriodDefinitions(count: 1),
      tasks: [testFinancialTask(1), testFinancialTask(1)],
    );
    await expectLater(
      TaskService(
        games,
        SqliteTaskCompletionPort(database),
        duplicateContent,
      ).submitAnswer(
        profileId: player.profileId,
        periodId: player.period.id!,
        taskId: _taskId,
        answerId: _correct,
      ),
      throwsFormatException,
    );
    expect((await games.getGameState(player.profileId))?.walletBalance, 500);
    expect(await games.getTaskProgress(player.profileId, _taskId), isNull);
    expect(await games.getTransactions(player.profileId), hasLength(1));
  });

  test(
    'task progress insert failure rolls back wallet and checkpoint',
    () async {
      final player = await createPeriod();
      final db = await database.database;
      await db.execute('''
      CREATE TRIGGER fail_task_progress BEFORE INSERT ON task_progress
      BEGIN SELECT RAISE(ABORT, 'test failure'); END
    ''');
      final stateBefore = (await games.getGameState(player.profileId))!.toMap();
      final periodBefore = (await games.getPeriodById(
        player.profileId,
        player.period.id!,
      ))!.toMap();
      final transactionsBefore = await db.query('transactions');
      await expectLater(submit(player), throwsA(isA<Exception>()));
      expect(
        (await games.getGameState(player.profileId))?.toMap(),
        stateBefore,
      );
      expect(
        (await games.getPeriodById(
          player.profileId,
          player.period.id!,
        ))?.toMap(),
        periodBefore,
      );
      expect(await db.query('transactions'), transactionsBefore);
      expect(await db.query('task_progress'), isEmpty);
    },
  );

  test('successful task replay survives SQLite reopen', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('finny_task_');
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
    final profile = await firstProfiles.create(
      Profile(
        gameName: 'Persistent',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await firstGames.ensureInitialState(profile.id!);
    final period = await firstGames.startPeriod(
      profileId: profile.id!,
      definitionId: 'period_1',
      periodNumber: 1,
      baseIncome: 500,
      requiredCheckpoints: const ['financial_task'],
      createdAt: DateTime.utc(2026, 1, 2),
    );
    await firstGames.confirmBudget(
      profileId: profile.id!,
      periodId: period.id!,
    );
    final first =
        await TaskService(
              firstGames,
              SqliteTaskCompletionPort(firstDatabase),
              content,
            ).submitAnswer(
              profileId: profile.id!,
              periodId: period.id!,
              taskId: _taskId,
              answerId: _correct,
            )
            as TaskAnswerCompleted;
    expect(first.period.status, GamePeriodStatus.readyToFinish);
    await firstDatabase.close();

    final reopenedDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    addTearDown(reopenedDatabase.close);
    final reopenedGames = SqliteGameRepository(reopenedDatabase);
    final replay =
        await TaskService(
              reopenedGames,
              SqliteTaskCompletionPort(reopenedDatabase),
              content,
            ).submitAnswer(
              profileId: profile.id!,
              periodId: period.id!,
              taskId: _taskId,
              answerId: _correct,
            )
            as TaskAnswerCompleted;
    expect(replay.wasAlreadyCompleted, isTrue);
    expect(replay.rewardAppliedNow, isFalse);
    expect(replay.gameState.walletBalance, 550);
    expect(replay.period.status, GamePeriodStatus.readyToFinish);
    expect(
      await reopenedGames.getTaskProgress(profile.id!, _taskId),
      isNotNull,
    );
    expect(
      (await reopenedGames.getTransactions(profile.id!))
          .where((entry) => entry.type == GameTransactionType.taskReward),
      hasLength(1),
    );
  });

  test('optional task rewards once in active or readyToFinish without resolving checkpoint', () async {
    final required = testFinancialTask(1);
    final optional = FinancialTask(
      id: 'task_bonus_reserve_05',
      title: 'Что делать с остатком?',
      topic: 'reserve',
      description: 'Тестовое дополнительное задание',
      type: 'choice',
      reward: 30,
      period: 1,
      requiredForCheckpoint: false,
      choiceScenario: required.choiceScenario,
    );
    final optionalService = TaskService(
      games,
      SqliteTaskCompletionPort(database),
      TestContentRepository(
        testPeriodDefinitions(count: 1),
        tasks: [required, optional],
      ),
    );
    final player = await createPeriod(
      checkpoints: const ['financial_task', 'savings_decision'],
    );

    await optionalService.submitAnswer(
      profileId: player.profileId,
      periodId: player.period.id!,
      taskId: required.id,
      answerId: _correct,
    );
    var period = await games.resolveCheckpoint(
      profileId: player.profileId,
      periodId: player.period.id!,
      checkpointId: 'savings_decision',
    );
    expect(period.status, GamePeriodStatus.readyToFinish);

    final completed = await optionalService.submitAnswer(
      profileId: player.profileId,
      periodId: player.period.id!,
      taskId: optional.id,
      answerId: _correct,
    ) as TaskAnswerCompleted;
    expect(completed.canonicalReward, 30);
    expect(completed.period.status, GamePeriodStatus.readyToFinish);
    expect(
      completed.period.resolvedCheckpoints,
      containsAll(['financial_task', 'savings_decision']),
    );
    expect(completed.gameState.walletBalance, 580);

    final replay = await optionalService.submitAnswer(
      profileId: player.profileId,
      periodId: player.period.id!,
      taskId: optional.id,
      answerId: _correct,
    ) as TaskAnswerCompleted;
    expect(replay.wasAlreadyCompleted, isTrue);
    expect(replay.rewardAppliedNow, isFalse);
    expect(replay.gameState.walletBalance, 580);
    expect(
      (await games.getTransactions(player.profileId))
          .where((entry) => entry.source == 'task_reward_${optional.id}'),
      hasLength(1),
    );
  });

  test(
    'optional task does not depend on a financial_task checkpoint',
    () async {
      final required = testFinancialTask(1);
      final optional = FinancialTask(
        id: 'task_bonus_without_checkpoint',
        title: 'Дополнительное задание',
        topic: 'reserve',
        description: 'Тестовое дополнительное задание',
        type: 'choice',
        reward: 30,
        period: 1,
        requiredForCheckpoint: false,
        choiceScenario: required.choiceScenario,
      );
      final optionalService = TaskService(
        games,
        SqliteTaskCompletionPort(database),
        TestContentRepository(
          testPeriodDefinitions(count: 1),
          tasks: [optional],
        ),
      );
      final player = await createPeriod(
        checkpoints: const ['savings_decision'],
      );

      final completed = await optionalService.submitAnswer(
        profileId: player.profileId,
        periodId: player.period.id!,
        taskId: optional.id,
        answerId: _correct,
      ) as TaskAnswerCompleted;

      expect(completed.canonicalReward, 30);
      expect(completed.gameState.walletBalance, 530);
      expect(completed.period.resolvedCheckpoints, isEmpty);
      expect(completed.period.status, GamePeriodStatus.active);
      expect(
        (await games.getTransactions(player.profileId))
            .where((entry) => entry.source == 'task_reward_${optional.id}'),
        hasLength(1),
      );
    },
  );
}
