import 'package:finny/models/pet.dart';
import 'package:finny/models/day_lifecycle.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/budget_service.dart';
import 'package:finny/services/day_lifecycle_service.dart';
import 'package:finny/services/period_service.dart';
import 'package:finny/services/item_use_service.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:finny/services/savings_service.dart';
import 'package:finny/services/special_purchase_service.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'canonical campaign completes Day 1 through Day 5 and reaches Stage 3',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final profiles = SqliteProfileRepository(database);
      final games = SqliteGameRepository(database);
      final content = AssetContentRepository();
      final periods = PeriodService(games, content);
      final budget = BudgetService(games);
      final tasks = TaskService(
        games,
        SqliteTaskCompletionPort(database),
        content,
      );
      final savings = SavingsService(games, content);
      final special = SpecialPurchaseService(
        SqliteSpecialPurchasePort(database),
        content,
      );
      final lifecycle = DayLifecycleService(
        SqliteDayLifecyclePort(database),
        content,
      );
      final purchases = PurchaseService(SqlitePurchasePort(database), content);
      final itemUse = ItemUseService(SqlitePetActionPort(database), content);

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
          satiety: 100,
          care: 100,
          mood: 100,
        ),
      );
      final goal = (await content.loadGoals()).first;
      await savings.selectGoal(profileId: profileId, goalId: goal.id);

      const answers = {
        2: ('task_priority_02', 'food'),
        3: ('task_changed_plan_03', 'adapt'),
        4: ('task_discount_04', 'consider'),
        5: ('task_final_choice_05', 'balanced'),
      };

      for (var day = 1; day <= 5; day++) {
        var period = (await periods.startNextPeriod(profileId: profileId))!;
        expect(period.periodNumber, day);
        await budget.saveDraft(
          profileId: profileId,
          periodId: period.id!,
          allocation: const BudgetAllocation(need: 0, want: 0, savings: 0),
        );
        period = await budget.confirmPlan(
          profileId: profileId,
          periodId: period.id!,
        );

        if (day == 3) {
          await special.purchaseStory(
            profileId: profileId,
            periodId: period.id!,
            storyPurchaseId: 'day3_bowl_replacement',
            operationId: 'campaign-day3-bowl',
          );
        }

        final TaskSubmissionResult taskResult;
        if (day == 1) {
          taskResult = await tasks.submitCategorization(
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
        } else {
          final answer = answers[day]!;
          taskResult = await tasks.submitAnswer(
            profileId: profileId,
            periodId: period.id!,
            taskId: answer.$1,
            answerId: answer.$2,
          );
        }
        expect(taskResult, isA<TaskAnswerCompleted>());

        if (day == 4) {
          await special.buyPromotion(
            profileId: profileId,
            periodId: period.id!,
            promotionId: 'day4_treat_discount',
            operationId: 'campaign-day4-buy',
          );
        }

        period = await savings.skipToday(
          profileId: profileId,
          periodId: period.id!,
        );
        expect(period.status.name, 'readyToFinish');

        if (day == 5) {
          final bonus = await tasks.submitAnswer(
            profileId: profileId,
            periodId: period.id!,
            taskId: 'task_bonus_reserve_05',
            answerId: 'keep',
          );
          expect(bonus, isA<TaskAnswerCompleted>());
        }

        for (final itemId in ['food_feed', 'care_shampoo']) {
          await purchases.purchase(
            profileId: profileId,
            periodId: period.id!,
            itemId: itemId,
            operationId: 'campaign-day$day-buy-$itemId',
          );
          await itemUse.useItem(
            profileId: profileId,
            periodId: period.id!,
            itemId: itemId,
            operationId: 'campaign-day$day-use-$itemId',
          );
        }
        await purchases.purchase(
          profileId: profileId,
          periodId: period.id!,
          itemId: 'food_feed',
          operationId: 'campaign-day$day-buy-food-feed-second',
        );
        await itemUse.useItem(
          profileId: profileId,
          periodId: period.id!,
          itemId: 'food_feed',
          operationId: 'campaign-day$day-use-food-feed-second',
        );
        if (day == 1) {
          await purchases.purchase(
            profileId: profileId,
            periodId: period.id!,
            itemId: 'toy_ball',
            operationId: 'campaign-buy-toy-ball',
          );
        }
        await itemUse.useItem(
          profileId: profileId,
          periodId: period.id!,
          itemId: 'toy_ball',
          operationId: 'campaign-day$day-use-toy-ball',
        );
        await itemUse.performFreeInteraction(
          profileId: profileId,
          periodId: period.id!,
          interaction: FreePetInteraction.pet,
          operationId: 'campaign-day$day-pet',
        );
        if (day >= 3) {
          await purchases.purchase(
            profileId: profileId,
            periodId: period.id!,
            itemId: 'food_treat',
            operationId: 'campaign-day$day-buy-food-treat',
          );
          await itemUse.useItem(
            profileId: profileId,
            periodId: period.id!,
            itemId: 'food_treat',
            operationId: 'campaign-day$day-use-food-treat',
          );
        }
        await itemUse.useItem(
          profileId: profileId,
          periodId: period.id!,
          itemId: 'care_toothbrush',
          operationId: 'campaign-day$day-brush-evening',
          slot: PetActionSlot.evening,
        );
        await purchases.purchase(
          profileId: profileId,
          periodId: period.id!,
          itemId: 'care_shampoo',
          operationId: 'campaign-day$day-buy-care-shampoo-second',
        );
        await itemUse.useItem(
          profileId: profileId,
          periodId: period.id!,
          itemId: 'care_shampoo',
          operationId: 'campaign-day$day-use-care-shampoo-second',
        );

        final bedtime = await lifecycle.evaluateBedtime(
          profileId: profileId,
          periodId: period.id!,
        );
        expect(
          bedtime.type,
          BedtimeDecisionType.ready,
          reason: 'Day $day must remain completable',
        );

        final result = await lifecycle.sleep(
          profileId: profileId,
          periodId: period.id!,
          allowFallback: false,
        );
        expect(result.period.status.name, 'completed');
      }

      final history = await games.getPeriods(profileId);
      final state = await games.getGameState(profileId);
      final pet = await games.getPet(profileId);
      final transactions = await games.getTransactions(profileId);
      final db = await database.database;
      final proofs = await db.query('period_special_actions');

      expect(history, hasLength(5));
      expect(
        history.every((period) => period.status.name == 'completed'),
        isTrue,
      );
      expect(await games.getCurrentPeriod(profileId), isNull);
      expect(state?.currentPeriod, 5);
      expect(state?.walletBalance, greaterThanOrEqualTo(0));
      expect(state?.savedAmount, 0);
      expect(pet?.developmentStage, 3);
      expect(pet?.growthPoints, 0);
      expect(
        transactions.where(
          (item) => item.type == GameTransactionType.taskReward,
        ),
        hasLength(6),
      );
      expect(proofs, hasLength(2));
      expect(
        history.every(
          (period) => period.requiredCheckpoints.every(
            period.resolvedCheckpoints.contains,
          ),
        ),
        isTrue,
      );
    },
  );
}
