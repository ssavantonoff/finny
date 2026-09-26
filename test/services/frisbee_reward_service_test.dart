import 'package:finny/core/database/app_database.dart';
import 'package:finny/features/minigames/frisbee/frisbee_session.dart';
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
import 'package:finny/services/frisbee_reward_service.dart';
import 'package:finny/services/free_play_service.dart';
import 'package:finny/services/item_use_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

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

const forgedFrisbee = ShopItem(
  id: 'toy_frisbee',
  name: 'Фрисби',
  category: ShopItemCategory.want,
  price: 140,
  persistent: true,
  effectType: 'mood',
  effectValue: 99,
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

FrisbeeSession completedSession(String id) {
  final session = FrisbeeSession(seed: 7, sessionId: id);
  session.start();
  for (
    var throwIndex = 0;
    throwIndex < FrisbeeSession.throwCount;
    throwIndex++
  ) {
    final start = Duration(seconds: throwIndex * 3);
    if (!session.beginGesture(1, FrisbeeSession.launchPoint)) {
      throw StateError('Fixture could not start throw $throwIndex.');
    }
    final result = session.releaseGesture(
      1,
      const FrisbeePoint(0.5, 0.25),
      start,
    );
    if (result != FrisbeeGestureResult.launched) {
      throw StateError('Fixture could not launch throw $throwIndex.');
    }
    session.advance(start + const Duration(seconds: 2));
  }
  if (!session.canSubmitReward) throw StateError('Fixture did not complete.');
  return session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late SqliteGameRepository games;
  late CampaignLifecycleRepository lifecycle;
  late TestContentRepository content;
  late FrisbeeRewardService rewards;
  late SqliteProfileRepository profiles;
  int? activeProfileId;

  void rebuildService() {
    rewards = FrisbeeRewardService(
      content,
      games,
      lifecycle,
      SqliteFrisbeeRewardPort(database, content),
      FreePlayRepository(database, canonicalContent: content),
      () => activeProfileId,
    );
  }

  setUp(() {
    database = createTestDatabase();
    games = SqliteGameRepository(database);
    profiles = SqliteProfileRepository(database);
    lifecycle = CampaignLifecycleRepository(database);
    content = TestContentRepository(days, shopItems: [frisbee]);
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
        'item_id': frisbee.id,
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
      final session = FrisbeeSession(seed: 1, sessionId: 'incomplete')..start();
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
          actionId: 'item:toy_frisbee',
          slot: PetActionSlot.defaultSlot,
        ),
        0,
      );
    },
  );

  test(
    'Campaign applies canonical mood once, then replay remains playable',
    () async {
      final p = await player();
      final access = await rewards.checkAccess(profileId: p.profileId);
      expect(access.mode, FrisbeeGameMode.campaign);
      final initialWallet = (await games.getGameState(p.profileId))!
          .walletBalance;
      final initialTransactions = await games.getTransactions(p.profileId);
      final first = await rewards.completeSession(
        access: access,
        session: completedSession('campaign-1'),
      );
      expect(first.status, FrisbeeRewardStatus.applied);
      expect(first.canonicalMoodEffect, frisbee.petEffects.mood);
      expect(first.actualMoodDelta, frisbee.petEffects.mood);
      expect((await games.getPet(p.profileId))!.mood, 79);
      final secondAccess = await rewards.checkAccess(profileId: p.profileId);
      final second = await rewards.completeSession(
        access: secondAccess,
        session: completedSession('campaign-2'),
      );
      expect(second.status, FrisbeeRewardStatus.alreadyRewarded);
      expect(second.actualMoodDelta, 0);
      expect((await games.getPet(p.profileId))!.mood, 79);
      expect(await games.getInventoryQuantity(p.profileId, frisbee.id), 1);
      expect(
        (await games.getGameState(p.profileId))!.walletBalance,
        initialWallet,
      );
      expect(await games.getTransactions(p.profileId), initialTransactions);
      expect(
        await games.getPetDailyUsageCount(
          profileId: p.profileId,
          periodId: p.periodId!,
          actionId: 'item:toy_frisbee',
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
      expect(capped.status, FrisbeeRewardStatus.capped);
      expect(capped.actualMoodDelta, 0);
      await games.savePet(
        (await games.getPet(p.profileId))!.copyWith(mood: 40),
      );
      final replay = await rewards.completeSession(
        access: await rewards.checkAccess(profileId: p.profileId),
        session: completedSession('capped-replay'),
      );
      expect(replay.status, FrisbeeRewardStatus.alreadyRewarded);
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
          FrisbeeRewardStatus.applied,
          FrisbeeRewardStatus.confirmedPreviously,
        ]),
      );
      rebuildService();
      final retry = await rewards.completeSession(
        access: access,
        session: session,
      );
      expect(retry.status, FrisbeeRewardStatus.confirmedPreviously);
      expect((await games.getPet(p.profileId))!.mood, 79);
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
      expect(confirmed.status, FrisbeeRewardStatus.confirmedPreviously);
      await expectLater(
        rewards.completeSession(
          access: access,
          session: completedSession('never-awarded'),
        ),
        throwsStateError,
      );
      expect((await games.getPet(p.profileId))!.mood, 79);
    },
  );

  test(
    'generic Campaign use paths reject Frisbee without mood change',
    () async {
      final p = await player();
      final service = ItemUseService(SqlitePetActionPort(database), content);
      await expectLater(
        service.useItem(
          profileId: p.profileId,
          periodId: p.periodId!,
          itemId: frisbee.id,
          operationId: 'direct-generic',
        ),
        throwsA(isA<PetItemNotUsableException>()),
      );
      await expectLater(
        SqlitePetActionPort(database).useItem(
          profileId: p.profileId,
          periodId: p.periodId!,
          item: frisbee,
          operationId: 'direct-port',
          slot: PetActionSlot.defaultSlot,
        ),
        throwsA(isA<PetItemNotUsableException>()),
      );
      expect((await games.getPet(p.profileId))!.mood, 39);
    },
  );

  test('Campaign reward port rejects forged Frisbee effects', () async {
    final p = await player();
    await expectLater(
      SqliteFrisbeeRewardPort(database, content).completeFrisbee(
        profileId: p.profileId,
        periodId: p.periodId!,
        item: forgedFrisbee,
        operationId: 'toy-frisbee:${p.profileId}:forged-campaign',
        activeProfileMatches: () => activeProfileId == p.profileId,
      ),
      throwsStateError,
    );
    expect((await games.getPet(p.profileId))!.mood, 39);
    expect(
      await games.getPetDailyUsageCount(
        profileId: p.profileId,
        periodId: p.periodId!,
        actionId: 'item:toy_frisbee',
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
        'item_id': frisbee.id,
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
        whereArgs: [p.profileId, frisbee.id],
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
      expect(access.mode, FrisbeeGameMode.freePlay);
      final wallet = (await games.getGameState(p.profileId))!.walletBalance;
      final transactions = await games.getTransactions(p.profileId);
      final session = completedSession('free-1');
      final first = await rewards.completeSession(
        access: access,
        session: session,
      );
      expect(first.status, FrisbeeRewardStatus.applied);
      expect(first.actualMoodDelta, 40);
      rebuildService();
      final retry = await rewards.completeSession(
        access: access,
        session: session,
      );
      expect(retry.status, FrisbeeRewardStatus.confirmedPreviously);
      final replayAccess = await rewards.checkAccess(profileId: p.profileId);
      final replay = await rewards.completeSession(
        access: replayAccess,
        session: completedSession('free-2'),
      );
      expect(replay.status, FrisbeeRewardStatus.alreadyRewarded);
      expect((await games.getPet(p.profileId))!.mood, 80);
      expect(await games.getInventoryQuantity(p.profileId, frisbee.id), 1);
      expect((await games.getGameState(p.profileId))!.walletBalance, wallet);
      expect(await games.getTransactions(p.profileId), transactions);
      final db = await database.database;
      expect(
        await db.query(
          'free_play_pet_operations',
          where: 'profile_id = ? AND action_id = ?',
          whereArgs: [p.profileId, 'item:toy_frisbee'],
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
    expect(capped.status, FrisbeeRewardStatus.capped);
    await games.savePet((await games.getPet(p.profileId))!.copyWith(mood: 40));
    rebuildService();
    final replay = await rewards.completeSession(
      access: await rewards.checkAccess(profileId: p.profileId),
      session: completedSession('free-capped-replay'),
    );
    expect(replay.status, FrisbeeRewardStatus.alreadyRewarded);
    expect((await games.getPet(p.profileId))!.mood, 40);
  });

  test(
    'generic Free Play use and repository action cannot bypass Frisbee',
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
          itemId: frisbee.id,
          operationId: 'direct-free',
        ),
        throwsA(isA<PetItemNotUsableException>()),
      );
      await expectLater(
        FreePlayRepository(database).petAction(
          profileId: p.profileId,
          actionId: 'item:toy_frisbee',
          effects: frisbee.petEffects,
          operationId: 'direct-repository',
          definitions: days,
        ),
        throwsA(isA<PetItemNotUsableException>()),
      );
      expect((await games.getPet(p.profileId))!.mood, 40);
    },
  );

  test('Free Play reward repository rejects forged Frisbee effects', () async {
    final p = await player(freePlay: true);
    await expectLater(
      FreePlayRepository(database, canonicalContent: content).completeFrisbee(
        profileId: p.profileId,
        item: forgedFrisbee,
        operationId: 'toy-frisbee:${p.profileId}:forged-free-play',
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
        whereArgs: [p.profileId, 'item:toy_frisbee'],
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
        'item_id': frisbee.id,
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
      expect(secondReward.status, FrisbeeRewardStatus.applied);
      expect((await games.getPet(second.profileId))!.mood, 80);
      expect((await games.getPet(first.profileId))!.mood, 80);
      await expectLater(
        rewards.completeSession(
          access: firstAccess,
          session: completedSession('wrong-active-profile'),
        ),
        throwsStateError,
      );
    },
  );

  test('canonical mood effect is read from item definition', () async {
    content = TestContentRepository(
      days,
      shopItems: [
        const ShopItem(
          id: 'toy_frisbee',
          name: 'Фрисби',
          category: ShopItemCategory.want,
          price: 140,
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
