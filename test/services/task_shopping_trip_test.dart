import 'dart:convert';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

const cheap = <String, ShoppingTripSelection>{
  'water': ShoppingTripSelection(
    priceScenarioId: 'small_better',
    smallQuantity: 2,
    largeQuantity: 0,
  ),
  'soap': ShoppingTripSelection(
    priceScenarioId: 'large_better',
    smallQuantity: 0,
    largeQuantity: 1,
  ),
  'cookies': ShoppingTripSelection(
    priceScenarioId: 'large_better',
    smallQuantity: 0,
    largeQuantity: 1,
  ),
};

ShoppingTripSelection selection(String scenario, int small, int large) =>
    ShoppingTripSelection(
      priceScenarioId: scenario,
      smallQuantity: small,
      largeQuantity: large,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late SqliteGameRepository games;
  late TaskService tasks;
  late FinancialTask canonical;
  late int profileId;
  late GamePeriod period;

  setUp(() async {
    database = createTestDatabase();
    games = SqliteGameRepository(database);
    canonical = (await AssetContentRepository().loadTasks()).singleWhere(
      (task) => task.id == 'task_shopping_trip_04',
    );
    tasks = TaskService(
      games,
      SqliteTaskCompletionPort(database),
      TestContentRepository(
        testPeriodDefinitions(count: 5),
        tasks: [canonical],
      ),
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
    period = await games.startPeriod(
      profileId: profileId,
      definitionId: 'period_4_discount',
      periodNumber: 4,
      baseIncome: 500,
      requiredCheckpoints: const ['financial_task', 'savings_decision'],
      createdAt: DateTime.utc(2026),
    );
    period = await confirmBudgetForTest(
      games,
      profileId: profileId,
      periodId: period.id!,
    );
  });
  tearDown(() => database.close());

  Future<TaskSubmissionResult> submit(
    Map<String, ShoppingTripSelection> basket,
  ) => tasks.submitShoppingTrip(
    profileId: profileId,
    periodId: period.id!,
    taskId: canonical.id,
    selections: basket,
  );

  test('180 basket succeeds once with reward, time and checkpoint; training is isolated', () async {
    final before = (await games.getPeriodById(profileId, period.id!))!;
    final result = await submit(cheap) as TaskAnswerCompleted;
    expect(result.rewardAppliedNow, isTrue);
    expect(result.period.dayProgress, before.dayProgress + 30);
    expect(result.period.resolvedCheckpoints, ['financial_task']);
    expect(result.gameState.walletBalance, 550);
    expect(result.period.actualNeed, 0);
    expect(result.period.actualWant, 0);
    expect(result.period.actualSavings, 0);
    expect(
      (
        result.period.plannedNeed,
        result.period.plannedWant,
        result.period.plannedSavings,
      ),
      (before.plannedNeed, before.plannedWant, before.plannedSavings),
    );
    for (final id in ['water', 'soap', 'cookies']) {
      expect(await games.getInventoryQuantity(profileId, id), 0);
    }
    expect(
      (await games.getTaskProgress(profileId, canonical.id))!.scenarioState,
      {
        'type': 'shopping_trip',
        'selections': {for (final e in cheap.entries) e.key: e.value.toJson()},
      },
    );
    final replay = await submit({
      'water': selection('small_better', 0, 1),
      'soap': cheap['soap']!,
      'cookies': cheap['cookies']!,
    }) as TaskAnswerCompleted;
    expect(replay.wasAlreadyCompleted, isTrue);
    expect(replay.rewardAppliedNow, isFalse);
    expect(
      (await games.getPeriodById(profileId, period.id!))!.dayProgress,
      before.dayProgress + 30,
    );
    expect(
      (await games.getTransactions(profileId))
          .where((t) => t.type == GameTransactionType.taskReward),
      hasLength(1),
    );
  });

  test('190 baskets are equally successful with different scenarios and quantities', () async {
    final oneExpensive = {...cheap, 'water': selection('small_better', 0, 1)};
    expect(
      canonical.shoppingTripScenario.evaluate(oneExpensive).totalCost,
      190,
    );
    expect(await submit(oneExpensive), isA<TaskAnswerCompleted>());
  });

  test('a different 190 basket is a valid completed-state proof', () async {
    final alternate = {
      'water': selection('large_better', 0, 1),
      'soap': selection('small_better', 2, 0),
      'cookies': selection('small_better', 0, 1),
    };
    expect(canonical.shoppingTripScenario.evaluate(alternate).totalCost, 190);
    expect(await submit(alternate), isA<TaskAnswerCompleted>());
    expect(
      (await submit(cheap) as TaskAnswerCompleted).wasAlreadyCompleted,
      isTrue,
    );
  });

  test('200 and 210 report exact overage without mutation', () async {
    final twoExpensive = {
      'water': selection('small_better', 0, 1),
      'soap': selection('large_better', 2, 0),
      'cookies': cheap['cookies']!,
    };
    final threeExpensive = {
      ...twoExpensive,
      'cookies': selection('large_better', 2, 0),
    };
    final before = (await games.getPeriodById(profileId, period.id!))!;
    for (final (basket, overage, total) in [
      (twoExpensive, 10, 200),
      (threeExpensive, 20, 210),
    ]) {
      final result = await submit(basket) as TaskShoppingTripIncorrect;
      expect(result.overBudgetBy, overage);
      expect(result.totalCost, total);
      expect(result.insufficientItemIds, isEmpty);
    }
    expect((await games.getGameState(profileId))!.walletBalance, 500);
    expect(
      (await games.getPeriodById(profileId, period.id!))!.dayProgress,
      before.dayProgress,
    );
    expect(await games.getTaskProgress(profileId, canonical.id), isNull);
  });

  test('each shortage, combined shortage and overage, and empty basket report facts', () async {
    for (final id in ['water', 'soap', 'cookies']) {
      final basket = {
        ...cheap,
        id: selection(cheap[id]!.priceScenarioId, 0, 0),
      };
      final result = await submit(basket) as TaskShoppingTripIncorrect;
      expect(result.insufficientItemIds, {id});
      expect(result.purchasedAmounts[id], 0);
    }
    final combined = {
      'water': selection('small_better', 1, 0),
      'soap': selection('large_better', 2, 1),
      'cookies': cheap['cookies']!,
    };
    final wrong = await submit(combined) as TaskShoppingTripIncorrect;
    expect(wrong.insufficientItemIds, {'water'});
    expect(wrong.purchasedAmounts['water'], 500);
    expect(wrong.overBudgetBy, 35);
    final empty = {
      for (final e in cheap.entries)
        e.key: selection(e.value.priceScenarioId, 0, 0),
    };
    final emptyResult = await submit(empty) as TaskShoppingTripIncorrect;
    expect(emptyResult.insufficientItemIds, {'water', 'soap', 'cookies'});
    expect(emptyResult.totalCost, 0);
  });

  test(
    'invalid item IDs, scenarios and quantity bounds are rejected',
    () async {
      final invalid = <Map<String, ShoppingTripSelection>>[
        {...cheap}..remove('water'),
        {...cheap, 'extra': selection('small_better', 0, 0)},
        {...cheap, 'water': selection('unknown', 0, 1)},
        {...cheap, 'water': selection('small_better', -1, 0)},
        {...cheap, 'water': selection('small_better', 0, -1)},
        {...cheap, 'water': selection('small_better', 3, 0)},
        {...cheap, 'water': selection('small_better', 0, 2)},
      ];
      for (final basket in invalid) {
        await expectLater(submit(basket), throwsArgumentError);
      }
      expect(await games.getTaskProgress(profileId, canonical.id), isNull);
    },
  );

  test('wrong period and altered canonical content are rejected', () async {
    await expectLater(
      tasks.submitShoppingTrip(
        profileId: profileId,
        periodId: period.id!,
        taskId: 'task_final_choice_05',
        selections: cheap,
      ),
      throwsStateError,
    );
    final altered = FinancialTask(
      id: canonical.id,
      title: canonical.title,
      topic: canonical.topic,
      description: canonical.description,
      type: canonical.type,
      reward: canonical.reward,
      period: canonical.period,
      shoppingTripScenario: ShoppingTripTaskScenario(
        prompt: canonical.shoppingTripScenario.prompt,
        budget: 191,
        items: canonical.shoppingTripScenario.items,
        successExplanation: canonical.shoppingTripScenario.successExplanation,
      ),
    );
    final alteredService = TaskService(
      games,
      SqliteTaskCompletionPort(database),
      TestContentRepository(testPeriodDefinitions(count: 5), tasks: [altered]),
    );
    await expectLater(
      alteredService.submitShoppingTrip(
        profileId: profileId,
        periodId: period.id!,
        taskId: canonical.id,
        selections: cheap,
      ),
      throwsStateError,
    );
  });

  test('corrupt persisted successful basket fails replay integrity', () async {
    await submit(cheap);
    await (await database.database).update(
      'task_progress',
      {
        'scenario_state': jsonEncode({
          'type': 'shopping_trip',
          'selections': {
            for (final e in cheap.entries) e.key: e.value.toJson(),
            'water': selection('small_better', 0, 0).toJson(),
          },
        }),
      },
      where: 'profile_id = ? AND task_id = ?',
      whereArgs: [profileId, canonical.id],
    );
    await expectLater(submit(cheap), throwsA(isA<TaskIntegrityException>()));
  });
}
