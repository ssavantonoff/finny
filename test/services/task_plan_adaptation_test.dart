import 'dart:convert';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

void main() {
  late AppDatabase database;
  late SqliteGameRepository games;
  late SqliteProfileRepository profiles;
  late TaskService tasks;
  late int profileId;
  late GamePeriod period;

  setUp(() async {
    database = createTestDatabase();
    games = SqliteGameRepository(database);
    profiles = SqliteProfileRepository(database);
    final content = TestContentRepository(
      testPeriodDefinitions(count: 3),
      tasks: [testPlanAdaptationTask()],
    );
    tasks = TaskService(games, SqliteTaskCompletionPort(database), content);
    final profile = await profiles.create(
      Profile(
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026),
      ),
    );
    profileId = profile.id!;
    await games.ensureInitialState(profileId);
    period = await games.startPeriod(
      profileId: profileId,
      definitionId: 'period_3',
      periodNumber: 3,
      baseIncome: 500,
      requiredCheckpoints: const ['financial_task'],
      createdAt: DateTime.utc(2026),
    );
    period = await confirmBudgetForTest(
      games,
      profileId: profileId,
      periodId: period.id!,
    );
  });

  tearDown(() => database.close());

  const correct = {
    'food': 'keep',
    'shampoo': 'keep',
    'toy': 'later',
    'savings': 'keep',
  };

  test('canonical completion is rewarded and persisted once', () async {
    final wrong = await tasks.submitPlanAdaptation(
      profileId: profileId,
      periodId: period.id!,
      taskId: 'task_changed_plan_03',
      assignments: const {
        'food': 'keep',
        'shampoo': 'keep',
        'toy': 'keep',
        'savings': 'keep',
      },
    );
    expect(wrong, isA<TaskPlanAdaptationIncorrect>());
    expect((wrong as TaskPlanAdaptationIncorrect).overBudgetBy, 80);
    expect((await games.getGameState(profileId))?.walletBalance, 500);
    expect((await games.getPeriodById(profileId, period.id!))?.dayProgress, 10);

    final completed = await tasks.submitPlanAdaptation(
      profileId: profileId,
      periodId: period.id!,
      taskId: 'task_changed_plan_03',
      assignments: correct,
    ) as TaskAnswerCompleted;
    expect(completed.rewardAppliedNow, isTrue);
    expect(completed.gameState.walletBalance, 550);
    expect(completed.period.dayProgress, 40);
    expect(completed.period.resolvedCheckpoints, contains('financial_task'));
    expect(
      (await games.getTaskProgress(
        profileId,
        'task_changed_plan_03',
      ))?.scenarioState,
      {'type': 'plan_adaptation', 'assignments': correct},
    );

    final replay = await tasks.submitPlanAdaptation(
      profileId: profileId,
      periodId: period.id!,
      taskId: 'task_changed_plan_03',
      assignments: const {
        'food': 'later',
        'shampoo': 'later',
        'toy': 'keep',
        'savings': 'later',
      },
    ) as TaskAnswerCompleted;
    expect(replay.wasAlreadyCompleted, isTrue);
    expect(replay.rewardAppliedNow, isFalse);
    expect((await games.getGameState(profileId))?.walletBalance, 550);
    expect(
      (await games.getTransactions(profileId)).where(
        (transaction) => transaction.type == GameTransactionType.taskReward,
      ),
      hasLength(1),
    );
  });

  test(
    'legacy Day 3 answer is accepted only as existing completion proof',
    () async {
      final db = await database.database;
      await db.insert('transactions', {
        'profile_id': profileId,
        'period_id': period.id,
        'type': GameTransactionType.taskReward,
        'amount': 50,
        'source': 'task_reward_task_changed_plan_03',
        'description': 'Legacy task reward',
        'created_at': DateTime.utc(2026).toIso8601String(),
        'deduplication_key': 'task_reward_${period.id}_task_changed_plan_03',
      });
      await db.insert('task_progress', {
        'profile_id': profileId,
        'task_id': 'task_changed_plan_03',
        'status': 'completed',
        'reward_claimed': 1,
        'scenario_state': jsonEncode({'answerId': 'adapt'}),
        'updated_at': DateTime.utc(2026).toIso8601String(),
      });
      await db.update(
        'game_periods',
        {
          'resolved_checkpoints': jsonEncode(['financial_task']),
          'status': GamePeriodStatus.active.name,
        },
        where: 'id = ?',
        whereArgs: [period.id],
      );

      final result = await tasks.submitPlanAdaptation(
        profileId: profileId,
        periodId: period.id!,
        taskId: 'task_changed_plan_03',
        assignments: correct,
      ) as TaskAnswerCompleted;
      expect(result.wasAlreadyCompleted, isTrue);
      expect((await games.getGameState(profileId))?.walletBalance, 500);
      expect(
        (await games.getPeriodById(profileId, period.id!))?.dayProgress,
        10,
      );
    },
  );

  test('wrong but affordable assignments do not mutate real finance', () async {
    final before = await games.getGameState(profileId);
    for (final assignments in [
      const {
        'food': 'later',
        'shampoo': 'keep',
        'toy': 'later',
        'savings': 'keep',
      },
      const {
        'food': 'keep',
        'shampoo': 'later',
        'toy': 'later',
        'savings': 'keep',
      },
      const {
        'food': 'keep',
        'shampoo': 'keep',
        'toy': 'later',
        'savings': 'later',
      },
    ]) {
      final result = await tasks.submitPlanAdaptation(
        profileId: profileId,
        periodId: period.id!,
        taskId: 'task_changed_plan_03',
        assignments: assignments,
      );
      expect(result, isA<TaskPlanAdaptationIncorrect>());
    }
    expect(
      (await games.getGameState(profileId))?.walletBalance,
      before?.walletBalance,
    );
    final unchanged = await games.getPeriodById(profileId, period.id!);
    expect(unchanged?.actualNeed, 0);
    expect(unchanged?.dayProgress, 10);
    expect(unchanged?.resolvedCheckpoints, isNot(contains('financial_task')));
    expect(
      await games.getTaskProgress(profileId, 'task_changed_plan_03'),
      isNull,
    );
  });

  test('unknown, missing and invalid assignments are rejected', () async {
    for (final assignments in [
      const {'food': 'keep', 'shampoo': 'keep', 'toy': 'later'},
      const {
        'food': 'keep',
        'shampoo': 'keep',
        'toy': 'later',
        'savings': 'keep',
        'extra': 'keep',
      },
      const {
        'food': 'keep',
        'shampoo': 'keep',
        'toy': 'later',
        'savings': 'unknown',
      },
    ]) {
      await expectLater(
        tasks.submitPlanAdaptation(
          profileId: profileId,
          periodId: period.id!,
          taskId: 'task_changed_plan_03',
          assignments: assignments,
        ),
        throwsArgumentError,
      );
    }
    expect((await games.getGameState(profileId))?.walletBalance, 500);
  });
}
