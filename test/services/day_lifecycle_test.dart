import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/day_lifecycle.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/active_gameplay_tracker.dart';
import 'package:finny/services/day_lifecycle_service.dart';
import 'package:finny/services/period_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

const _apple = ShopItem(
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

const _shampoo = ShopItem(
  id: 'care_shampoo',
  name: 'Шампунь',
  category: ShopItemCategory.need,
  price: 60,
  persistent: false,
  effectType: 'care',
  effectValue: 40,
  unlockType: 'available',
  usagePolicy: ItemUsagePolicy.unlimited,
);

const _comb = ShopItem(
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

const _toothbrush = ShopItem(
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

const _accessory = ShopItem(
  id: 'accessory_hat',
  name: 'Шапочка',
  category: ShopItemCategory.want,
  price: 1,
  persistent: true,
  effectType: 'none',
  effectValue: 0,
  unlockType: 'available',
  displaySection: ShopDisplaySection.accessories,
  equipSlot: ShopEquipSlot.head,
);

const _items = [_apple, _shampoo, _comb, _toothbrush, _accessory];

typedef _Player = ({int profileId, GamePeriod period});

void main() {
  late AppDatabase database;
  late SqliteProfileRepository profiles;
  late SqliteGameRepository games;
  late DayLifecycleService lifecycle;
  var playerSequence = 0;

  setUp(() {
    database = createTestDatabase();
    profiles = SqliteProfileRepository(database);
    games = SqliteGameRepository(database);
    playerSequence = 0;
    lifecycle = DayLifecycleService(
      SqliteDayLifecyclePort(database),
      TestContentRepository(const [], shopItems: _items),
    );
  });

  tearDown(() => database.close());

  Future<_Player> createPlayer({
    int satiety = 70,
    int care = 70,
    int mood = 70,
    int wallet = 0,
    int periodNumber = 1,
    bool resolveCheckpoints = true,
  }) async {
    final profileDraft = Profile(
      gameName: 'Player ${++playerSequence}',
      profileType: ProfileType.normal,
      onboardingCompleted: true,
      createdAt: DateTime.utc(2026),
    );
    final Profile profile;
    if (playerSequence == 1) {
      profile = await profiles.create(profileDraft);
    } else {
      final db = await database.database;
      profile = profileDraft.copyWith(
        id: await db.insert('profiles', profileDraft.toMap()),
      );
    }
    await games.createInitialState(
      GameState(
        profileId: profile.id!,
        walletBalance: wallet,
        currentPeriod: 0,
        savedAmount: 0,
        updatedAt: DateTime.utc(2026),
      ),
    );
    await games.savePet(
      Pet(
        profileId: profile.id!,
        name: 'Финни',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 1,
        growthPoints: 0,
        satiety: satiety,
        care: care,
        mood: mood,
      ),
    );
    var period = await games.startPeriod(
      profileId: profile.id!,
      definitionId: 'period_$periodNumber',
      periodNumber: periodNumber,
      baseIncome: 0,
      requiredCheckpoints: const ['savings_decision'],
      createdAt: DateTime.utc(2026, 1, periodNumber),
    );
    period = await games.confirmBudget(
      profileId: profile.id!,
      periodId: period.id!,
    );
    if (resolveCheckpoints) {
      period = await games.resolveCheckpoint(
        profileId: profile.id!,
        periodId: period.id!,
        checkpointId: 'savings_decision',
      );
    }
    return (profileId: profile.id!, period: period);
  }

  Future<void> grant(int profileId, ShopItem item, {int quantity = 1}) async {
    final db = await database.database;
    await db.insert('inventory', {
      'profile_id': profileId,
      'item_id': item.id,
      'quantity': quantity,
      'acquired_at': DateTime.utc(2026).toIso8601String(),
    });
  }

  Future<void> markUsed(
    _Player player,
    String actionId, {
    PetActionSlot slot = PetActionSlot.defaultSlot,
  }) async {
    final db = await database.database;
    await db.insert('pet_daily_usage', {
      'profile_id': player.profileId,
      'period_id': player.period.id,
      'action_id': actionId,
      'usage_slot': slot.storageValue,
      'usage_count': 1,
      'updated_at': DateTime.utc(2026).toIso8601String(),
    });
  }

  test('green pet sleeps atomically and stores ending wallet', () async {
    final player = await createPlayer(wallet: 135);

    final decision = await lifecycle.evaluateBedtime(
      profileId: player.profileId,
      periodId: player.period.id!,
    );
    expect(decision.type, BedtimeDecisionType.ready);

    final result = await lifecycle.sleep(
      profileId: player.profileId,
      periodId: player.period.id!,
      allowFallback: false,
    );
    expect(result.period.status, GamePeriodStatus.completed);
    expect(result.period.endWalletBalance, 135);
    expect(result.pet.developmentStage, 1);
    expect(result.pet.growthPoints, 0);
  });

  test('checkpoints always block normal and fallback sleep', () async {
    final green = await createPlayer(resolveCheckpoints: false);
    expect(
      (await lifecycle.evaluateBedtime(
        profileId: green.profileId,
        periodId: green.period.id!,
      )).type,
      BedtimeDecisionType.blockedByCheckpoints,
    );

    final impossible = await createPlayer(
      satiety: 0,
      care: 0,
      mood: 0,
      resolveCheckpoints: false,
    );
    final decision = await lifecycle.evaluateBedtime(
      profileId: impossible.profileId,
      periodId: impossible.period.id!,
    );
    expect(decision.type, BedtimeDecisionType.blockedByCheckpoints);
    await expectLater(
      lifecycle.sleep(
        profileId: impossible.profileId,
        periodId: impossible.period.id!,
        allowFallback: true,
      ),
      throwsA(isA<BedtimeNotAllowedException>()),
    );
  });

  test(
    'owned consumables and unused persistent items make care possible',
    () async {
      final consumable = await createPlayer(satiety: 50);
      await grant(consumable.profileId, _apple);
      expect(
        (await lifecycle.evaluateBedtime(
          profileId: consumable.profileId,
          periodId: consumable.period.id!,
        )).type,
        BedtimeDecisionType.carePossible,
      );

      final persistent = await createPlayer(care: 50);
      await grant(persistent.profileId, _comb);
      expect(
        (await lifecycle.evaluateBedtime(
          profileId: persistent.profileId,
          periodId: persistent.period.id!,
        )).type,
        BedtimeDecisionType.carePossible,
      );
      await markUsed(persistent, 'item:${_comb.id}');
      expect(
        (await lifecycle.evaluateBedtime(
          profileId: persistent.profileId,
          periodId: persistent.period.id!,
        )).type,
        BedtimeDecisionType.fallbackAllowed,
      );
    },
  );

  test(
    'toothbrush evening slot and unused free actions are considered',
    () async {
      final brush = await createPlayer(care: 62);
      await grant(brush.profileId, _toothbrush);
      expect(
        (await lifecycle.evaluateBedtime(
          profileId: brush.profileId,
          periodId: brush.period.id!,
        )).type,
        BedtimeDecisionType.carePossible,
      );
      await markUsed(
        brush,
        'item:${_toothbrush.id}',
        slot: PetActionSlot.evening,
      );
      expect(
        (await lifecycle.evaluateBedtime(
          profileId: brush.profileId,
          periodId: brush.period.id!,
        )).type,
        BedtimeDecisionType.fallbackAllowed,
      );

      final free = await createPlayer(mood: 25);
      expect(
        (await lifecycle.evaluateBedtime(
          profileId: free.profileId,
          periodId: free.period.id!,
        )).type,
        BedtimeDecisionType.carePossible,
      );
    },
  );

  test(
    'canonical shop prices respect wallet and accessories are ignored',
    () async {
      final enough = await createPlayer(satiety: 50, wallet: 40);
      expect(
        (await lifecycle.evaluateBedtime(
          profileId: enough.profileId,
          periodId: enough.period.id!,
        )).type,
        BedtimeDecisionType.carePossible,
      );
      final short = await createPlayer(satiety: 50, wallet: 39);
      expect(
        (await lifecycle.evaluateBedtime(
          profileId: short.profileId,
          periodId: short.period.id!,
        )).type,
        BedtimeDecisionType.fallbackAllowed,
      );

      final accessory = await createPlayer(satiety: 0, care: 0, mood: 0);
      await grant(accessory.profileId, _accessory);
      expect(
        (await lifecycle.evaluateBedtime(
          profileId: accessory.profileId,
          periodId: accessory.period.id!,
        )).type,
        BedtimeDecisionType.fallbackAllowed,
      );
    },
  );

  test('fallback rechecks current resources inside the transaction', () async {
    final player = await createPlayer(satiety: 50);
    expect(
      (await lifecycle.evaluateBedtime(
        profileId: player.profileId,
        periodId: player.period.id!,
      )).type,
      BedtimeDecisionType.fallbackAllowed,
    );
    final db = await database.database;
    await db.update(
      'game_states',
      {'wallet_balance': 40},
      where: 'profile_id = ?',
      whereArgs: [player.profileId],
    );

    await expectLater(
      lifecycle.sleep(
        profileId: player.profileId,
        periodId: player.period.id!,
        allowFallback: true,
      ),
      throwsA(
        isA<BedtimeNotAllowedException>().having(
          (error) => error.decision.type,
          'decision',
          BedtimeDecisionType.carePossible,
        ),
      ),
    );
    expect(
      (await games.getPeriodById(player.profileId, player.period.id!))?.status,
      GamePeriodStatus.readyToFinish,
    );
  });

  test('period and stage roll back together when completion fails', () async {
    final player = await createPlayer(periodNumber: 2);
    final db = await database.database;
    await db.execute('''
      CREATE TRIGGER reject_completion
      BEFORE UPDATE OF status ON game_periods
      WHEN NEW.status = 'completed'
      BEGIN
        SELECT RAISE(ABORT, 'forced failure');
      END
    ''');

    await expectLater(
      lifecycle.sleep(
        profileId: player.profileId,
        periodId: player.period.id!,
        allowFallback: false,
      ),
      throwsA(anything),
    );
    expect((await games.getPet(player.profileId))?.developmentStage, 1);
    expect(
      (await games.getPeriodById(player.profileId, player.period.id!))?.status,
      GamePeriodStatus.readyToFinish,
    );
  });

  test(
    'next day applies morning once, preserves carryover, and day 2 grows',
    () async {
      final player = await createPlayer(wallet: 135);
      await lifecycle.sleep(
        profileId: player.profileId,
        periodId: player.period.id!,
        allowFallback: false,
      );
      await games.savePet(
        (await games.getPet(player.profileId))!
            .copyWith(satiety: 80, care: 78, mood: 60),
      );

      var day2 = await games.startPeriod(
        profileId: player.profileId,
        definitionId: 'period_2',
        periodNumber: 2,
        baseIncome: 500,
        requiredCheckpoints: const ['savings_decision'],
        createdAt: DateTime.utc(2026, 1, 2),
      );
      expect(day2.startWalletBalance, 135);
      expect((await games.getGameState(player.profileId))?.walletBalance, 635);
      final morning = await games.getPet(player.profileId);
      expect([morning?.satiety, morning?.care, morning?.mood], [40, 39, 35]);
      await expectLater(
        games.startPeriod(
          profileId: player.profileId,
          definitionId: 'period_2',
          periodNumber: 2,
          baseIncome: 500,
          requiredCheckpoints: const ['savings_decision'],
          createdAt: DateTime.utc(2026, 1, 2),
        ),
        throwsStateError,
      );
      expect((await games.getPet(player.profileId))?.satiety, 40);

      day2 = await games.confirmBudget(
        profileId: player.profileId,
        periodId: day2.id!,
      );
      day2 = await games.resolveCheckpoint(
        profileId: player.profileId,
        periodId: day2.id!,
        checkpointId: 'savings_decision',
      );
      await games.savePet(
        (await games.getPet(player.profileId))!
            .copyWith(satiety: 70, care: 70, mood: 70),
      );
      final completed = await lifecycle.sleep(
        profileId: player.profileId,
        periodId: day2.id!,
        allowFallback: false,
      );
      expect(completed.pet.developmentStage, 2);
      expect(completed.pet.growthPoints, 0);
    },
  );

  test(
    'restart with an existing next period does not repeat morning',
    () async {
      final directory = await Directory.systemTemp.createTemp('finny_morning_');
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
          gameName: 'Restart player',
          profileType: ProfileType.normal,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026),
        ),
      );
      await firstGames.createInitialState(
        GameState(
          profileId: profile.id!,
          walletBalance: 0,
          currentPeriod: 1,
          savedAmount: 0,
          updatedAt: DateTime.utc(2026),
        ),
      );
      await firstGames.savePet(
        Pet(
          profileId: profile.id!,
          name: 'Финни',
          colorId: 'blue',
          patternId: 'plain',
          developmentStage: 1,
          growthPoints: 0,
          satiety: 80,
          care: 78,
          mood: 76,
        ),
      );
      var day1 = await firstGames.startPeriod(
        profileId: profile.id!,
        definitionId: 'period_1',
        periodNumber: 1,
        baseIncome: 0,
        requiredCheckpoints: const ['savings_decision'],
        createdAt: DateTime.utc(2026),
      );
      expect((await firstGames.getPet(profile.id!))?.satiety, 80);
      day1 = await firstGames.confirmBudget(
        profileId: profile.id!,
        periodId: day1.id!,
      );
      day1 = await firstGames.resolveCheckpoint(
        profileId: profile.id!,
        periodId: day1.id!,
        checkpointId: 'savings_decision',
      );
      final firstLifecycle = DayLifecycleService(
        SqliteDayLifecyclePort(firstDatabase),
        TestContentRepository(const [], shopItems: _items),
      );
      await firstLifecycle.sleep(
        profileId: profile.id!,
        periodId: day1.id!,
        allowFallback: false,
      );
      await firstGames.startPeriod(
        profileId: profile.id!,
        definitionId: 'period_2',
        periodNumber: 2,
        baseIncome: 0,
        requiredCheckpoints: const ['savings_decision'],
        createdAt: DateTime.utc(2026, 1, 2),
      );
      final firstMorning = await firstGames.getPet(profile.id!);
      await firstDatabase.close();

      final reopenedDatabase = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(reopenedDatabase.close);
      final reopenedGames = SqliteGameRepository(reopenedDatabase);
      final periods = PeriodService(
        reopenedGames,
        TestContentRepository(testPeriodDefinitions(count: 2)),
      );
      await expectLater(
        periods.startNextPeriod(profileId: profile.id!),
        throwsStateError,
      );
      final afterRestart = await reopenedGames.getPet(profile.id!);
      expect(afterRestart?.satiety, firstMorning?.satiety);
      expect(afterRestart?.care, firstMorning?.care);
      expect(afterRestart?.mood, firstMorning?.mood);
    },
  );

  test('day 5 completion reaches stage 3 without XP', () async {
    final player = await createPlayer(periodNumber: 5);
    final completed = await lifecycle.sleep(
      profileId: player.profileId,
      periodId: player.period.id!,
      allowFallback: false,
    );
    expect(completed.pet.developmentStage, 3);
    expect(completed.pet.growthPoints, 0);
  });

  test(
    'foreground tracker persists active time and excludes background',
    () async {
      final player = await createPlayer();
      var now = DateTime.utc(2026);
      final tracker = ActiveGameplayTracker(
        games,
        () => player.profileId,
        now: () => now,
      );
      tracker.resume();
      now = now.add(const Duration(minutes: 3));
      await tracker.flush();
      var pet = await games.getPet(player.profileId);
      expect([pet?.satiety, pet?.care, pet?.mood], [63, 65, 64]);

      await tracker.pause();
      now = now.add(const Duration(hours: 2));
      tracker.resume();
      now = now.add(const Duration(minutes: 3));
      await tracker.flush();
      pet = await games.getPet(player.profileId);
      expect([pet?.satiety, pet?.care, pet?.mood], [55, 60, 58]);

      now = now.add(const Duration(minutes: 10));
      await tracker.flush();
      pet = await games.getPet(player.profileId);
      expect([pet?.satiety, pet?.care, pet?.mood], [55, 60, 58]);

      await lifecycle.sleep(
        profileId: player.profileId,
        periodId: player.period.id!,
        allowFallback: true,
      );
      now = now.add(const Duration(minutes: 3));
      await tracker.flush();
      pet = await games.getPet(player.profileId);
      expect([pet?.satiety, pet?.care, pet?.mood], [55, 60, 58]);
    },
  );
}
