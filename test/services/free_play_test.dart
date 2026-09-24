import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/campaign_lifecycle.dart';
import 'package:finny/models/content_entry.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/campaign_lifecycle_repository.dart';
import 'package:finny/repositories/free_play_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_data_management_repository.dart';
import 'package:finny/services/free_play_service.dart';
import 'package:finny/services/period_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

final days = List<PeriodDefinition>.generate(5, (index) {
  final day = index + 1;
  return PeriodDefinition(
    id: 'period_$day',
    number: day,
    title: 'День',
    baseIncome: 500,
    requiredCheckpoints: const [],
  );
});
const food = ShopItem(
  id: 'food',
  name: 'Еда',
  category: ShopItemCategory.need,
  price: 20,
  persistent: false,
  effectType: 'satiety',
  effectValue: 10,
  unlockType: 'available',
  usagePolicy: ItemUsagePolicy.unlimited,
);
const toy = ShopItem(
  id: 'toy',
  name: 'Игрушка',
  category: ShopItemCategory.want,
  price: 30,
  persistent: true,
  effectType: 'mood',
  effectValue: 10,
  unlockType: 'available',
  displaySection: ShopDisplaySection.toys,
  usagePolicy: ItemUsagePolicy.oncePerPeriod,
);
const bow = ShopItem(
  id: 'bow',
  name: 'Бантик',
  category: ShopItemCategory.want,
  price: 25,
  persistent: true,
  effectType: 'none',
  effectValue: 0,
  unlockType: 'available',
  displaySection: ShopDisplaySection.accessories,
  equipSlot: ShopEquipSlot.head,
);
const brush = ShopItem(
  id: 'brush',
  name: 'Щётка',
  category: ShopItemCategory.need,
  price: 25,
  persistent: true,
  effectType: 'care',
  effectValue: 8,
  unlockType: 'available',
  displaySection: ShopDisplaySection.care,
  usagePolicy: ItemUsagePolicy.toothbrush,
);
const mixed = ShopItem(
  id: 'mixed',
  name: 'Полезный перекус',
  category: ShopItemCategory.need,
  price: 25,
  persistent: false,
  effectType: 'none',
  effectValue: 0,
  unlockType: 'available',
  displaySection: ShopDisplaySection.food,
  usagePolicy: ItemUsagePolicy.unlimited,
  effects: PetStatEffects(satiety: 5, care: 5),
);
const goalA = SavingsGoal(
  id: 'a',
  name: 'Цель A',
  price: 50,
  description: '',
  rewardAssetId: 'reward_a',
);
const goalB = SavingsGoal(
  id: 'b',
  name: 'Цель B',
  price: 80,
  description: '',
  rewardAssetId: 'reward_b',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late SqliteGameRepository games;
  late CampaignLifecycleRepository lifecycle;
  late FreePlayService freePlay;
  const profileId = 1;

  Future<void> addDay(int day, {String status = 'completed'}) async {
    final db = await database.database;
    await db.insert('game_periods', {
      'profile_id': profileId,
      'definition_id': 'period_$day',
      'period_number': day,
      'start_wallet_balance': 100,
      'status': status,
      'created_at': DateTime.utc(2026).toIso8601String(),
      if (status == 'completed')
        'completed_at': DateTime.utc(2026).toIso8601String(),
      if (status == 'completed') 'end_wallet_balance': 100,
    });
  }

  Future<void> completeCampaign() async {
    for (var day = 1; day <= 5; day++) {
      await addDay(day);
    }
  }

  setUp(() async {
    database = createTestDatabase();
    games = SqliteGameRepository(database);
    lifecycle = CampaignLifecycleRepository(database);
    final db = await database.database;
    await db.insert('profiles', {
      'id': profileId,
      'game_name': 'Игрок',
      'profile_type': 'NORMAL',
      'onboarding_completed': 1,
      'created_at': DateTime.utc(2026).toIso8601String(),
    });
    await games.ensureInitialState(profileId);
    await games.savePet(
      const Pet(
        profileId: profileId,
        name: 'Финни',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 3,
        growthPoints: 0,
        satiety: 90,
        care: 100,
        mood: 95,
      ),
    );
    await db.update(
      'game_states',
      {'wallet_balance': 200},
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    freePlay = FreePlayService(
      FreePlayRepository(database),
      TestContentRepository(
        days,
        shopItems: [food, toy, bow, brush, mixed],
        goals: [goalA, goalB],
      ),
      games,
    );
  });
  tearDown(() => database.close());

  test('campaign mode until five canonical days complete and transitions are durable/idempotent', () async {
    for (var day = 1; day <= 4; day++) {
      await addDay(day);
    }
    expect((await lifecycle.load(profileId, days)).mode, CampaignMode.campaign);
    await addDay(5, status: 'active');
    expect((await lifecycle.load(profileId, days)).mode, CampaignMode.campaign);
    await expectLater(
      lifecycle.startFreePlay(profileId, days),
      throwsStateError,
    );
    final db = await database.database;
    await db.update(
      'game_periods',
      {'status': 'completed'},
      where: 'profile_id = ? AND period_number = 5',
      whereArgs: [profileId],
    );
    expect(
      (await lifecycle.load(profileId, days)).mode,
      CampaignMode.finalePending,
    );
    await db.update(
      'game_states',
      {'goal_change_used': 1, 'active_goal_id': 'a'},
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    final finished = await lifecycle.finishStory(profileId, days);
    expect(finished.mode, CampaignMode.campaignFinished);
    expect(
      (await lifecycle.finishStory(profileId, days)).finaleAcknowledgedAt,
      finished.finaleAcknowledgedAt,
    );
    final started = await lifecycle.startFreePlay(profileId, days);
    expect(started.mode, CampaignMode.freePlay);
    expect(started.finaleAcknowledgedAt, finished.finaleAcknowledgedAt);
    expect(
      (await lifecycle.startFreePlay(profileId, days)).freePlayStartedAt,
      started.freePlayStartedAt,
    );
    expect((await games.getGameState(profileId))!.goalChangeUsed, isFalse);
    expect((await games.getCurrentPeriod(profileId)), isNull);
    expect(
      (await db.query(
        'game_periods',
        where: 'profile_id = ?',
        whereArgs: [profileId],
      )).length,
      5,
    );
  });

  test('direct Free Play choice acknowledges finale once, including an empty completion row', () async {
    await completeCampaign();
    final db = await database.database;
    await db.insert('campaign_completion', {'profile_id': profileId});
    expect(
      (await lifecycle.load(profileId, days)).mode,
      CampaignMode.finalePending,
    );
    final started = await lifecycle.startFreePlay(profileId, days);
    expect(started.finaleAcknowledgedAt, isNotNull);
    expect(started.freePlayStartedAt, isNotNull);
    expect(
      (await lifecycle.startFreePlay(profileId, days)).freePlayStartedAt,
      started.freePlayStartedAt,
    );
    expect(
      (await lifecycle.finishStory(profileId, days)).mode,
      CampaignMode.freePlay,
    );
  });

  test(
    'purchase and savings use periodless transactions without changing Day 5',
    () async {
      await completeCampaign();
      await expectLater(
        freePlay.purchase(
          profileId: profileId,
          itemId: 'food',
          operationId: 'before',
        ),
        throwsStateError,
      );
      await lifecycle.startFreePlay(profileId, days);
      final summaryService = PeriodService(games, TestContentRepository(days));
      final dayFiveId = (await games.getPeriod(profileId, 5))!.id!;
      final beforeSummary = await summaryService.getSummary(
        profileId: profileId,
        periodId: dayFiveId,
      );
      await freePlay.purchase(
        profileId: profileId,
        itemId: 'toy',
        operationId: 'buy-toy',
      );
      await freePlay.purchase(
        profileId: profileId,
        itemId: 'toy',
        operationId: 'buy-toy',
      );
      await expectLater(
        freePlay.purchase(
          profileId: profileId,
          itemId: 'food',
          operationId: 'buy-toy',
        ),
        throwsStateError,
      );
      expect(await games.getInventoryQuantity(profileId, 'toy'), 1);
      await expectLater(
        freePlay.purchase(
          profileId: profileId,
          itemId: 'toy',
          operationId: 'again',
        ),
        throwsStateError,
      );
      await freePlay.purchase(
        profileId: profileId,
        itemId: 'food',
        operationId: 'food-1',
      );
      await freePlay.purchase(
        profileId: profileId,
        itemId: 'food',
        operationId: 'food-2',
      );
      expect(await games.getInventoryQuantity(profileId, 'food'), 2);
      await games.selectSavingsGoal(profileId: profileId, goal: goalA);
      await freePlay.deposit(
        profileId: profileId,
        amount: 10,
        operationId: 'save-1',
      );
      await freePlay.deposit(
        profileId: profileId,
        amount: 10,
        operationId: 'save-1',
      );
      await freePlay.changeGoal(profileId: profileId, goalId: 'b');
      await freePlay.changeGoal(profileId: profileId, goalId: 'a');
      final state = (await games.getGameState(profileId))!;
      expect(state.walletBalance, 120);
      expect(state.savedAmount, 10);
      expect(state.activeGoalId, 'a');
      expect(state.goalChangeUsed, isFalse);
      final db = await database.database;
      final transactions = await db.query(
        'transactions',
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      expect(transactions.length, 4);
      expect(transactions.every((row) => row['period_id'] == null), isTrue);
      expect(transactions.map((row) => row['type']), [
        'want_expense',
        'need_expense',
        'need_expense',
        'savings_deposit',
      ]);
      final dayFive = (await db.query(
        'game_periods',
        where: 'profile_id = ? AND period_number = 5',
        whereArgs: [profileId],
      )).single;
      expect(dayFive['actual_need'], 0);
      expect(dayFive['actual_want'], 0);
      expect(dayFive['actual_savings'], 0);
      final afterSummary = await summaryService.getSummary(
        profileId: profileId,
        periodId: dayFiveId,
      );
      expect(afterSummary.factNeed, beforeSummary.factNeed);
      expect(afterSummary.factWant, beforeSummary.factWant);
      expect(afterSummary.factSavings, beforeSummary.factSavings);
      expect(afterSummary.factRemainder, beforeSummary.factRemainder);
    },
  );

  test('Finny Catch reward is Free Play-only, periodless and idempotent without changing Day 5', () async {
    await completeCampaign();
    await expectLater(
      freePlay.grantMinigameReward(
        profileId: profileId,
        amount: 33,
        runId: 'run-1',
      ),
      throwsStateError,
    );
    await lifecycle.startFreePlay(profileId, days);
    final dayFiveId = (await games.getPeriod(profileId, 5))!.id!;
    final summaryService = PeriodService(games, TestContentRepository(days));
    final beforeSummary = await summaryService.getSummary(
      profileId: profileId,
      periodId: dayFiveId,
    );
    final db = await database.database;
    final beforePeriod = (await db.query(
      'game_periods',
      where: 'id = ?',
      whereArgs: [dayFiveId],
    )).single;
    final awarded = await freePlay.grantMinigameReward(
      profileId: profileId,
      amount: 33,
      runId: 'run-1',
    );
    expect(awarded.walletBalance, 233);
    final repeated = await freePlay.grantMinigameReward(
      profileId: profileId,
      amount: 33,
      runId: 'run-1',
    );
    expect(repeated.walletBalance, 233);
    await expectLater(
      freePlay.grantMinigameReward(
        profileId: profileId,
        amount: 34,
        runId: 'run-1',
      ),
      throwsStateError,
    );
    await expectLater(
      freePlay.grantMinigameReward(
        profileId: profileId,
        amount: 0,
        runId: 'bad',
      ),
      throwsArgumentError,
    );
    await expectLater(
      freePlay.grantMinigameReward(profileId: profileId, amount: 10, runId: ''),
      throwsArgumentError,
    );
    final transactions = await db.query(
      'transactions',
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    expect(transactions, hasLength(1));
    final reward = transactions.single;
    expect(reward['period_id'], isNull);
    expect(reward['type'], 'other_income');
    expect(reward['amount'], 33);
    expect(reward['source'], 'free_play_minigame:finny_catch');
    expect(reward['description'], 'Мини-игра «Лови монеты»');
    expect(reward['deduplication_key'], 'operation:run-1');
    expect((await games.getGameState(profileId))!.walletBalance, 233);
    final afterPeriod = (await db.query(
      'game_periods',
      where: 'id = ?',
      whereArgs: [dayFiveId],
    )).single;
    for (final field in [
      'actual_need',
      'actual_want',
      'actual_savings',
      'extra_income',
    ]) {
      expect(afterPeriod[field], beforePeriod[field]);
    }
    final afterSummary = await summaryService.getSummary(
      profileId: profileId,
      periodId: dayFiveId,
    );
    expect(afterSummary.factNeed, beforeSummary.factNeed);
    expect(afterSummary.factWant, beforeSummary.factWant);
    expect(afterSummary.factSavings, beforeSummary.factSavings);
    expect(afterSummary.factRemainder, beforeSummary.factRemainder);
  });

  test(
    'petting repeats, toy repeats and consumable at max is preserved',
    () async {
      await completeCampaign();
      await lifecycle.startFreePlay(profileId, days);
      final db = await database.database;
      await db.insert('inventory', {
        'profile_id': profileId,
        'item_id': 'toy',
        'quantity': 1,
        'acquired_at': DateTime.utc(2026).toIso8601String(),
      });
      await db.insert('inventory', {
        'profile_id': profileId,
        'item_id': 'food',
        'quantity': 1,
        'acquired_at': DateTime.utc(2026).toIso8601String(),
      });
      await freePlay.pet(profileId: profileId, operationId: 'pet-1');
      await freePlay.pet(profileId: profileId, operationId: 'pet-2');
      expect((await games.getPet(profileId))!.mood, 100);
      await freePlay.useItem(
        profileId: profileId,
        itemId: 'toy',
        operationId: 'toy-1',
      );
      await freePlay.useItem(
        profileId: profileId,
        itemId: 'toy',
        operationId: 'toy-2',
      );
      expect(await games.getInventoryQuantity(profileId, 'toy'), 1);
      await freePlay.useItem(
        profileId: profileId,
        itemId: 'food',
        operationId: 'food-use',
      );
      expect((await games.getPet(profileId))!.satiety, 100);
      await db.insert('inventory', {
        'profile_id': profileId,
        'item_id': 'food',
        'quantity': 1,
        'acquired_at': DateTime.utc(2026).toIso8601String(),
      });
      final maxResult = await freePlay.useItem(
        profileId: profileId,
        itemId: 'food',
        operationId: 'food-max',
      );
      expect(maxResult.notice, 'Финни уже сыт!');
      expect(await games.getInventoryQuantity(profileId, 'food'), 1);
      expect(
        await db.query(
          'pet_daily_usage',
          where: 'profile_id = ?',
          whereArgs: [profileId],
        ),
        isEmpty,
      );
      expect(
        (await db.query(
          'game_periods',
          where: 'profile_id = ? AND period_number = 5',
          whereArgs: [profileId],
        )).single['day_progress'],
        0,
      );
    },
  );

  test(
    'owned accessory can be equipped and removed without changing stats',
    () async {
      await completeCampaign();
      await lifecycle.startFreePlay(profileId, days);
      await expectLater(
        freePlay.equip(profileId: profileId, itemId: 'bow'),
        throwsA(isA<Exception>()),
      );
      await freePlay.purchase(
        profileId: profileId,
        itemId: 'bow',
        operationId: 'bow-buy',
      );
      final before = await games.getPet(profileId);
      await freePlay.equip(profileId: profileId, itemId: 'bow');
      expect((await freePlay.equipped(profileId))[ShopEquipSlot.head], 'bow');
      await freePlay.unequip(profileId: profileId, slot: ShopEquipSlot.head);
      expect(await freePlay.equipped(profileId), isEmpty);
      expect((await games.getPet(profileId))!.toMap(), before!.toMap());
    },
  );

  test('reached goal must be claimed before selecting the next', () async {
    await completeCampaign();
    await lifecycle.startFreePlay(profileId, days);
    await games.selectSavingsGoal(profileId: profileId, goal: goalA);
    await expectLater(
      freePlay.deposit(
        profileId: profileId,
        amount: 201,
        operationId: 'wallet',
      ),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      freePlay.deposit(
        profileId: profileId,
        amount: 51,
        operationId: 'remaining',
      ),
      throwsA(isA<Exception>()),
    );
    await freePlay.deposit(
      profileId: profileId,
      amount: 50,
      operationId: 'reach',
    );
    await expectLater(
      freePlay.changeGoal(profileId: profileId, goalId: 'b'),
      throwsA(isA<Exception>()),
    );
    await games.claimSavingsGoal(
      profileId: profileId,
      goal: goalA,
      operationId: 'claim',
    );
    await games.selectSavingsGoal(profileId: profileId, goal: goalB);
    expect((await games.getGameState(profileId))!.activeGoalId, 'b');
    expect((await games.getGameState(profileId))!.savedAmount, 0);
  });

  test(
    'toothbrush and mixed effects work without slots or daily usage',
    () async {
      await completeCampaign();
      await lifecycle.startFreePlay(profileId, days);
      final db = await database.database;
      for (final itemId in ['brush', 'mixed']) {
        await db.insert('inventory', {
          'profile_id': profileId,
          'item_id': itemId,
          'quantity': 1,
          'acquired_at': '2026-01-01',
        });
      }
      await freePlay.useItem(
        profileId: profileId,
        itemId: 'brush',
        operationId: 'brush-1',
      );
      await freePlay.useItem(
        profileId: profileId,
        itemId: 'brush',
        operationId: 'brush-2',
      );
      expect(await games.getInventoryQuantity(profileId, 'brush'), 1);
      expect(
        (await freePlay.useItem(
          profileId: profileId,
          itemId: 'mixed',
          operationId: 'mixed-1',
        )).notice,
        isNull,
      );
      await freePlay.useItem(
        profileId: profileId,
        itemId: 'mixed',
        operationId: 'mixed-1',
      );
      expect(await games.getInventoryQuantity(profileId, 'mixed'), 0);
      expect((await games.getPet(profileId))!.satiety, 95);
      await expectLater(
        freePlay.pet(profileId: profileId, operationId: 'mixed-1'),
        throwsA(isA<Exception>()),
      );
      expect(await db.query('pet_daily_usage'), isEmpty);
    },
  );

  test('adult profile reset clears post-campaign state', () async {
    await completeCampaign();
    await lifecycle.startFreePlay(profileId, days);
    await freePlay.pet(profileId: profileId, operationId: 'before-reset');
    await freePlay.purchase(
      profileId: profileId,
      itemId: 'bow',
      operationId: 'buy-before-reset',
    );
    await freePlay.equip(profileId: profileId, itemId: 'bow');
    await SqliteProfileDataManagement(database).resetNormalProfile(profileId);
    final db = await database.database;
    expect(await db.query('campaign_completion'), isEmpty);
    expect(await db.query('free_play_pet_operations'), isEmpty);
    expect(await db.query('free_play_equipped_accessories'), isEmpty);
    expect((await lifecycle.load(profileId, days)).mode, CampaignMode.campaign);
  });
}
