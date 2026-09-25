import 'package:finny/models/pet.dart';
import 'package:finny/features/minigames/ball/ball_session.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/day_lifecycle.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/budget_service.dart';
import 'package:finny/services/ball_reward_service.dart';
import 'package:finny/repositories/campaign_lifecycle_repository.dart';
import 'package:finny/repositories/free_play_repository.dart';
import 'package:finny/services/day_lifecycle_service.dart';
import 'package:finny/services/period_service.dart';
import 'package:finny/services/item_use_service.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:finny/services/savings_service.dart';
import 'package:finny/services/special_purchase_service.dart';
import 'package:finny/services/story_event_service.dart';
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
      final storyEvents = StoryEventService(
        SqliteStoryEventPort(database),
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
      final ballReward = BallRewardService(
        content,
        games,
        CampaignLifecycleRepository(database),
        SqliteBallRewardPort(database),
        FreePlayRepository(database),
        () => profileId,
      );
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

      for (var day = 1; day <= 5; day++) {
        var period = (await periods.startNextPeriod(profileId: profileId))!;
        expect(period.periodNumber, day);
        await budget.saveDraft(
          profileId: profileId,
          periodId: period.id!,
          allocation: const BudgetAllocation(need: 10, want: 10, savings: 10),
        );
        period = await budget.confirmPlan(
          profileId: profileId,
          periodId: period.id!,
        );

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
        } else if (day == 2) {
          taskResult = await tasks.submitBudgetPriority(
            profileId: profileId,
            periodId: period.id!,
            taskId: 'task_priority_02',
            assignments: const {
              'food': 'buy_now',
              'shampoo': 'buy_now',
              'bow': 'later',
            },
          );
        } else if (day == 3) {
          taskResult = await tasks.submitPlanAdaptation(
            profileId: profileId,
            periodId: period.id!,
            taskId: 'task_changed_plan_03',
            assignments: const {
              'food': 'keep',
              'shampoo': 'keep',
              'toy': 'later',
              'savings': 'keep',
            },
          );
          final bowl = await storyEvents.armOrLoadDay3Bowl(
            profileId: profileId,
          );
          expect(bowl?.status.name, 'armed');
        } else if (day == 4) {
          taskResult = await tasks.submitShoppingTrip(
            profileId: profileId,
            periodId: period.id!,
            taskId: 'task_shopping_trip_04',
            selections: const {
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
            },
          );
        } else {
          final first = await tasks.submitIndependentBudget(
            profileId: profileId,
            periodId: period.id!,
            taskId: 'task_independent_budget_05',
            selectedItemIds: {'food_feed', 'care_comb'},
            savingsAmount: 50,
          ) as TaskAnswerCompleted;
          expect(
            first.period.resolvedCheckpoints,
            isNot(contains('financial_task')),
          );
          taskResult = await tasks.submitPlanRepair(
            profileId: profileId,
            periodId: period.id!,
            taskId: 'task_plan_repair_05',
            nowItemIds: {'food_feed', 'care_comb', 'scenario_waterer_05'},
            savingsAmount: 70,
          );
        }
        expect(taskResult, isA<TaskAnswerCompleted>());

        if (day == 4) {
          await special.purchasePromotion(
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
        if (day != 3) {
          expect(period.status.name, 'readyToFinish');
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
        final ballSession = BallSession(
          seed: day,
          sessionId: 'campaign-day$day-ball',
        )..start();
        ballSession.advance(const Duration(seconds: 30));
        await ballReward.completeSession(
          access: await ballReward.checkAccess(profileId: profileId),
          session: ballSession,
        );
        await itemUse.performFreeInteraction(
          profileId: profileId,
          periodId: period.id!,
          interaction: FreePetInteraction.pet,
          operationId: 'campaign-day$day-pet',
        );
        if (day == 3) {
          final bowl = await storyEvents.loadDay3Bowl(profileId: profileId);
          expect(bowl?.isDue, isTrue);
          await storyEvents.purchaseDay3Bowl(
            profileId: profileId,
            currentPeriodId: period.id!,
            operationId: 'campaign-day3-bowl',
            useSavings: false,
          );
          final resolvedPeriod = await games.getPeriodById(
            profileId,
            period.id!,
          );
          expect(resolvedPeriod?.status.name, 'readyToFinish');
        }
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
      final storyEventRows = await db.query('campaign_story_events');

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
      expect(proofs, hasLength(1));
      expect(storyEventRows, hasLength(1));
      expect(storyEventRows.single['status'], 'purchased');
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
