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
      baseIncome: income == 0 ? 30 : income,
      requiredCheckpoints: [
        if (day == 3) 'changed_circumstance',
        if (day == 4) ...['financial_task', 'savings_decision'],
      ],
      createdAt: DateTime.utc(2026),
    );
    await confirmBudgetForTest(
      games,
      profileId: profile.id!,
      periodId: period.id!,
    );
    if (income == 0) {
      await (await database.database).update(
        'game_states',
        {'wallet_balance': 0},
        where: 'profile_id = ?',
        whereArgs: [profile.id],
      );
    }
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

  Future<void> buyPromotion(
    ({int profileId, int periodId}) player,
    String operationId,
  ) async {
    await specials.purchasePromotion(
      profileId: player.profileId,
      periodId: player.periodId,
      promotionId: promotion.id,
      operationId: operationId,
    );
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
    expect((await games.getPet(player.profileId))!.satiety, 34);
    expect((await proofs()).single['outcome'], 'purchased');
    expect(
      (await games.getPeriodById(
        player.profileId,
        player.periodId,
      ))!.resolvedCheckpoints,
      [story.checkpoint],
    );
    await completePeriodForTest(
      database,
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
    final before = (await games.getPeriodById(
      player.profileId,
      player.periodId,
    ))!;
    await buyPromotion(player, 'promo-buy');
    expect((await games.getGameState(player.profileId))!.walletBalance, 465);
    expect(await games.getInventoryQuantity(player.profileId, treat.id), 1);
    expect((await games.getPet(player.profileId))!.satiety, 34);
    expect((await games.getPet(player.profileId))!.mood, 39);
    final transactions = await games.getTransactions(player.profileId);
    expect(
      (transactions.last.type, transactions.last.amount),
      (GameTransactionType.wantExpense, -35),
    );
    expect((await proofs()).single['outcome'], 'purchased');
    final after = (await games.getPeriodById(
      player.profileId,
      player.periodId,
    ))!;
    expect(after.resolvedCheckpoints, before.resolvedCheckpoints);
    expect(after.dayProgress, before.dayProgress);
    expect(
      await games.getTaskProgress(player.profileId, 'task_shopping_trip_04'),
      isNull,
    );
    expect(after.actualWant, 35);
    expect(
      await specials.loadPromotionState(
        profileId: player.profileId,
        periodId: player.periodId,
        periodNumber: 4,
      ),
      (promotion: promotion, purchased: true),
    );
    await resolveCheckpointForTest(
      database,
      profileId: player.profileId,
      periodId: player.periodId,
      checkpointId: 'financial_task',
    );
    await resolveCheckpointForTest(
      database,
      profileId: player.profileId,
      periodId: player.periodId,
      checkpointId: 'savings_decision',
    );
    await completePeriodForTest(
      database,
      profileId: player.profileId,
      periodId: player.periodId,
    );
    await buyPromotion(player, 'promo-buy');
    expect(await games.getInventoryQuantity(player.profileId, treat.id), 1);
    await expectLater(
      buyPromotion(player, 'promo-again'),
      throwsA(isA<SpecialPurchaseAlreadyDecidedException>()),
    );
    // Standard Shop purchase remains independent of the one-time promotion.
    // A completed period rejects new purchases, so use a fresh active player.
    final another = await active(4, type: ProfileType.demo);
    await buyPromotion(another, 'demo-promo');
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

  test('Day 4 promotion is available before the financial task', () async {
    final player = await active(4);
    final state = await specials.loadPromotionState(
      profileId: player.profileId,
      periodId: player.periodId,
      periodNumber: 4,
    );
    expect(state.promotion?.id, promotion.id);
    expect(state.purchased, isFalse);
    await buyPromotion(player, 'before-task');
    expect(
      await games.getTaskProgress(player.profileId, 'task_shopping_trip_04'),
      isNull,
    );
    expect(
      (await games.getPeriodById(
        player.profileId,
        player.periodId,
      ))!.resolvedCheckpoints,
      isEmpty,
    );
  });

  test(
    'Day 4 proof failure rolls back debit, inventory and transaction',
    () async {
      final player = await active(4);
      final db = await database.database;
      await db.execute('''
      CREATE TRIGGER fail_day4_proof BEFORE INSERT ON period_special_actions
      WHEN NEW.action_id = 'day4_treat_discount'
      BEGIN SELECT RAISE(ABORT, 'forced proof failure'); END
    ''');
      await expectLater(
        buyPromotion(player, 'rollback-promo'),
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
    },
  );

  test('Day 4 rejects wrong period, foreign profile and low balance', () async {
    final day3 = await active(3);
    await expectLater(buyPromotion(day3, 'wrong-day'), throwsStateError);
    final demo = await active(4, type: ProfileType.demo, income: 0);
    await expectLater(
      buyPromotion((
        profileId: day3.profileId,
        periodId: demo.periodId,
      ), 'foreign-promo'),
      throwsStateError,
    );
    await expectLater(
      buyPromotion(demo, 'low-promo'),
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
      await completePeriodForTest(
        database,
        profileId: player.profileId,
        periodId: player.periodId,
      );
      final next = await games.startPeriod(
        profileId: player.profileId,
        definitionId: 'period_4',
        periodNumber: 4,
        baseIncome: 500,
        requiredCheckpoints: const ['financial_task', 'savings_decision'],
        createdAt: DateTime.utc(2026, 1, 2),
      );
      await confirmBudgetForTest(
        games,
        profileId: player.profileId,
        periodId: next.id!,
      );
      await expectLater(
        buyPromotion((
          profileId: player.profileId,
          periodId: next.id!,
        ), 'shared-special-operation'),
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

  test('concurrent Day 4 purchases commit only one promotion', () async {
    final player = await active(4);
    Future<String> attempt(String operationId) async {
      try {
        await buyPromotion(player, operationId);
        return 'success';
      } on SpecialPurchaseAlreadyDecidedException {
        return 'already-decided';
      }
    }

    final results = await Future.wait([
      attempt('concurrent-buy-one'),
      attempt('concurrent-buy-two'),
    ]);
    expect(results, containsAll(['success', 'already-decided']));
    expect(await proofs(), hasLength(1));
    final proof = (await proofs()).single;
    final balance = (await games.getGameState(player.profileId))!.walletBalance;
    final quantity = await games.getInventoryQuantity(
      player.profileId,
      treat.id,
    );
    expect(proof['outcome'], 'purchased');
    expect((balance, quantity), (465, 1));
    expect(
      (await games.getPeriodById(
        player.profileId,
        player.periodId,
      ))!.resolvedCheckpoints,
      isEmpty,
    );
  });
}
