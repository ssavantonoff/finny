import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/item_use_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

const apple = ShopItem(
  id: 'food_apple',
  name: 'Яблоко',
  category: ShopItemCategory.need,
  price: 40,
  persistent: false,
  effectType: 'satiety',
  effectValue: 20,
  unlockType: 'available',
  usagePolicy: ItemUsagePolicy.unlimited,
);

const treat = ShopItem(
  id: 'food_treat',
  name: 'Лакомство',
  category: ShopItemCategory.want,
  price: 60,
  persistent: false,
  effectType: 'none',
  effectValue: 0,
  unlockType: 'available',
  usagePolicy: ItemUsagePolicy.unlimited,
  effects: PetStatEffects(satiety: 10, mood: 10),
);

const comb = ShopItem(
  id: 'care_comb',
  name: 'Расчёска',
  category: ShopItemCategory.need,
  price: 70,
  persistent: true,
  effectType: 'care',
  effectValue: 25,
  unlockType: 'available',
  displaySection: ShopDisplaySection.care,
  usagePolicy: ItemUsagePolicy.oncePerPeriod,
);

const shampoo = ShopItem(
  id: 'care_shampoo',
  name: 'Шампунь',
  category: ShopItemCategory.need,
  price: 60,
  persistent: false,
  effectType: 'care',
  effectValue: 40,
  unlockType: 'available',
  displaySection: ShopDisplaySection.care,
  usagePolicy: ItemUsagePolicy.unlimited,
);

const toothbrush = ShopItem(
  id: 'care_toothbrush',
  name: 'Зубная щётка',
  category: ShopItemCategory.need,
  price: 80,
  persistent: true,
  effectType: 'care',
  effectValue: 8,
  unlockType: 'available',
  displaySection: ShopDisplaySection.care,
  usagePolicy: ItemUsagePolicy.toothbrush,
);

const ball = ShopItem(
  id: 'toy_ball',
  name: 'Мяч',
  category: ShopItemCategory.want,
  price: 120,
  persistent: true,
  effectType: 'mood',
  effectValue: 35,
  unlockType: 'available',
  displaySection: ShopDisplaySection.toys,
  usagePolicy: ItemUsagePolicy.oncePerPeriod,
);

const frisbee = ShopItem(
  id: 'toy_frisbee',
  name: 'Фрисби',
  category: ShopItemCategory.want,
  price: 140,
  persistent: true,
  effectType: 'mood',
  effectValue: 40,
  unlockType: 'available',
  displaySection: ShopDisplaySection.toys,
  usagePolicy: ItemUsagePolicy.oncePerPeriod,
);

const plush = ShopItem(
  id: 'toy_plush',
  name: 'Плюшевая игрушка',
  category: ShopItemCategory.want,
  price: 160,
  persistent: true,
  effectType: 'mood',
  effectValue: 30,
  unlockType: 'available',
  displaySection: ShopDisplaySection.toys,
  usagePolicy: ItemUsagePolicy.oncePerPeriod,
);

const items = [apple, treat, comb, shampoo, toothbrush, ball, frisbee, plush];

typedef ActivePlayer = ({int profileId, GamePeriod period});

