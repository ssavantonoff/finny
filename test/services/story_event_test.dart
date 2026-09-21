import 'dart:math';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/story_event.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/task_service.dart';
import 'package:finny/services/period_service.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:finny/services/item_use_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

class _ChooseTwoRandom implements Random {
  @override
  int nextInt(int max) => max - 1;

  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.999;
}

void main() {
  late AppDatabase database;
  late SqliteGameRepository games;
  late SqliteProfileRepository profiles;
  late SqliteStoryEventPort events;
  late int profileId;
  late GamePeriod period;

  setUp(() async {
    database = createTestDatabase();
    games = SqliteGameRepository(database);
    profiles = SqliteProfileRepository(database);
    events = SqliteStoryEventPort(database, random: Random(1));
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
      requiredCheckpoints: const [
        'financial_task',
        'savings_decision',
        'changed_circumstance',
      ],
      createdAt: DateTime.utc(2026),
    );
    period = await games.confirmBudget(
      profileId: profileId,
      periodId: period.id!,
    );
  });

  tearDown(() => database.close());

  Future<void> completeTask() async {
    final content = TestContentRepository(
      testPeriodDefinitions(count: 3),
      tasks: [testPlanAdaptationTask()],
    );
    await TaskService(
      games,
      SqliteTaskCompletionPort(database),
      content,
    ).submitPlanAdaptation(
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
  }

  Future<void> addPetProof(String operationId, String actionId) async {
    final db = await database.database;
    await db.insert('pet_action_operations', {
      'profile_id': profileId,
      'operation_id': operationId,
      'period_id': period.id,
      'action_id': actionId,
      'usage_slot': 'default',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  const qualifying = {
    'free:pet',
    'item:food_apple',
    'item:food_treat',
    'item:care_toothbrush',
    'item:toy_ball',
  };
  const qualifyingItems = [
    ShopItem(
      id: 'food_apple',
      name: 'Яблоко',
      category: ShopItemCategory.need,
      price: 40,
      persistent: false,
      effectType: 'satiety',
      effectValue: 20,
      unlockType: 'available',
      displaySection: ShopDisplaySection.food,
      usagePolicy: ItemUsagePolicy.unlimited,
    ),
    ShopItem(
      id: 'care_toothbrush',
      name: 'Щётка',
      category: ShopItemCategory.need,
      price: 80,
      persistent: true,
      effectType: 'care',
      effectValue: 8,
      unlockType: 'available',
      displaySection: ShopDisplaySection.care,
      usagePolicy: ItemUsagePolicy.toothbrush,
    ),
  ];

  test(
    'arms only after task, persists threshold and counts post-arm actions',
    () async {
      expect(
        await events.armDay3Bowl(
          profileId: profileId,
          qualifyingActionIds: qualifying,
          qualifyingItems: qualifyingItems,
        ),
        isNull,
      );
      await completeTask();
      final armed = await events.armDay3Bowl(
        profileId: profileId,
        qualifyingActionIds: qualifying,
        qualifyingItems: qualifyingItems,
      );
      expect(armed?.status, StoryEventStatus.armed);
      expect(armed?.threshold, anyOf(1, 2));
      expect(armed?.qualifyingInteractionCount, 0);
      final replay = await events.armDay3Bowl(
        profileId: profileId,
        qualifyingActionIds: qualifying,
        qualifyingItems: qualifyingItems,
      );
      expect(replay?.threshold, armed?.threshold);

      await addPetProof('pet-1', 'free:pet');
      final afterAction = await events.loadDay3Bowl(
        profileId: profileId,
        qualifyingActionIds: qualifying,
      );
      expect(afterAction?.qualifyingInteractionCount, 1);
      expect(afterAction?.isDue, armed!.threshold == 1);
    },
  );

  test(
    'persists threshold 2 when two post-arm actions are affordable',
    () async {
      events = SqliteStoryEventPort(database, random: _ChooseTwoRandom());
      await completeTask();
      final armed = await events.armDay3Bowl(
        profileId: profileId,
        qualifyingActionIds: qualifying,
        qualifyingItems: qualifyingItems,
      );
      expect(armed?.threshold, 2);
      expect(
        (await events.armDay3Bowl(
          profileId: profileId,
          qualifyingActionIds: qualifying,
          qualifyingItems: qualifyingItems,
        ))?.threshold,
        2,
      );
    },
  );

  test(
    'falls back to one reachable action after pre-task exhaustion',
    () async {
      final petActions = SqlitePetActionPort(database);
      await games.savePet(
        Pet(
          profileId: profileId,
          name: 'Финни',
          colorId: 'purple',
          patternId: 'spots',
          developmentStage: 1,
          growthPoints: 0,
          satiety: 80,
          care: 80,
          mood: 80,
        ),
      );
      await petActions.performFreePetInteraction(
        profileId: profileId,
        periodId: period.id!,
        interaction: FreePetInteraction.pet,
        operationId: 'pre-task-pet',
      );
      await petActions.useItem(
        profileId: profileId,
        periodId: period.id!,
        item: qualifyingItems[1],
        operationId: 'pre-task-brush',
        slot: PetActionSlot.morning,
      );
      final db = await database.database;
      await db.delete(
        'inventory',
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      await db.update(
        'game_states',
        {'wallet_balance': 0},
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );

      await completeTask();
      expect((await games.getGameState(profileId))?.walletBalance, 50);
      events = SqliteStoryEventPort(database, random: _ChooseTwoRandom());
      final armed = await events.armDay3Bowl(
        profileId: profileId,
        qualifyingActionIds: qualifying,
        qualifyingItems: qualifyingItems,
      );
      expect(armed?.threshold, 1);
      expect(armed?.qualifyingInteractionCount, 0);
      expect(
        (await events.armDay3Bowl(
          profileId: profileId,
          qualifyingActionIds: qualifying,
          qualifyingItems: qualifyingItems,
        ))?.threshold,
        1,
      );

      final content = TestContentRepository(
        testPeriodDefinitions(count: 3),
        shopItems: qualifyingItems,
      );
      await PurchaseService(SqlitePurchasePort(database), content).purchase(
        profileId: profileId,
        periodId: period.id!,
        itemId: 'food_apple',
        operationId: 'post-task-apple-purchase',
      );
      await ItemUseService(petActions, content).useItem(
        profileId: profileId,
        periodId: period.id!,
        itemId: 'food_apple',
        operationId: 'post-task-apple-use',
      );
      final due = await events.loadDay3Bowl(
        profileId: profileId,
        qualifyingActionIds: qualifying,
      );
      expect(due?.qualifyingInteractionCount, 1);
      expect(due?.isDue, isTrue);
      await events.postponeDay3Bowl(
        profileId: profileId,
        currentPeriodId: period.id!,
        operationId: 'post-task-postpone',
        qualifyingActionIds: qualifying,
      );
      final completed = await resolveCheckpointForTest(
        database,
        profileId: profileId,
        periodId: period.id!,
        checkpointId: 'savings_decision',
      );
      expect(completed.status, GamePeriodStatus.readyToFinish);
      expect(completed.resolvedCheckpoints, contains('changed_circumstance'));
    },
  );

  test('postpone resolves Day 3 without financial mutation', () async {
    await completeTask();
    await events.armDay3Bowl(
      profileId: profileId,
      qualifyingActionIds: qualifying,
      qualifyingItems: qualifyingItems,
    );
    await addPetProof('pet-1', 'free:pet');
    await addPetProof('pet-2', 'item:food_treat');
    final before = await games.getGameState(profileId);
    final postponed = await events.postponeDay3Bowl(
      profileId: profileId,
      currentPeriodId: period.id!,
      operationId: 'bowl-postpone-1',
      qualifyingActionIds: qualifying,
    );
    expect(postponed.status, StoryEventStatus.postponed);
    expect((await games.getGameState(profileId))?.toMap(), before?.toMap());
    expect(
      (await games.getPeriodById(profileId, period.id!))?.resolvedCheckpoints,
      contains('changed_circumstance'),
    );
    expect(
      (await events.postponeDay3Bowl(
        profileId: profileId,
        currentPeriodId: period.id!,
        operationId: 'bowl-postpone-1',
        qualifyingActionIds: qualifying,
      )).status,
      StoryEventStatus.postponed,
    );
  });

  test(
    'savings purchase withdraws exact deficit atomically and replays',
    () async {
      await completeTask();
      await events.armDay3Bowl(
        profileId: profileId,
        qualifyingActionIds: qualifying,
        qualifyingItems: qualifyingItems,
      );
      await addPetProof('pet-1', 'free:pet');
      await addPetProof('pet-2', 'item:food_treat');
      final db = await database.database;
      await db.update(
        'game_states',
        {'wallet_balance': 80, 'saved_amount': 150},
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      await db.update(
        'game_periods',
        {'actual_savings': 50},
        where: 'id = ?',
        whereArgs: [period.id],
      );

      final purchased = await events.purchaseDay3Bowl(
        profileId: profileId,
        currentPeriodId: period.id!,
        operationId: 'bowl-purchase-1',
        useSavings: true,
        qualifyingActionIds: qualifying,
      );
      expect(purchased.status, StoryEventStatus.purchased);
      final state = await games.getGameState(profileId);
      expect(state?.walletBalance, 0);
      expect(state?.savedAmount, 110);
      final updatedPeriod = await games.getPeriodById(profileId, period.id!);
      expect(updatedPeriod?.actualNeed, 120);
      expect(updatedPeriod?.actualSavings, 50);
      expect(
        (await games.getTransactions(
          profileId,
        )).where((transaction) => transaction.source.startsWith('story_day3')),
        hasLength(1),
      );
      expect(
        (await games.getTransactions(profileId)).where(
          (transaction) => transaction.source == 'day3_bowl_replacement',
        ),
        hasLength(1),
      );
      expect(
        (await events.purchaseDay3Bowl(
          profileId: profileId,
          currentPeriodId: period.id!,
          operationId: 'bowl-purchase-1',
          useSavings: true,
          qualifyingActionIds: qualifying,
        )).status,
        StoryEventStatus.purchased,
      );
      expect(
        (await games.getTransactions(profileId)).where(
          (transaction) => transaction.source == 'day3_bowl_replacement',
        ),
        hasLength(1),
      );
    },
  );

  test('counts only successful post-arm pet actions including toys', () async {
    await addPetProof('before-task', 'item:toy_ball');
    await completeTask();
    final armed = await events.armDay3Bowl(
      profileId: profileId,
      qualifyingActionIds: qualifying,
      qualifyingItems: qualifyingItems,
    );
    expect(armed?.qualifyingInteractionCount, 0);
    await addPetProof('shop-purchase', 'purchase:toy_ball');
    await addPetProof('toy-use', 'item:toy_ball');
    await addPetProof('care-use', 'item:care_toothbrush');
    final snapshot = await events.loadDay3Bowl(
      profileId: profileId,
      qualifyingActionIds: qualifying,
    );
    expect(snapshot?.qualifyingInteractionCount, 2);
    expect(snapshot?.isDue, isTrue);
  });

  test(
    'postpone survives completion and later purchase belongs to Day 4',
    () async {
      await completeTask();
      await events.armDay3Bowl(
        profileId: profileId,
        qualifyingActionIds: qualifying,
        qualifyingItems: qualifyingItems,
      );
      await addPetProof('pet-1', 'free:pet');
      await addPetProof('pet-2', 'item:food_treat');
      await events.postponeDay3Bowl(
        profileId: profileId,
        currentPeriodId: period.id!,
        operationId: 'postpone-day3',
        qualifyingActionIds: qualifying,
      );
      await expectLater(
        events.purchaseDay3Bowl(
          profileId: profileId,
          currentPeriodId: period.id!,
          operationId: 'postpone-day3',
          useSavings: false,
          qualifyingActionIds: qualifying,
        ),
        throwsA(isA<StoryEventConflictException>()),
      );
      await resolveCheckpointForTest(
        database,
        profileId: profileId,
        periodId: period.id!,
        checkpointId: 'savings_decision',
      );
      await completePeriodForTest(
        database,
        profileId: profileId,
        periodId: period.id!,
      );
      final summaries = PeriodService(
        games,
        TestContentRepository(testPeriodDefinitions(count: 5)),
        storyEventPort: events,
      );
      final day3Summary = await summaries.getSummary(
        profileId: profileId,
        periodId: period.id!,
      );
      expect(day3Summary.bowlPostponed, isTrue);
      expect(day3Summary.unexpectedNeed, 0);
      final day4 = await games.startPeriod(
        profileId: profileId,
        definitionId: 'period_4',
        periodNumber: 4,
        baseIncome: 500,
        requiredCheckpoints: const ['financial_task'],
        createdAt: DateTime.utc(2026, 1, 4),
      );
      await games.confirmBudget(profileId: profileId, periodId: day4.id!);
      final purchased = await events.purchaseDay3Bowl(
        profileId: profileId,
        currentPeriodId: day4.id!,
        operationId: 'buy-day4',
        useSavings: false,
        qualifyingActionIds: qualifying,
      );
      expect(purchased.purchasePeriodNumber, 4);
      expect(purchased.wasPostponed, isTrue);
      final day4Summary = await summaries.getSummary(
        profileId: profileId,
        periodId: day4.id!,
      );
      expect(day4Summary.unexpectedNeed, 120);
      expect(day4Summary.carriedUnexpectedNeed, isTrue);
      expect((await games.getPeriodById(profileId, period.id!))?.actualNeed, 0);
      expect((await games.getPeriodById(profileId, day4.id!))?.actualNeed, 120);
      expect(
        (await summaries.getSummary(
          profileId: profileId,
          periodId: period.id!,
        )).bowlPostponed,
        isTrue,
      );
      await expectLater(
        events.purchaseDay3Bowl(
          profileId: profileId,
          currentPeriodId: day4.id!,
          operationId: 'buy-day4',
          useSavings: true,
          qualifyingActionIds: qualifying,
        ),
        throwsA(isA<StoryEventConflictException>()),
      );
    },
  );

  test('insufficient combined funds leave event and balances intact', () async {
    await completeTask();
    await events.armDay3Bowl(
      profileId: profileId,
      qualifyingActionIds: qualifying,
      qualifyingItems: qualifyingItems,
    );
    await addPetProof('pet-1', 'free:pet');
    await addPetProof('pet-2', 'item:food_treat');
    final db = await database.database;
    await db.update(
      'game_states',
      {'wallet_balance': 80, 'saved_amount': 39},
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    await expectLater(
      events.purchaseDay3Bowl(
        profileId: profileId,
        currentPeriodId: period.id!,
        operationId: 'insufficient',
        useSavings: true,
        qualifyingActionIds: qualifying,
      ),
      throwsA(isA<StoryEventInsufficientFundsException>()),
    );
    final state = await games.getGameState(profileId);
    expect(state?.walletBalance, 80);
    expect(state?.savedAmount, 39);
    expect((await games.getPeriodById(profileId, period.id!))?.actualNeed, 0);
    expect(
      (await events.loadDay3Bowl(
        profileId: profileId,
        qualifyingActionIds: qualifying,
      ))?.status,
      StoryEventStatus.armed,
    );
  });

  test('legacy purchased bowl proof prevents rearming', () async {
    await completeTask();
    await resolveCheckpointForTest(
      database,
      profileId: profileId,
      periodId: period.id!,
      checkpointId: 'changed_circumstance',
    );
    final db = await database.database;
    await db.insert('period_special_actions', {
      'profile_id': profileId,
      'period_id': period.id,
      'action_id': 'day3_bowl_replacement',
      'outcome': 'purchased',
      'operation_id': 'legacy-bowl',
      'created_at': DateTime.utc(2026, 1, 3).toIso8601String(),
    });
    final snapshot = await events.armDay3Bowl(
      profileId: profileId,
      qualifyingActionIds: qualifying,
      qualifyingItems: qualifyingItems,
    );
    expect(snapshot?.status, StoryEventStatus.purchased);
    expect(snapshot?.decisionOperationId, 'legacy-bowl');
    expect(
      await db.query(
        'campaign_story_events',
        where: 'profile_id = ?',
        whereArgs: [profileId],
      ),
      hasLength(1),
    );
  });

  for (final sample in [
    (wallet: 119, saved: 1, withdrawal: 1),
    (wallet: 0, saved: 120, withdrawal: 120),
    (wallet: 120, saved: 0, withdrawal: 0),
  ]) {
    test('savings fallback uses exact deficit ${sample.withdrawal}', () async {
      await completeTask();
      await events.armDay3Bowl(
        profileId: profileId,
        qualifyingActionIds: qualifying,
        qualifyingItems: qualifyingItems,
      );
      await addPetProof('pet-1', 'free:pet');
      await addPetProof('pet-2', 'item:toy_ball');
      final db = await database.database;
      await db.update(
        'game_states',
        {'wallet_balance': sample.wallet, 'saved_amount': sample.saved},
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      final snapshot = await events.purchaseDay3Bowl(
        profileId: profileId,
        currentPeriodId: period.id!,
        operationId: 'exact-deficit',
        useSavings: true,
        qualifyingActionIds: qualifying,
      );
      expect(snapshot.savingsUsed, sample.withdrawal);
      expect((await games.getGameState(profileId))?.walletBalance, 0);
      expect(
        (await games.getGameState(profileId))?.savedAmount,
        sample.saved - sample.withdrawal,
      );
      final withdrawals = (await games.getTransactions(profileId)).where(
        (transaction) =>
            transaction.source == 'story_day3_bowl_replacement_savings',
      );
      expect(withdrawals, hasLength(sample.withdrawal == 0 ? 0 : 1));
    });
  }

  test('postponed bowl remains optional through the end of Day 5', () async {
    await completeTask();
    await events.armDay3Bowl(
      profileId: profileId,
      qualifyingActionIds: qualifying,
      qualifyingItems: qualifyingItems,
    );
    await addPetProof('pet-1', 'free:pet');
    await addPetProof('pet-2', 'item:toy_ball');
    await events.postponeDay3Bowl(
      profileId: profileId,
      currentPeriodId: period.id!,
      operationId: 'carry-through-day5',
      qualifyingActionIds: qualifying,
    );
    await resolveCheckpointForTest(
      database,
      profileId: profileId,
      periodId: period.id!,
      checkpointId: 'savings_decision',
    );
    await completePeriodForTest(
      database,
      profileId: profileId,
      periodId: period.id!,
    );
    for (final day in [4, 5]) {
      final next = await games.startPeriod(
        profileId: profileId,
        definitionId: 'period_$day',
        periodNumber: day,
        baseIncome: 500,
        requiredCheckpoints: const ['financial_task'],
        createdAt: DateTime.utc(2026, 1, day),
      );
      await games.confirmBudget(profileId: profileId, periodId: next.id!);
      final activeSnapshot = await events.loadDay3Bowl(
        profileId: profileId,
        qualifyingActionIds: qualifying,
      );
      expect(activeSnapshot?.status, StoryEventStatus.postponed);
      expect(activeSnapshot?.currentPeriodNumber, day);
      await resolveCheckpointForTest(
        database,
        profileId: profileId,
        periodId: next.id!,
        checkpointId: 'financial_task',
      );
      await completePeriodForTest(
        database,
        profileId: profileId,
        periodId: next.id!,
      );
      if (day == 5) {
        final summary = await PeriodService(
          games,
          TestContentRepository(testPeriodDefinitions(count: 5)),
          storyEventPort: events,
        ).getSummary(profileId: profileId, periodId: next.id!);
        expect(summary.bowlPostponed, isTrue);
        expect(summary.unexpectedNeed, 0);
      }
    }
  });
}
