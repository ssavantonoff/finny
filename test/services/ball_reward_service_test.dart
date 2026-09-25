import 'package:finny/core/database/app_database.dart';
import 'package:finny/features/minigames/ball/ball_session.dart';
import 'package:finny/models/ball_reward.dart';
import 'package:finny/models/content_entry.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/campaign_lifecycle_repository.dart';
import 'package:finny/repositories/free_play_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/ball_reward_service.dart';
import 'package:finny/services/free_play_service.dart';
import 'package:finny/services/item_use_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

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

BallSession completedSession(String id) {
  final session = BallSession(seed: 7, sessionId: id);
  session.start();
  session.advance(const Duration(seconds: 30));
  if (!session.canSubmitReward) throw StateError('Fixture did not complete.');
  return session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late SqliteGameRepository games;
  late CampaignLifecycleRepository lifecycle;
  late TestContentRepository content;
  late BallRewardService rewards;
  late SqliteProfileRepository profiles;
  int? activeProfileId;

  void rebuildService() {
    rewards = BallRewardService(
      content,
      games,
      lifecycle,
      SqliteBallRewardPort(database),
      FreePlayRepository(database),
      () => activeProfileId,
    );
  }

  setUp(() {
    database = createTestDatabase();
    games = SqliteGameRepository(database);
    profiles = SqliteProfileRepository(database);
    lifecycle = CampaignLifecycleRepository(database);
    content = TestContentRepository(days, shopItems: [ball]);
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
        'item_id': ball.id,
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
      final session = BallSession(seed: 1, sessionId: 'incomplete')..start();
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
          actionId: 'item:toy_ball',
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
      expect(access.mode, BallGameMode.campaign);
      final initialWallet = (await games.getGameState(p.profileId))!
          .walletBalance;
      final initialTransactions = await games.getTransactions(p.profileId);
      final first = await rewards.completeSession(
        access: access,
        session: completedSession('campaign-1'),
      );
      expect(first.status, BallRewardStatus.applied);
      expect(first.canonicalMoodEffect, ball.petEffects.mood);
      expect(first.actualMoodDelta, ball.petEffects.mood);
      expect((await games.getPet(p.profileId))!.mood, 74);
      final secondAccess = await rewards.checkAccess(profileId: p.profileId);
      final second = await rewards.completeSession(
        access: secondAccess,
        session: completedSession('campaign-2'),
      );
      expect(second.status, BallRewardStatus.alreadyRewarded);
      expect(second.actualMoodDelta, 0);
      expect((await games.getPet(p.profileId))!.mood, 74);
      expect(await games.getInventoryQuantity(p.profileId, ball.id), 1);
      expect(
        (await games.getGameState(p.profileId))!.walletBalance,
        initialWallet,
      );
      expect(await games.getTransactions(p.profileId), initialTransactions);
      expect(
        await games.getPetDailyUsageCount(
          profileId: p.profileId,
          periodId: p.periodId!,
          actionId: 'item:toy_ball',
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
      expect(capped.status, BallRewardStatus.capped);
      expect(capped.actualMoodDelta, 0);
      await games.savePet(
        (await games.getPet(p.profileId))!.copyWith(mood: 40),
      );
      final replay = await rewards.completeSession(
        access: await rewards.checkAccess(profileId: p.profileId),
        session: completedSession('capped-replay'),
      );
      expect(replay.status, BallRewardStatus.alreadyRewarded);
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
          BallRewardStatus.applied,
          BallRewardStatus.confirmedPreviously,
        ]),
      );
      rebuildService();
      final retry = await rewards.completeSession(
        access: access,
        session: session,
      );
      expect(retry.status, BallRewardStatus.confirmedPreviously);
      expect((await games.getPet(p.profileId))!.mood, 74);
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
      expect(confirmed.status, BallRewardStatus.confirmedPreviously);
      await expectLater(
        rewards.completeSession(
          access: access,
          session: completedSession('never-awarded'),
        ),
        throwsStateError,
      );
      expect((await games.getPet(p.profileId))!.mood, 74);
    },
  );

  test('generic Campaign use paths reject Ball without mood change', () async {
    final p = await player();
    final service = ItemUseService(SqlitePetActionPort(database), content);
    await expectLater(
      service.useItem(
        profileId: p.profileId,
        periodId: p.periodId!,
        itemId: ball.id,
        operationId: 'direct-generic',
      ),
      throwsA(isA<PetItemNotUsableException>()),
    );
    await expectLater(
      SqlitePetActionPort(database).useItem(
        profileId: p.profileId,
        periodId: p.periodId!,
        item: ball,
        operationId: 'direct-port',
        slot: PetActionSlot.defaultSlot,
      ),
      throwsA(isA<PetItemNotUsableException>()),
    );
    expect((await games.getPet(p.profileId))!.mood, 39);
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
        'item_id': ball.id,
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
        whereArgs: [p.profileId, ball.id],
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
      expect(access.mode, BallGameMode.freePlay);
      final wallet = (await games.getGameState(p.profileId))!.walletBalance;
      final transactions = await games.getTransactions(p.profileId);
      final session = completedSession('free-1');
      final first = await rewards.completeSession(
        access: access,
        session: session,
      );
      expect(first.status, BallRewardStatus.applied);
      expect(first.actualMoodDelta, 35);
      rebuildService();
      final retry = await rewards.completeSession(
        access: access,
        session: session,
      );
      expect(retry.status, BallRewardStatus.confirmedPreviously);
      final replayAccess = await rewards.checkAccess(profileId: p.profileId);
      final replay = await rewards.completeSession(
        access: replayAccess,
        session: completedSession('free-2'),
      );
      expect(replay.status, BallRewardStatus.alreadyRewarded);
      expect((await games.getPet(p.profileId))!.mood, 75);
      expect(await games.getInventoryQuantity(p.profileId, ball.id), 1);
      expect((await games.getGameState(p.profileId))!.walletBalance, wallet);
      expect(await games.getTransactions(p.profileId), transactions);
      final db = await database.database;
      expect(
        await db.query(
          'free_play_pet_operations',
          where: 'profile_id = ? AND action_id = ?',
          whereArgs: [p.profileId, 'item:toy_ball'],
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
    expect(capped.status, BallRewardStatus.capped);
    await games.savePet((await games.getPet(p.profileId))!.copyWith(mood: 40));
    rebuildService();
    final replay = await rewards.completeSession(
      access: await rewards.checkAccess(profileId: p.profileId),
      session: completedSession('free-capped-replay'),
    );
    expect(replay.status, BallRewardStatus.alreadyRewarded);
    expect((await games.getPet(p.profileId))!.mood, 40);
  });

  test(
    'generic Free Play use and repository action cannot bypass Ball',
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
          itemId: ball.id,
          operationId: 'direct-free',
        ),
        throwsA(isA<PetItemNotUsableException>()),
      );
      await expectLater(
        FreePlayRepository(database).petAction(
          profileId: p.profileId,
          actionId: 'item:toy_ball',
          effects: ball.petEffects,
          operationId: 'direct-repository',
          definitions: days,
        ),
        throwsA(isA<PetItemNotUsableException>()),
      );
      expect((await games.getPet(p.profileId))!.mood, 40);
    },
  );

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
        'item_id': ball.id,
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
      expect(secondReward.status, BallRewardStatus.applied);
      expect((await games.getPet(second.profileId))!.mood, 75);
      expect((await games.getPet(first.profileId))!.mood, 75);
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
          id: 'toy_ball',
          name: 'Мяч',
          category: ShopItemCategory.want,
          price: 120,
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
