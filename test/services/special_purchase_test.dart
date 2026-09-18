import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/purchase_exception.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:finny/services/special_purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

const story = StoryPurchase(
  id: 'day3_bowl_replacement',
  name: 'Новая миска',
  period: 3,
  price: 120,
  category: ShopItemCategory.need,
  checkpoint: 'changed_circumstance',
);
const promotion = ShopPromotion(
  id: 'day4_treat_discount',
  period: 4,
  itemId: 'food_treat',
  promoPrice: 35,
  maxPromoQuantity: 1,
  checkpoint: 'discount_decision',
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

void main() {
  late AppDatabase database;
  late SqliteGameRepository games;
  late SqliteProfileRepository profiles;
  late SpecialPurchaseService specials;
  late PurchaseService standard;

  setUp(() {
    database = createTestDatabase();
    games = SqliteGameRepository(database);
    profiles = SqliteProfileRepository(database);
    final content = TestContentRepository(
      testPeriodDefinitions(count: 5),
      shopItems: const [treat],
      stories: const [story],
      promotions: const [promotion],
    );
    specials = SpecialPurchaseService(
      SqliteSpecialPurchasePort(database),
      content,
    );
    standard = PurchaseService(SqlitePurchasePort(database), content);
  });
  tearDown(() => database.close());

  Future<({int profileId, int periodId})> active(
    int day, {
    ProfileType type = ProfileType.normal,
    int income = 500,
  }) async {
    final profile = await profiles.create(
      Profile(
        gameName: type.name,
        profileType: type,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026),
      ),
    );
    await games.ensureInitialState(profile.id!);
    await games.savePet(
      Pet(
        profileId: profile.id!,
        name: 'Финни',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 0,
        growthPoints: 0,
        satiety: 40,
        care: 40,
        mood: 40,
      ),
    );
    final period = await games.startPeriod(
      profileId: profile.id!,
      definitionId: 'period_$day',
      periodNumber: day,
      baseIncome: income,
      requiredCheckpoints: [
        if (day == 3) 'changed_circumstance',
        if (day == 4) 'discount_decision',
      ],
      createdAt: DateTime.utc(2026),
    );
    await games.confirmBudget(profileId: profile.id!, periodId: period.id!);
    return (profileId: profile.id!, periodId: period.id!);
  }

  Future<List<Map<String, Object?>>> proofs() async =>
      (await database.database).query('period_special_actions');

  Future<void> buyStory(
    ({int profileId, int periodId}) player,
    String operationId,
  ) async {
    await specials.purchaseStory(
      profileId: player.profileId,
      periodId: player.periodId,
      storyPurchaseId: story.id,
      operationId: operationId,
    );
  }

  Future<void> decide(
    ({int profileId, int periodId}) player,
    String operationId, {
    required bool purchase,
  }) async {
    final arguments = (
      profileId: player.profileId,
      periodId: player.periodId,
      promotionId: promotion.id,
      operationId: operationId,
    );
    if (purchase) {
      await specials.buyPromotion(
        profileId: arguments.profileId,
        periodId: arguments.periodId,
        promotionId: arguments.promotionId,
        operationId: arguments.operationId,
      );
    } else {
      await specials.skipPromotion(
        profileId: arguments.profileId,
        periodId: arguments.periodId,
        promotionId: arguments.promotionId,
        operationId: arguments.operationId,
      );
    }
  }

  test('Day 3 charges canonical NEED once, closes checkpoint and replays after completion', () async {
    final player = await active(3);
    await expectLater(
      games.resolveCheckpoint(
        profileId: player.profileId,
        periodId: player.periodId,
        checkpointId: story.checkpoint,
      ),
      throwsStateError,
    );
    await buyStory(player, 'story-one');
    expect((await games.getGameState(player.profileId))!.walletBalance, 380);
    final transactions = await games.getTransactions(player.profileId);
    expect(transactions, hasLength(2));
    expect(
      (
        transactions.last.type,
        transactions.last.amount,
        transactions.last.source,
      ),
      (GameTransactionType.needExpense, -120, 'story_${story.id}'),
    );
    expect(await games.getInventoryQuantity(player.profileId, story.id), 0);
    expect((await games.getPet(player.profileId))!.satiety, 40);
    expect((await proofs()).single['outcome'], 'purchased');
    expect(
      (await games.getPeriodById(
        player.profileId,
        player.periodId,
      ))!.resolvedCheckpoints,
      [story.checkpoint],
    );
    await games.completePeriod(
      profileId: player.profileId,
      periodId: player.periodId,
    );
    await buyStory(player, 'story-one');
    expect((await games.getGameState(player.profileId))!.walletBalance, 380);
    expect(await games.getTransactions(player.profileId), hasLength(2));
    expect(await proofs(), hasLength(1));
    await expectLater(
      buyStory(player, 'story-two'),
      throwsA(isA<SpecialPurchaseAlreadyDecidedException>()),
    );
  });

  test(
    'Day 3 rejects wrong day, foreign profile and low balance without mutation',
    () async {
      final day2 = await active(2, income: 0);
      await expectLater(buyStory(day2, 'wrong-day'), throwsStateError);
      final demo = await active(3, type: ProfileType.demo);
      await expectLater(
        buyStory((
          profileId: day2.profileId,
          periodId: demo.periodId,
        ), 'foreign'),
        throwsStateError,
      );
      final lowBalance = await active(3, type: ProfileType.demo, income: 0);
      await expectLater(
        buyStory(lowBalance, 'low-balance'),
        throwsA(isA<InsufficientFundsException>()),
      );
      expect(
        (await games.getGameState(lowBalance.profileId))!.walletBalance,
        0,
      );
      expect(await proofs(), isEmpty);
    },
  );

  test(
    'Day 3 checkpoint failure rolls back wallet, transaction and proof',
    () async {
      final player = await active(3);
      final db = await database.database;
      await db.execute('''
      CREATE TRIGGER fail_day3_checkpoint BEFORE UPDATE ON game_periods
      WHEN NEW.resolved_checkpoints != OLD.resolved_checkpoints
      BEGIN SELECT RAISE(ABORT, 'forced checkpoint failure'); END
    ''');
      await expectLater(buyStory(player, 'rollback-story'), throwsException);
      expect((await games.getGameState(player.profileId))!.walletBalance, 500);
      expect(await games.getTransactions(player.profileId), hasLength(1));
      expect(await proofs(), isEmpty);
      expect(
        (await games.getPeriodById(
          player.profileId,
          player.periodId,
        ))!.resolvedCheckpoints,
        isEmpty,
      );
    },
  );

  test('Day 4 promo buy charges 35 once; normal treat remains 60', () async {
    final player = await active(4);
    await expectLater(
      games.resolveCheckpoint(
        profileId: player.profileId,
        periodId: player.periodId,
        checkpointId: promotion.checkpoint,
      ),
      throwsStateError,
    );
    await decide(player, 'promo-buy', purchase: true);
    expect((await games.getGameState(player.profileId))!.walletBalance, 465);
    expect(await games.getInventoryQuantity(player.profileId, treat.id), 1);
    expect((await games.getPet(player.profileId))!.satiety, 40);
    expect((await games.getPet(player.profileId))!.mood, 40);
    final transactions = await games.getTransactions(player.profileId);
    expect(
      (transactions.last.type, transactions.last.amount),
      (GameTransactionType.wantExpense, -35),
    );
    expect((await proofs()).single['outcome'], 'purchased');
    expect(
      (await games.getPeriodById(
        player.profileId,
        player.periodId,
      ))!.resolvedCheckpoints,
      [promotion.checkpoint],
    );
    await games.completePeriod(
      profileId: player.profileId,
      periodId: player.periodId,
    );
    await decide(player, 'promo-buy', purchase: true);
    expect(await games.getInventoryQuantity(player.profileId, treat.id), 1);
    await expectLater(
      decide(player, 'promo-again', purchase: true),
      throwsA(isA<SpecialPurchaseAlreadyDecidedException>()),
    );
    await expectLater(
      decide(player, 'promo-buy', purchase: false),
      throwsA(isA<SpecialPurchaseConflictException>()),
    );
    await expectLater(
      decide(player, 'promo-skip-new', purchase: false),
      throwsA(isA<SpecialPurchaseAlreadyDecidedException>()),
    );
    // Standard Shop purchase remains independent of the one-time promotion.
    // A completed period rejects new purchases, so use a fresh active player.
    final another = await active(4, type: ProfileType.demo);
    await decide(another, 'demo-promo', purchase: true);
    await standard.purchase(
      profileId: another.profileId,
      periodId: another.periodId,
      itemId: treat.id,
      operationId: 'normal-treat',
    );
    expect((await games.getGameState(another.profileId))!.walletBalance, 405);
    expect(await games.getInventoryQuantity(another.profileId, treat.id), 2);
    expect((await games.getGameState(player.profileId))!.walletBalance, 465);
  });

  test(
    'Day 4 skip leaves money and inventory, blocks promo, allows normal treat',
    () async {
      final player = await active(4);
      await decide(player, 'promo-skip', purchase: false);
      expect((await games.getGameState(player.profileId))!.walletBalance, 500);
      expect(await games.getInventoryQuantity(player.profileId, treat.id), 0);
      expect((await proofs()).single['outcome'], 'skipped');
      await decide(player, 'promo-skip', purchase: false);
      expect(await proofs(), hasLength(1));
      await expectLater(
        decide(player, 'promo-skip', purchase: true),
        throwsA(isA<SpecialPurchaseConflictException>()),
      );
      await expectLater(
        decide(player, 'new-buy', purchase: true),
        throwsA(isA<SpecialPurchaseAlreadyDecidedException>()),
      );
      await standard.purchase(
        profileId: player.profileId,
        periodId: player.periodId,
        itemId: treat.id,
        operationId: 'normal-after-skip',
      );
      expect((await games.getGameState(player.profileId))!.walletBalance, 440);
      expect(await games.getInventoryQuantity(player.profileId, treat.id), 1);
    },
  );

  test('Day 4 checkpoint failure rolls back debit, inventory, proof and transaction', () async {
    final player = await active(4);
    final db = await database.database;
    await db.execute('''
      CREATE TRIGGER fail_day4_checkpoint BEFORE UPDATE ON game_periods
      WHEN NEW.resolved_checkpoints != OLD.resolved_checkpoints
      BEGIN SELECT RAISE(ABORT, 'forced checkpoint failure'); END
    ''');
    await expectLater(
      decide(player, 'rollback-promo', purchase: true),
      throwsException,
    );
    expect((await games.getGameState(player.profileId))!.walletBalance, 500);
    expect(await games.getTransactions(player.profileId), hasLength(1));
    expect(await games.getInventoryQuantity(player.profileId, treat.id), 0);
    expect(await proofs(), isEmpty);
    expect(
      (await games.getPeriodById(
        player.profileId,
        player.periodId,
      ))!.resolvedCheckpoints,
      isEmpty,
    );
  });

  test('Day 4 rejects wrong period, foreign profile and low balance', () async {
    final day3 = await active(3);
    await expectLater(
      decide(day3, 'wrong-day', purchase: true),
      throwsStateError,
    );
    final demo = await active(4, type: ProfileType.demo, income: 0);
    await expectLater(
      decide(
        (profileId: day3.profileId, periodId: demo.periodId),
        'foreign-promo',
        purchase: true,
      ),
      throwsStateError,
    );
    await expectLater(
      decide(demo, 'low-promo', purchase: true),
      throwsA(isA<InsufficientFundsException>()),
    );
    expect((await games.getGameState(demo.profileId))!.walletBalance, 0);
    expect(await games.getInventoryQuantity(demo.profileId, treat.id), 0);
    expect(await proofs(), isEmpty);
  });

  test(
    'same profile operation ID cannot be reused for a different action',
    () async {
      final player = await active(3);
      await buyStory(player, 'shared-special-operation');
      await games.completePeriod(
        profileId: player.profileId,
        periodId: player.periodId,
      );
      final next = await games.startPeriod(
        profileId: player.profileId,
        definitionId: 'period_4',
        periodNumber: 4,
        baseIncome: 500,
        requiredCheckpoints: const ['discount_decision'],
        createdAt: DateTime.utc(2026, 1, 2),
      );
      await games.confirmBudget(
        profileId: player.profileId,
        periodId: next.id!,
      );
      await expectLater(
        decide(
          (profileId: player.profileId, periodId: next.id!),
          'shared-special-operation',
          purchase: false,
        ),
        throwsA(isA<SpecialPurchaseConflictException>()),
      );
      expect(await proofs(), hasLength(1));
      expect(
        (await games.getPeriodById(
          player.profileId,
          next.id!,
        ))!.resolvedCheckpoints,
        isEmpty,
      );
    },
  );

  test('concurrent Day 4 decisions commit only one outcome', () async {
    final player = await active(4);
    Future<String> attempt(String operationId, bool purchase) async {
      try {
        await decide(player, operationId, purchase: purchase);
        return 'success';
      } on SpecialPurchaseAlreadyDecidedException {
        return 'already-decided';
      }
    }

    final results = await Future.wait([
      attempt('concurrent-buy', true),
      attempt('concurrent-skip', false),
    ]);
    expect(results, containsAll(['success', 'already-decided']));
    expect(await proofs(), hasLength(1));
    final proof = (await proofs()).single;
    final balance = (await games.getGameState(player.profileId))!.walletBalance;
    final quantity = await games.getInventoryQuantity(
      player.profileId,
      treat.id,
    );
    expect((
      balance,
      quantity,
    ), proof['outcome'] == 'purchased' ? (465, 1) : (500, 0));
    expect(
      (await games.getPeriodById(
        player.profileId,
        player.periodId,
      ))!.resolvedCheckpoints,
      [promotion.checkpoint],
    );
  });
}
