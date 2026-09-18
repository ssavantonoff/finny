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
  usagePolicy: ItemUsagePolicy.oncePerPeriod,
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
  usagePolicy: ItemUsagePolicy.oncePerPeriod,
);

const items = [apple, treat, comb, toothbrush, ball, frisbee];

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
        ? await games.confirmBudget(
            profileId: profileId,
            periodId: planning.id!,
          )
        : planning;
    return (profileId: profileId, period: period);
  }

  Future<void> grant(int profileId, ShopItem item, {int quantity = 1}) async {
    await (await database.database).insert('inventory', {
      'profile_id': profileId,
      'item_id': item.id,
      'quantity': quantity,
      'acquired_at': DateTime.utc(2026, 9, 18).toIso8601String(),
    });
  }

  Future<GamePeriod> startNextPeriod(ActivePlayer player) async {
    await games.resolveCheckpoint(
      profileId: player.profileId,
      periodId: player.period.id!,
      checkpointId: 'done',
    );
    await games.completePeriod(
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
    return games.confirmBudget(
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
    expect((pet?.satiety, pet?.care, pet?.mood), (40, 40, 40));
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
    expect(first.care, 65);
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
    expect((await games.getPet(player.profileId))?.care, 65);

    final next = await startNextPeriod(player);
    final nextUse = await service.useItem(
      profileId: player.profileId,
      periodId: next.id!,
      itemId: comb.id,
      operationId: 'comb-next-day',
    );
    expect(nextUse.care, 90);
    expect(await games.getInventoryQuantity(player.profileId, comb.id), 1);
  });

  test('each toy has its own once-per-period usage identity', () async {
    final player = await createPlayer();
    await grant(player.profileId, ball);
    await grant(player.profileId, frisbee);

    await service.useItem(
      profileId: player.profileId,
      periodId: player.period.id!,
      itemId: ball.id,
      operationId: 'ball-1',
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
        itemId: ball.id,
        operationId: 'ball-2',
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

    await games.resolveCheckpoint(
      profileId: player.profileId,
      periodId: player.period.id!,
      checkpointId: 'done',
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
    final evening = await service.useItem(
      profileId: player.profileId,
      periodId: player.period.id!,
      itemId: toothbrush.id,
      operationId: 'brush-evening',
      slot: PetActionSlot.evening,
    );
    expect(evening.care, 56);
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

  test(
    'free pet and play interactions are independent and once per period',
    () async {
      final player = await createPlayer();

      await service.performFreeInteraction(
        profileId: player.profileId,
        periodId: player.period.id!,
        interaction: FreePetInteraction.pet,
        operationId: 'free-pet',
      );
      final played = await service.performFreeInteraction(
        profileId: player.profileId,
        periodId: player.period.id!,
        interaction: FreePetInteraction.play,
        operationId: 'free-play',
      );
      expect(played.mood, 85);

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
      expect(nextPet.mood, 100);
    },
  );

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
    expect(replay.satiety, 60);
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
      await games.completePeriod(
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
    await grant(normal.profileId, ball);

    await expectLater(
      service.useItem(
        profileId: normal.profileId,
        periodId: demo.period.id!,
        itemId: ball.id,
        operationId: 'foreign-period',
      ),
      throwsStateError,
    );
    expect((await games.getPet(normal.profileId))?.mood, 40);
    expect((await games.getPet(demo.profileId))?.mood, 60);
    expect(await games.getInventoryQuantity(normal.profileId, ball.id), 1);
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
    expect((await games.getPet(player.profileId))?.satiety, 40);
    expect(await games.getInventoryQuantity(player.profileId, apple.id), 1);
    expect(await db.query('pet_daily_usage'), isEmpty);
    expect(await db.query('pet_action_operations'), isEmpty);
  });

  test('concurrent persistent uses allow exactly one new operation', () async {
    final player = await createPlayer();
    await grant(player.profileId, ball);

    Future<Object> attempt(String operationId) async {
      try {
        return await service.useItem(
          profileId: player.profileId,
          periodId: player.period.id!,
          itemId: ball.id,
          operationId: operationId,
        );
      } catch (error) {
        return error;
      }
    }

    final results = await Future.wait([
      attempt('ball-concurrent-a'),
      attempt('ball-concurrent-b'),
    ]);
    expect(results.whereType<Pet>(), hasLength(1));
    expect(results.whereType<PetActionAlreadyUsedException>(), hasLength(1));
    expect((await games.getPet(player.profileId))?.mood, 75);
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
    final period = await firstGames.confirmBudget(
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
    expect((await reopenedGames.getPet(profileId))?.satiety, 60);
    expect((await reopenedGames.getPet(profileId))?.care, 65);
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
