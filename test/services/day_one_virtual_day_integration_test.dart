import 'package:finny/models/day_lifecycle.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/pet_state_rules.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/budget_service.dart';
import 'package:finny/services/day_lifecycle_service.dart';
import 'package:finny/services/item_use_service.dart';
import 'package:finny/services/period_service.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:finny/services/savings_service.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('canonical Day 1 reaches bedtime through action-driven time', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final profiles = SqliteProfileRepository(database);
    final games = SqliteGameRepository(database);
    final content = AssetContentRepository();
    final periods = PeriodService(games, content);
    final budget = BudgetService(games);
    final purchases = PurchaseService(SqlitePurchasePort(database), content);
    final itemUse = ItemUseService(SqlitePetActionPort(database), content);
    final tasks = TaskService(
      games,
      SqliteTaskCompletionPort(database),
      content,
    );
    final savings = SavingsService(games, content);
    final lifecycle = DayLifecycleService(
      SqliteDayLifecyclePort(database),
      content,
    );

    final profile = await profiles.create(
      Profile(
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026),
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
        satiety: PetStateRules.dayOneInitialSatiety,
        care: PetStateRules.dayOneInitialCare,
        mood: PetStateRules.dayOneInitialMood,
      ),
    );
    expect(await games.getInventoryQuantity(profileId, 'care_toothbrush'), 1);
    final goal = (await content.loadGoals()).first;
    await savings.selectGoal(profileId: profileId, goalId: goal.id);

    var period = (await periods.startNextPeriod(profileId: profileId))!;
    expect(period.dayProgress, 0);
    period = await confirmPlanForTest(
      budget,
      profileId: profileId,
      periodId: period.id!,
    );
    expect(period.dayProgress, 10);

    for (var index = 1; index <= 2; index++) {
      await purchases.purchase(
        profileId: profileId,
        periodId: period.id!,
        itemId: 'food_feed',
        operationId: 'day1-buy-feed-$index',
      );
    }
    expect((await games.getPeriodById(profileId, period.id!))?.dayProgress, 10);

    await itemUse.useItem(
      profileId: profileId,
      periodId: period.id!,
      itemId: 'food_feed',
      operationId: 'day1-feed-morning',
    );
    expect((await games.getPeriodById(profileId, period.id!))?.dayProgress, 18);
    await itemUse.useItem(
      profileId: profileId,
      periodId: period.id!,
      itemId: 'care_toothbrush',
      operationId: 'day1-brush-morning',
      slot: PetActionSlot.morning,
    );
    expect((await games.getPeriodById(profileId, period.id!))?.dayProgress, 24);

    final task = await tasks.submitCategorization(
      profileId: profileId,
      periodId: period.id!,
      taskId: 'task_need_or_want_01',
      assignments: const {
        'food': 'need',
        'shampoo': 'need',
        'comb': 'need',
        'ball': 'want',
        'bow': 'want',
        'room_decoration': 'want',
      },
    );
    expect(task, isA<TaskAnswerCompleted>());
    expect((task as TaskAnswerCompleted).period.dayProgress, 54);

    period = await savings.skipToday(
      profileId: profileId,
      periodId: period.id!,
    );
    expect(period.dayProgress, 62);
    await itemUse.useItem(
      profileId: profileId,
      periodId: period.id!,
      itemId: 'food_feed',
      operationId: 'day1-feed-evening',
    );
    expect((await games.getPeriodById(profileId, period.id!))?.dayProgress, 70);
    final pet = await itemUse.useItem(
      profileId: profileId,
      periodId: period.id!,
      itemId: 'care_toothbrush',
      operationId: 'day1-brush-evening',
      slot: PetActionSlot.evening,
    );
    period = (await games.getPeriodById(profileId, period.id!))!;
    expect(period.dayProgress, 76);
    expect((pet.satiety, pet.care, pet.mood), (97, 81, 71));
    expect(period.requiredCheckpoints, ['financial_task', 'savings_decision']);
    expect(
      period.requiredCheckpoints.every(period.resolvedCheckpoints.contains),
      isTrue,
    );
    expect(await games.getInventoryQuantity(profileId, 'food_feed'), 0);
    expect(await games.getInventoryQuantity(profileId, 'care_toothbrush'), 1);
    expect((await games.getGameState(profileId))?.walletBalance, 370);

    expect(
      (await lifecycle.evaluateBedtime(
        profileId: profileId,
        periodId: period.id!,
      )).type,
      BedtimeDecisionType.ready,
    );
    final completed = await lifecycle.sleep(
      profileId: profileId,
      periodId: period.id!,
      allowFallback: false,
    );
    expect(completed.period.status.name, 'completed');
    expect(completed.period.endWalletBalance, 370);

    final summary = await periods.getSummary(
      profileId: profileId,
      periodId: period.id!,
    );
    expect(summary.baseIncome, 500);
    expect(summary.additionalIncome, 50);
    expect(summary.totalExpenses, 180);
    expect(summary.factSavings, 0);
    expect(summary.factRemainder, 370);
  });
}