void main() {
  late AppDatabase database;
  late SqliteProfileRepository profiles;
  late SqliteGameRepository games;
  late ItemUseService service;

  setUp(() {
    database = createTestDatabase();
    profiles = SqliteProfileRepository(database);
    games = SqliteGameRepository(database);
    service = ItemUseService(
      SqlitePetActionPort(database),
      TestContentRepository(const [], shopItems: items),
    );
  });

  tearDown(() => database.close());

  Future<ActivePlayer> createPlayer({
    ProfileType type = ProfileType.normal,
    int satiety = 40,
    int care = 40,
    int mood = 40,
    bool active = true,
  }) async {
    final profile = await profiles.create(
      Profile(
        gameName: type == ProfileType.normal ? 'Player' : 'Demo',
        profileType: type,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 9, 18),
      ),
    );
    final profileId = profile.id!;
    await games.ensureInitialState(profileId);
    await games.savePet(
      Pet(
        profileId: profileId,
        name: 'Finny',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 0,
        growthPoints: 0,
        satiety: satiety,
        care: care,
        mood: mood,
      ),
    );
    final planning = await games.startPeriod(
      profileId: profileId,
      definitionId: 'period_1',
      periodNumber: 1,
      baseIncome: 500,
      requiredCheckpoints: const ['done'],
      createdAt: DateTime.utc(2026, 9, 18),
    );
    final period = active
        ? await confirmBudgetForTest(
            games,
            profileId: profileId,
            periodId: planning.id!,
          )
        : planning;
    return (profileId: profileId, period: period);
  }

  Future<void> grant(int profileId, ShopItem item, {int quantity = 1}) async {
    await (await database.database).rawInsert(
      '''
      INSERT INTO inventory (profile_id, item_id, quantity, acquired_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(profile_id, item_id) DO UPDATE SET quantity = excluded.quantity
      ''',
      [
        profileId,
        item.id,
        quantity,
        DateTime.utc(2026, 9, 18).toIso8601String(),
      ],
    );
  }

  Future<GamePeriod> startNextPeriod(ActivePlayer player) async {
    await games.resolveCheckpoint(
      profileId: player.profileId,
      periodId: player.period.id!,
      checkpointId: 'done',
    );
    await completePeriodForTest(
      database,
      profileId: player.profileId,
      periodId: player.period.id!,
    );
    final planning = await games.startPeriod(
      profileId: player.profileId,
      definitionId: 'period_2',
      periodNumber: 2,
      baseIncome: 500,
      requiredCheckpoints: const ['done'],
      createdAt: DateTime.utc(2026, 9, 19),
    );
    return confirmBudgetForTest(
      games,
      profileId: player.profileId,
      periodId: planning.id!,
    );
  }

  test(
    'canonical consumable effects clamp and decrement exactly one',
    () async {
      final player = await createPlayer(satiety: 92, mood: 95);
      await grant(player.profileId, apple, quantity: 2);
      await grant(player.profileId, treat);

      final afterApple = await service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: apple.id,
        operationId: 'apple-1',
      );
      expect(afterApple.satiety, 100);
      expect(await games.getInventoryQuantity(player.profileId, apple.id), 1);

      final afterTreat = await service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: treat.id,
        operationId: 'treat-1',
      );
      expect((afterTreat.satiety, afterTreat.mood), (100, 100));
      expect(await games.getInventoryQuantity(player.profileId, treat.id), 0);
      expect(
        await games.getPetDailyUsageCount(
          profileId: player.profileId,
          periodId: player.period.id!,
          actionId: 'item:${apple.id}',
          slot: PetActionSlot.defaultSlot,
        ),
        1,
      );
    },
  );

  test('only first four feedings advance time and replay is inert', () async {
    final player = await createPlayer(satiety: 50, care: 80, mood: 80);
    await grant(player.profileId, apple, quantity: 5);

    for (var use = 1; use <= 5; use++) {
      await service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: apple.id,
        operationId: 'feeding-$use',
      );
    }
    final afterFive = await games.getPeriodById(
      player.profileId,
      player.period.id!,
    );
    expect(afterFive?.dayProgress, 42);
    expect((await games.getPet(player.profileId))?.satiety, 100);
    expect(await games.getInventoryQuantity(player.profileId, apple.id), 0);
    expect(
      await games.getPetDailyUsageCount(
        profileId: player.profileId,
        periodId: player.period.id!,
        actionId: 'time:feeding',
        slot: PetActionSlot.defaultSlot,
      ),
      5,
    );

    await service.useItem(
      profileId: player.profileId,
      periodId: player.period.id!,
      itemId: apple.id,
      operationId: 'feeding-5',
    );
    expect(
      (await games.getPeriodById(
        player.profileId,
        player.period.id!,
      ))?.dayProgress,
      42,
    );
    expect(await games.getInventoryQuantity(player.profileId, apple.id), 0);
  });

  test('only first two ordinary care uses advance time', () async {
    final player = await createPlayer(care: 40);
    await grant(player.profileId, shampoo, quantity: 3);

    for (var use = 1; use <= 3; use++) {
      await service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: shampoo.id,
        operationId: 'care-$use',
      );
    }
    expect(
      (await games.getPeriodById(
        player.profileId,
        player.period.id!,
      ))?.dayProgress,
      20,
    );
    expect((await games.getPet(player.profileId))?.care, 100);
    expect(await games.getInventoryQuantity(player.profileId, shampoo.id), 0);
    expect(
      await games.getPetDailyUsageCount(
        profileId: player.profileId,
        periodId: player.period.id!,
        actionId: 'time:care',
        slot: PetActionSlot.defaultSlot,
      ),
      3,
    );
  });

  test('zero quantity rejects use without pet or usage changes', () async {
    final player = await createPlayer();

    await expectLater(
      service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: apple.id,
        operationId: 'missing-apple',
      ),
      throwsA(isA<PetItemNotOwnedException>()),
    );

    final pet = await games.getPet(player.profileId);
    expect((pet?.satiety, pet?.care, pet?.mood), (34, 38, 39));
    expect(await (await database.database).query('pet_daily_usage'), isEmpty);
    expect(
      await (await database.database).query('pet_action_operations'),
      isEmpty,
    );
  });

  test('persistent item is not consumed and is limited per period', () async {
    final player = await createPlayer();
    await grant(player.profileId, comb);

    final first = await service.useItem(
      profileId: player.profileId,
      periodId: player.period.id!,
      itemId: comb.id,
      operationId: 'comb-1',
    );
    expect(first.care, 62);
    expect(await games.getInventoryQuantity(player.profileId, comb.id), 1);

    await expectLater(
      service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: comb.id,
        operationId: 'comb-2',
      ),
      throwsA(isA<PetActionAlreadyUsedException>()),
    );
    expect((await games.getPet(player.profileId))?.care, 62);

    final next = await startNextPeriod(player);
    final nextUse = await service.useItem(
      profileId: player.profileId,
      periodId: next.id!,
      itemId: comb.id,
      operationId: 'comb-next-day',
    );
    expect(nextUse.care, 57);
    expect(await games.getInventoryQuantity(player.profileId, comb.id), 1);
  });

  test('each toy has its own once-per-period usage identity', () async {
    final player = await createPlayer();
    await grant(player.profileId, plush);
    await grant(player.profileId, frisbee);

    await service.useItem(
      profileId: player.profileId,
      periodId: player.period.id!,
      itemId: plush.id,
      operationId: 'plush-1',
    );
    await service.useItem(
      profileId: player.profileId,
      periodId: player.period.id!,
      itemId: frisbee.id,
      operationId: 'frisbee-independent',
    );
    expect((await games.getPet(player.profileId))?.mood, 100);
    await expectLater(
      service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: plush.id,
        operationId: 'plush-2',
      ),
      throwsA(isA<PetActionAlreadyUsedException>()),
    );
  });

  test('toothbrush has distinct morning and evening phases', () async {
    final player = await createPlayer();
    await grant(player.profileId, toothbrush);

    await service.useItem(
      profileId: player.profileId,
      periodId: player.period.id!,
      itemId: toothbrush.id,
      operationId: 'brush-morning',
      slot: PetActionSlot.morning,
    );
    await expectLater(
      service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: toothbrush.id,
        operationId: 'brush-morning-again',
        slot: PetActionSlot.morning,
      ),
      throwsA(isA<PetActionAlreadyUsedException>()),
    );
    await expectLater(
      service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: toothbrush.id,
        operationId: 'brush-evening-early',
        slot: PetActionSlot.evening,
      ),
      throwsA(isA<PetActionSlotUnavailableException>()),
    );

    final db = await database.database;
    await db.update(
      'game_periods',
      {'day_progress': 35},
      where: 'id = ?',
      whereArgs: [player.period.id],
    );
    await expectLater(
      service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: toothbrush.id,
        operationId: 'brush-morning-late',
        slot: PetActionSlot.morning,
      ),
      throwsA(isA<PetActionSlotUnavailableException>()),
    );
    await db.update(
      'game_periods',
      {'day_progress': 70},
      where: 'id = ?',
      whereArgs: [player.period.id],
    );
    final evening = await service.useItem(
      profileId: player.profileId,
      periodId: player.period.id!,
      itemId: toothbrush.id,
      operationId: 'brush-evening',
      slot: PetActionSlot.evening,
    );
    expect(evening.care, 52);
    await expectLater(
      service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: toothbrush.id,
        operationId: 'brush-evening-again',
        slot: PetActionSlot.evening,
      ),
      throwsA(isA<PetActionAlreadyUsedException>()),
    );
  });

  test('toothbrush slot is determined from progress before its cost', () async {
    final player = await createPlayer(care: 50);
    final db = await database.database;
    await db.update(
      'game_periods',
      {'day_progress': 34},
      where: 'id = ?',
      whereArgs: [player.period.id],
    );
    await games.savePet(
      (await games.getPet(player.profileId))!.copyWith(care: 50),
    );

    final result = await service.useItem(
      profileId: player.profileId,
      periodId: player.period.id!,
      itemId: toothbrush.id,
      operationId: 'brush-crosses-morning-boundary',
      slot: PetActionSlot.morning,
    );
    expect(result.care, 56);
    expect(
      (await games.getPeriodById(
        player.profileId,
        player.period.id!,
      ))?.dayProgress,
      40,
    );
  });

  test('free petting is once per period and resets next period', () async {
    final player = await createPlayer();

    await service.performFreeInteraction(
      profileId: player.profileId,
      periodId: player.period.id!,
      interaction: FreePetInteraction.pet,
      operationId: 'free-pet',
    );
    expect((await games.getPet(player.profileId))?.mood, 44);
    expect(
      (await games.getPeriodById(
        player.profileId,
        player.period.id!,
      ))?.dayProgress,
      14,
    );

    final replay = await service.performFreeInteraction(
      profileId: player.profileId,
      periodId: player.period.id!,
      interaction: FreePetInteraction.pet,
      operationId: 'free-pet',
    );
    expect(replay.mood, 44);
    expect(
      (await games.getPeriodById(
        player.profileId,
        player.period.id!,
      ))?.dayProgress,
      14,
    );

    await expectLater(
      service.performFreeInteraction(
        profileId: player.profileId,
        periodId: player.period.id!,
        interaction: FreePetInteraction.pet,
        operationId: 'free-pet-again',
      ),
      throwsA(isA<PetActionAlreadyUsedException>()),
    );

    final next = await startNextPeriod(player);
    final nextPet = await service.performFreeInteraction(
      profileId: player.profileId,
      periodId: next.id!,
      interaction: FreePetInteraction.pet,
      operationId: 'free-pet-next',
    );
    expect(nextPet.mood, greaterThan(35));
  });

  test('same operation replays safely and changed payload conflicts', () async {
    final player = await createPlayer();
    await grant(player.profileId, apple, quantity: 2);

    await service.useItem(
      profileId: player.profileId,
      periodId: player.period.id!,
      itemId: apple.id,
      operationId: 'ambiguous-use',
    );
    final replay = await service.useItem(
      profileId: player.profileId,
      periodId: player.period.id!,
      itemId: apple.id,
      operationId: 'ambiguous-use',
    );
    expect(replay.satiety, 50);
    expect(await games.getInventoryQuantity(player.profileId, apple.id), 1);
    expect(
      await games.getPetDailyUsageCount(
        profileId: player.profileId,
        periodId: player.period.id!,
        actionId: 'item:${apple.id}',
        slot: PetActionSlot.defaultSlot,
      ),
      1,
    );

    await expectLater(
      service.performFreeInteraction(
        profileId: player.profileId,
        periodId: player.period.id!,
        interaction: FreePetInteraction.pet,
        operationId: 'ambiguous-use',
      ),
      throwsA(isA<PetOperationConflictException>()),
    );
  });

  test(
    'replay is allowed after completion but a new action is rejected',
    () async {
      final player = await createPlayer();
      await grant(player.profileId, apple, quantity: 2);
      await service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: apple.id,
        operationId: 'completed-replay',
      );
      await games.resolveCheckpoint(
        profileId: player.profileId,
        periodId: player.period.id!,
        checkpointId: 'done',
      );
      await completePeriodForTest(
        database,
        profileId: player.profileId,
        periodId: player.period.id!,
      );

      await service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: apple.id,
        operationId: 'completed-replay',
      );
      expect(await games.getInventoryQuantity(player.profileId, apple.id), 1);
      await expectLater(
        service.useItem(
          profileId: player.profileId,
          periodId: player.period.id!,
          itemId: apple.id,
          operationId: 'completed-new',
        ),
        throwsStateError,
      );
    },
  );

  test('planning rejects actions without partial changes', () async {
    final player = await createPlayer(active: false);
    await grant(player.profileId, apple);

    await expectLater(
      service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: apple.id,
        operationId: 'planning-use',
      ),
      throwsStateError,
    );
    expect(await games.getInventoryQuantity(player.profileId, apple.id), 1);
    expect((await games.getPet(player.profileId))?.satiety, 40);
  });

  test('period ownership and profiles are isolated', () async {
    final normal = await createPlayer();
    final demo = await createPlayer(type: ProfileType.demo, mood: 60);
    await grant(normal.profileId, frisbee);

    await expectLater(
      service.useItem(
        profileId: normal.profileId,
        periodId: demo.period.id!,
        itemId: frisbee.id,
        operationId: 'foreign-period',
      ),
      throwsStateError,
    );
    expect((await games.getPet(normal.profileId))?.mood, 39);
    expect((await games.getPet(demo.profileId))?.mood, 59);
    expect(await games.getInventoryQuantity(normal.profileId, frisbee.id), 1);
  });

  test('storage failure rolls pet, inventory, usage and proof back', () async {
    final player = await createPlayer();
    await grant(player.profileId, apple);
    final db = await database.database;
    await db.execute('''
      CREATE TRIGGER reject_pet_action_proof
      BEFORE INSERT ON pet_action_operations
      BEGIN
        SELECT RAISE(ABORT, 'forced proof failure');
      END
    ''');

    await expectLater(
      service.useItem(
        profileId: player.profileId,
        periodId: player.period.id!,
        itemId: apple.id,
        operationId: 'rollback-use',
      ),
      throwsA(anything),
    );
    expect((await games.getPet(player.profileId))?.satiety, 34);
    expect(await games.getInventoryQuantity(player.profileId, apple.id), 1);
    expect(await db.query('pet_daily_usage'), isEmpty);
    expect(await db.query('pet_action_operations'), isEmpty);
  });

  test('concurrent persistent uses allow exactly one new operation', () async {
    final player = await createPlayer();
    await grant(player.profileId, frisbee);

    Future<Object> attempt(String operationId) async {
      try {
        return await service.useItem(
          profileId: player.profileId,
          periodId: player.period.id!,
          itemId: frisbee.id,
          operationId: operationId,
        );
      } catch (error) {
        return error;
      }
    }

    final results = await Future.wait([
      attempt('frisbee-concurrent-a'),
      attempt('frisbee-concurrent-b'),
    ]);
    expect(results.whereType<Pet>(), hasLength(1));
    expect(results.whereType<PetActionAlreadyUsedException>(), hasLength(1));
    expect((await games.getPet(player.profileId))?.mood, 79);
  });

  test('restart preserves quantity, usage and idempotent replay', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('finny_item_use_');
    final path = '${directory.path}/finny.sqlite';
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final first = AppDatabase(factory: databaseFactoryFfi, databasePath: path);
    final firstProfiles = SqliteProfileRepository(first);
    final firstGames = SqliteGameRepository(first);
    final profile = await firstProfiles.create(
      Profile(
        gameName: 'Persistent player',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 9, 18),
      ),
    );
    final profileId = profile.id!;
    await firstGames.ensureInitialState(profileId);
    await firstGames.savePet(
      const Pet(
        profileId: 1,
        name: 'Finny',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 0,
        growthPoints: 0,
        satiety: 40,
        care: 40,
        mood: 40,
      ),
    );
    final planning = await firstGames.startPeriod(
      profileId: profileId,
      definitionId: 'period_1',
      periodNumber: 1,
      baseIncome: 500,
      requiredCheckpoints: const ['done'],
      createdAt: DateTime.utc(2026, 9, 18),
    );
    final period = await confirmBudgetForTest(
      firstGames,
      profileId: profileId,
      periodId: planning.id!,
    );
    await (await first.database).insert('inventory', {
      'profile_id': profileId,
      'item_id': apple.id,
      'quantity': 3,
      'acquired_at': DateTime.utc(2026, 9, 18).toIso8601String(),
    });
    await (await first.database).insert('inventory', {
      'profile_id': profileId,
      'item_id': comb.id,
      'quantity': 1,
      'acquired_at': DateTime.utc(2026, 9, 18).toIso8601String(),
    });
    final firstService = ItemUseService(
      SqlitePetActionPort(first),
      TestContentRepository(const [], shopItems: items),
    );
    await firstService.useItem(
      profileId: profileId,
      periodId: period.id!,
      itemId: apple.id,
      operationId: 'restart-replay',
    );
    await firstService.useItem(
      profileId: profileId,
      periodId: period.id!,
      itemId: comb.id,
      operationId: 'comb-before-restart',
    );
    await firstService.performFreeInteraction(
      profileId: profileId,
      periodId: period.id!,
      interaction: FreePetInteraction.pet,
      operationId: 'pet-before-restart',
    );
    await first.close();

    final reopened = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    addTearDown(reopened.close);
    final reopenedGames = SqliteGameRepository(reopened);
    final reopenedService = ItemUseService(
      SqlitePetActionPort(reopened),
      TestContentRepository(const [], shopItems: items),
    );
    await reopenedService.useItem(
      profileId: profileId,
      periodId: period.id!,
      itemId: apple.id,
      operationId: 'restart-replay',
    );
    expect(await reopenedGames.getInventoryQuantity(profileId, apple.id), 2);
    expect((await reopenedGames.getPet(profileId))?.satiety, 44);
    expect((await reopenedGames.getPet(profileId))?.care, 60);
    expect(
      await reopenedGames.getPetDailyUsageCount(
        profileId: profileId,
        periodId: period.id!,
        actionId: 'item:${apple.id}',
        slot: PetActionSlot.defaultSlot,
      ),
      1,
    );
    await expectLater(
      reopenedService.useItem(
        profileId: profileId,
        periodId: period.id!,
        itemId: comb.id,
        operationId: 'comb-after-restart',
      ),
      throwsA(isA<PetActionAlreadyUsedException>()),
    );
    await expectLater(
      reopenedService.performFreeInteraction(
        profileId: profileId,
        periodId: period.id!,
        interaction: FreePetInteraction.pet,
        operationId: 'pet-after-restart',
      ),
      throwsA(isA<PetActionAlreadyUsedException>()),
    );
  });
}
