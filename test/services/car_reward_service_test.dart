import 'package:finny/core/database/app_database.dart';
import 'package:finny/features/minigames/car/car_session.dart';
import 'package:finny/models/car_reward.dart';
import 'package:finny/models/ball_reward.dart';
import 'package:finny/models/frisbee_reward.dart';
import 'package:finny/models/content_entry.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/campaign_lifecycle_repository.dart';
import 'package:finny/repositories/free_play_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/car_reward_service.dart';
import 'package:finny/services/free_play_service.dart';
import 'package:finny/services/item_use_service.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

const car = ShopItem(
  id: 'toy_plush',
  name: 'Машинка',
  category: ShopItemCategory.want,
  price: 160,
  persistent: true,
  effectType: 'mood',
  effectValue: 30,
  unlockType: 'available',
  displaySection: ShopDisplaySection.toys,
  usagePolicy: ItemUsagePolicy.oncePerPeriod,
);

const forgedCar = ShopItem(
  id: 'toy_plush',
  name: 'Машинка',
  category: ShopItemCategory.want,
  price: 160,
  persistent: true,
  effectType: 'mood',
  effectValue: 99,
  unlockType: 'available',
  displaySection: ShopDisplaySection.toys,
  usagePolicy: ItemUsagePolicy.oncePerPeriod,
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

final days = [
  for (var day = 1; day <= 5; day++)
    PeriodDefinition(
      id: 'period_$day',
      number: day,
      title: 'День $day',
      baseIncome: 500,
      requiredCheckpoints: const [],
    ),
];

CarSession completedSession(String id) {
  final session = CarSession(seed: 7, sessionId: id)..start();
  session.advance(const Duration(seconds: 20));
  if (!session.canSubmitReward) throw StateError('Fixture did not complete.');
  return session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late SqliteGameRepository games;
  late CampaignLifecycleRepository lifecycle;
  late TestContentRepository content;
  late CarRewardService rewards;
  late SqliteProfileRepository profiles;
  int? activeProfileId;

  void rebuildService() {
    rewards = CarRewardService(
      content,
      games,
      lifecycle,
      SqliteCarRewardPort(database, content),
      FreePlayRepository(database, canonicalContent: content),
      () => activeProfileId,
    );
  }

  setUp(() {
    database = createTestDatabase();
    games = SqliteGameRepository(database);
    profiles = SqliteProfileRepository(database);
    lifecycle = CampaignLifecycleRepository(database);
    content = TestContentRepository(days, shopItems: [car]);
    activeProfileId = null;
    rebuildService();
  });
  tearDown(() => database.close());

  Future<({int profileId, int? periodId})> player({
    int mood = 40,
    bool owned = true,
    bool freePlay = false,
    ProfileType profileType = ProfileType.normal,
  }) async {
    final profile = await profiles.create(
      Profile(
        gameName: 'Игрок',
        profileType: profileType,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 9, 25),
      ),
    );
    final id = profile.id!;
    activeProfileId = id;
    await games.ensureInitialState(id);
    await games.savePet(
      Pet(
        profileId: id,
        name: 'Финни',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 1,
        growthPoints: 0,
        satiety: 50,
        care: 50,
        mood: mood,
      ),
    );
    final db = await database.database;
    await db.update(
      'game_states',
      {'wallet_balance': 200},
      where: 'profile_id = ?',
      whereArgs: [id],
    );
    if (owned) {
      await db.insert('inventory', {
        'profile_id': id,
        'item_id': car.id,
        'quantity': 1,
        'acquired_at': DateTime.utc(2026, 9, 25).toIso8601String(),
      });
    }
    if (freePlay) {
      for (var day = 1; day <= 5; day++) {
        await db.insert('game_periods', {
          'profile_id': id,
          'definition_id': 'period_$day',
          'period_number': day,
          'start_wallet_balance': 200,
          'status': 'completed',
          'created_at': DateTime.utc(2026, 9, 25).toIso8601String(),
          'completed_at': DateTime.utc(2026, 9, 25).toIso8601String(),
          'end_wallet_balance': 200,
        });
      }
      await lifecycle.startFreePlay(id, days);
      return (profileId: id, periodId: null);
    }
    final planning = await games.startPeriod(
      profileId: id,
      definitionId: 'period_1',
      periodNumber: 1,
      baseIncome: 0,
      requiredCheckpoints: const [],
      createdAt: DateTime.utc(2026, 9, 25),
    );
    final period = await confirmBudgetForTest(
      games,
      profileId: id,
      periodId: planning.id!,
    );
    return (profileId: id, periodId: period.id);
  }

  test(
    'incomplete and aborted sessions cannot mutate Campaign state',
    () async {
      final p = await player();
      final access = await rewards.checkAccess(profileId: p.profileId);
      final before = await games.getPet(p.profileId);
      final session = CarSession(seed: 1, sessionId: 'incomplete')..start();
      await expectLater(
        rewards.completeSession(access: access, session: session),
        throwsStateError,
      );
      session.abort();
      await expectLater(
        rewards.completeSession(access: access, session: session),
        throwsStateError,
      );
      expect((await games.getPet(p.profileId))!.mood, before!.mood);
      expect(
        await games.getPetDailyUsageCount(
          profileId: p.profileId,
          periodId: p.periodId!,
          actionId: 'item:toy_plush',
          slot: PetActionSlot.defaultSlot,
        ),
        0,
      );
    },
  );

  test('buying and opening Car do not grant gameplay mood', () async {
    final p = await player(owned: false);
    final beforeMood = (await games.getPet(p.profileId))!.mood;
    await PurchaseService(SqlitePurchasePort(database), content).purchase(
      profileId: p.profileId,
      periodId: p.periodId!,
      itemId: car.id,
      operationId: 'purchase-car',
    );
    expect(await games.getInventoryQuantity(p.profileId, car.id), 1);
    expect((await games.getPet(p.profileId))!.mood, beforeMood);
    await rewards.checkAccess(profileId: p.profileId);
    expect((await games.getPet(p.profileId))!.mood, beforeMood);
  });

  test(
    'Campaign applies canonical mood once, then replay remains playable',
    () async {
      final p = await player();
      final access = await rewards.checkAccess(profileId: p.profileId);
      expect(access.mode, CarGameMode.campaign);
      final initialWallet = (await games.getGameState(p.profileId))!
          .walletBalance;
      final initialTransactions = await games.getTransactions(p.profileId);
      final first = await rewards.completeSession(
        access: access,
        session: completedSession('campaign-1'),
      );
      expect(first.status, CarRewardStatus.applied);
      expect(first.canonicalMoodEffect, car.petEffects.mood);
      expect(first.actualMoodDelta, car.petEffects.mood);
      expect((await games.getPet(p.profileId))!.mood, 69);
      final secondAccess = await rewards.checkAccess(profileId: p.profileId);
      final second = await rewards.completeSession(
        access: secondAccess,
        session: completedSession('campaign-2'),
      );
      expect(second.status, CarRewardStatus.alreadyRewarded);
      expect(second.actualMoodDelta, 0);
      expect((await games.getPet(p.profileId))!.mood, 69);
      expect(await games.getInventoryQuantity(p.profileId, car.id), 1);
      expect(
        (await games.getGameState(p.profileId))!.walletBalance,
        initialWallet,
      );
      expect(await games.getTransactions(p.profileId), initialTransactions);
      expect(
        await games.getPetDailyUsageCount(
          profileId: p.profileId,
          periodId: p.periodId!,
          actionId: 'item:toy_plush',
          slot: PetActionSlot.defaultSlot,
        ),
        1,
      );
    },
  );

  test(
    'Campaign mood at 100 consumes eligibility despite zero delta',
    () async {
      final p = await player(mood: 100);
      await games.savePet(
        (await games.getPet(p.profileId))!.copyWith(mood: 100),
      );
      final access = await rewards.checkAccess(profileId: p.profileId);
      final capped = await rewards.completeSession(
        access: access,
        session: completedSession('capped'),
      );
      expect(capped.status, CarRewardStatus.capped);
      expect(capped.actualMoodDelta, 0);
      await games.savePet(
        (await games.getPet(p.profileId))!.copyWith(mood: 40),
      );
      final replay = await rewards.completeSession(
        access: await rewards.checkAccess(profileId: p.profileId),
        session: completedSession('capped-replay'),
      );
      expect(replay.status, CarRewardStatus.alreadyRewarded);
      expect((await games.getPet(p.profileId))!.mood, 40);
    },
  );

  test(
    'same completion identity is idempotent, including concurrent retries',
    () async {
      final p = await player();
      final access = await rewards.checkAccess(profileId: p.profileId);
      final session = completedSession('stable-identity');
      final results = await Future.wait([
        rewards.completeSession(access: access, session: session),
        rewards.completeSession(access: access, session: session),
      ]);
      expect(
        results.map((result) => result.status),
        containsAll([
          CarRewardStatus.applied,
          CarRewardStatus.confirmedPreviously,
        ]),
      );
      rebuildService();
      final retry = await rewards.completeSession(
        access: access,
        session: session,
      );
      expect(retry.status, CarRewardStatus.confirmedPreviously);
      expect((await games.getPet(p.profileId))!.mood, 69);
    },
  );

  test(
    'committed Campaign operation can be confirmed after day transition',
    () async {
      final p = await player();
      final access = await rewards.checkAccess(profileId: p.profileId);
      final completed = completedSession('day-transition');
      await rewards.completeSession(access: access, session: completed);
      final db = await database.database;
      await db.update(
        'game_periods',
        {'status': 'completed', 'completed_at': '2026-09-25'},
        where: 'id = ?',
        whereArgs: [p.periodId],
      );
      final confirmed = await rewards.completeSession(
        access: access,
        session: completed,
      );
      expect(confirmed.status, CarRewardStatus.confirmedPreviously);
      await expectLater(
        rewards.completeSession(
          access: access,
          session: completedSession('never-awarded'),
        ),
        throwsStateError,
      );
      expect((await games.getPet(p.profileId))!.mood, 69);
    },
  );

  test('generic Campaign use paths reject Car without mood change', () async {
    final p = await player();
    final service = ItemUseService(SqlitePetActionPort(database), content);
    await expectLater(
      service.useItem(
        profileId: p.profileId,
        periodId: p.periodId!,
        itemId: car.id,
        operationId: 'direct-generic',
      ),
      throwsA(isA<PetItemNotUsableException>()),
    );
    await expectLater(
      SqlitePetActionPort(database).useItem(
        profileId: p.profileId,
        periodId: p.periodId!,
        item: car,
        operationId: 'direct-port',
        slot: PetActionSlot.defaultSlot,
      ),
      throwsA(isA<PetItemNotUsableException>()),
    );
    expect((await games.getPet(p.profileId))!.mood, 39);
  });

  test('Campaign reward port rejects forged Car effects', () async {
    final p = await player();
    await expectLater(
      SqliteCarRewardPort(database, content).completeCar(
        profileId: p.profileId,
        periodId: p.periodId!,
        item: forgedCar,
        operationId: 'toy-car:${p.profileId}:forged-campaign',
        activeProfileMatches: () => activeProfileId == p.profileId,
      ),
      throwsStateError,
    );
    expect((await games.getPet(p.profileId))!.mood, 39);
    expect(
      await games.getPetDailyUsageCount(
        profileId: p.profileId,
        periodId: p.periodId!,
        actionId: 'item:toy_plush',
        slot: PetActionSlot.defaultSlot,
      ),
      0,
    );
  });

  test(
    'ownership and active profile are checked at start and completion',
    () async {
      final p = await player(owned: false);
      await expectLater(
        rewards.checkAccess(profileId: p.profileId),
        throwsA(isA<PetItemNotOwnedException>()),
      );
      final db = await database.database;
      await db.insert('inventory', {
        'profile_id': p.profileId,
        'item_id': car.id,
        'quantity': 1,
        'acquired_at': '2026-09-25',
      });
      final access = await rewards.checkAccess(profileId: p.profileId);
      activeProfileId = null;
      await expectLater(
        rewards.completeSession(
          access: access,
          session: completedSession('switched'),
        ),
        throwsStateError,
      );
      activeProfileId = p.profileId;
      await db.delete(
        'inventory',
        where: 'profile_id = ? AND item_id = ?',
        whereArgs: [p.profileId, car.id],
      );
      await expectLater(
        rewards.completeSession(
          access: access,
          session: completedSession('not-owned-anymore'),
        ),
        throwsA(isA<PetItemNotOwnedException>()),
      );
      expect((await games.getPet(p.profileId))!.mood, 39);
    },
  );

  test(
    'Free Play reward persists across service reconstruction and replay',
    () async {
      final p = await player(freePlay: true);
      final access = await rewards.checkAccess(profileId: p.profileId);
      expect(access.mode, CarGameMode.freePlay);
      final wallet = (await games.getGameState(p.profileId))!.walletBalance;
      final transactions = await games.getTransactions(p.profileId);
      final session = completedSession('free-1');
      final first = await rewards.completeSession(
        access: access,
        session: session,
      );
      expect(first.status, CarRewardStatus.applied);
      expect(first.actualMoodDelta, 30);
      rebuildService();
      final retry = await rewards.completeSession(
        access: access,
        session: session,
      );
      expect(retry.status, CarRewardStatus.confirmedPreviously);
      final replayAccess = await rewards.checkAccess(profileId: p.profileId);
      final replay = await rewards.completeSession(
        access: replayAccess,
        session: completedSession('free-2'),
      );
      expect(replay.status, CarRewardStatus.alreadyRewarded);
      expect((await games.getPet(p.profileId))!.mood, 70);
      expect(await games.getInventoryQuantity(p.profileId, car.id), 1);
      expect((await games.getGameState(p.profileId))!.walletBalance, wallet);
      expect(await games.getTransactions(p.profileId), transactions);
      final db = await database.database;
      expect(
        await db.query(
          'free_play_pet_operations',
          where: 'profile_id = ? AND action_id = ?',
          whereArgs: [p.profileId, 'item:toy_plush'],
        ),
        hasLength(1),
      );
    },
  );

  test('Free Play mood at 100 consumes persistent eligibility', () async {
    final p = await player(mood: 100, freePlay: true);
    final access = await rewards.checkAccess(profileId: p.profileId);
    final capped = await rewards.completeSession(
      access: access,
      session: completedSession('free-capped'),
    );
    expect(capped.status, CarRewardStatus.capped);
    await games.savePet((await games.getPet(p.profileId))!.copyWith(mood: 40));
    rebuildService();
    final replay = await rewards.completeSession(
      access: await rewards.checkAccess(profileId: p.profileId),
      session: completedSession('free-capped-replay'),
    );
    expect(replay.status, CarRewardStatus.alreadyRewarded);
    expect((await games.getPet(p.profileId))!.mood, 40);
  });

  test(
    'generic Free Play use and repository action cannot bypass Car',
    () async {
      final p = await player(freePlay: true);
      final freePlay = FreePlayService(
        FreePlayRepository(database),
        content,
        games,
      );
      await expectLater(
        freePlay.useItem(
          profileId: p.profileId,
          itemId: car.id,
          operationId: 'direct-free',
        ),
        throwsA(isA<PetItemNotUsableException>()),
      );
      await expectLater(
        FreePlayRepository(database).petAction(
          profileId: p.profileId,
          actionId: 'item:toy_plush',
          effects: car.petEffects,
          operationId: 'direct-repository',
          definitions: days,
        ),
        throwsA(isA<PetItemNotUsableException>()),
      );
      expect((await games.getPet(p.profileId))!.mood, 40);
    },
  );

  test('Free Play reward repository rejects forged Car effects', () async {
    final p = await player(freePlay: true);
    await expectLater(
      FreePlayRepository(database, canonicalContent: content).completeCar(
        profileId: p.profileId,
        item: forgedCar,
        operationId: 'toy-car:${p.profileId}:forged-free-play',
        definitions: days,
        activeProfileMatches: () => activeProfileId == p.profileId,
      ),
      throwsStateError,
    );
    expect((await games.getPet(p.profileId))!.mood, 40);
    expect(
      await (await database.database).query(
        'free_play_pet_operations',
        where: 'profile_id = ? AND action_id = ?',
        whereArgs: [p.profileId, 'item:toy_plush'],
      ),
      isEmpty,
    );
  });

  test(
    'Free Play eligibility and ownership stay isolated by profile',
    () async {
      final first = await player(freePlay: true);
      final firstAccess = await rewards.checkAccess(profileId: first.profileId);
      await rewards.completeSession(
        access: firstAccess,
        session: completedSession('first-profile'),
      );
      final second = await player(
        owned: false,
        freePlay: true,
        profileType: ProfileType.demo,
      );
      await expectLater(
        rewards.checkAccess(profileId: second.profileId),
        throwsA(isA<PetItemNotOwnedException>()),
      );
      final db = await database.database;
      await db.insert('inventory', {
        'profile_id': second.profileId,
        'item_id': car.id,
        'quantity': 1,
        'acquired_at': '2026-09-25',
      });
      final secondAccess = await rewards.checkAccess(
        profileId: second.profileId,
      );
      final secondReward = await rewards.completeSession(
        access: secondAccess,
        session: completedSession('second-profile'),
      );
      expect(secondReward.status, CarRewardStatus.applied);
      expect((await games.getPet(second.profileId))!.mood, 70);
      expect((await games.getPet(first.profileId))!.mood, 70);
      await expectLater(
        rewards.completeSession(
          access: firstAccess,
          session: completedSession('wrong-active-profile'),
        ),
        throwsStateError,
      );
    },
  );

  test('Free Play Car, Ball and Frisbee rewards are independent', () async {
    content = TestContentRepository(days, shopItems: [car, ball, frisbee]);
    rebuildService();
    final p = await player(freePlay: true);
    final db = await database.database;
    for (final item in [ball, frisbee]) {
      await db.insert('inventory', {
        'profile_id': p.profileId,
        'item_id': item.id,
        'quantity': 1,
        'acquired_at': '2026-09-25',
      });
    }
    final carResult = await rewards.completeSession(
      access: await rewards.checkAccess(profileId: p.profileId),
      session: completedSession('independent-car'),
    );
    expect(carResult.status, CarRewardStatus.applied);
    final freePlay = FreePlayRepository(database, canonicalContent: content);
    final ballResult = await freePlay.completeBall(
      profileId: p.profileId,
      item: ball,
      operationId: 'toy-ball:${p.profileId}:independent-ball',
      definitions: days,
      activeProfileMatches: () => activeProfileId == p.profileId,
    );
    final frisbeeResult = await freePlay.completeFrisbee(
      profileId: p.profileId,
      item: frisbee,
      operationId: 'toy-frisbee:${p.profileId}:independent-frisbee',
      definitions: days,
      activeProfileMatches: () => activeProfileId == p.profileId,
    );
    expect(ballResult.status, BallRewardStatus.applied);
    expect(frisbeeResult.status, FrisbeeRewardStatus.capped);
    final rows = await db.query(
      'free_play_pet_operations',
      columns: ['action_id'],
      where: 'profile_id = ?',
      whereArgs: [p.profileId],
    );
    expect(
      rows.map((row) => row['action_id']),
      containsAll(['item:toy_plush', 'item:toy_ball', 'item:toy_frisbee']),
    );
  });

  test('canonical mood effect is read from item definition', () async {
    content = TestContentRepository(
      days,
      shopItems: [
        const ShopItem(
          id: 'toy_plush',
          name: 'Машинка',
          category: ShopItemCategory.want,
          price: 160,
          persistent: true,
          effectType: 'mood',
          effectValue: 17,
          unlockType: 'available',
          displaySection: ShopDisplaySection.toys,
          usagePolicy: ItemUsagePolicy.oncePerPeriod,
        ),
      ],
    );
    rebuildService();
    final p = await player();
    final result = await rewards.completeSession(
      access: await rewards.checkAccess(profileId: p.profileId),
      session: completedSession('canonical-17'),
    );
    expect(result.canonicalMoodEffect, 17);
    expect(result.actualMoodDelta, 17);
    expect((await games.getPet(p.profileId))!.mood, 56);
  });
}
