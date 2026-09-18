import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/special_purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_content_repository.dart';

const _story = StoryPurchase(
  id: 'day3_bowl_replacement',
  name: 'Новая миска',
  period: 3,
  price: 120,
  category: ShopItemCategory.need,
  checkpoint: 'changed_circumstance',
);
const _promo = ShopPromotion(
  id: 'day4_treat_discount',
  period: 4,
  itemId: 'food_treat',
  promoPrice: 35,
  maxPromoQuantity: 1,
  checkpoint: 'discount_decision',
);
const _treat = ShopItem(
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
  sqfliteFfiInit();

  for (final decision in <String>['story', 'promo-buy', 'promo-skip']) {
    test(
      '$decision replays from durable proof after DB reopen and completion',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'finny_special_',
        );
        final path = '${directory.path}/finny.sqlite';
        addTearDown(() async {
          if (await directory.exists()) await directory.delete(recursive: true);
        });
        final initial = AppDatabase(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        final content = TestContentRepository(
          testPeriodDefinitions(count: 5),
          shopItems: const [_treat],
          stories: const [_story],
          promotions: const [_promo],
        );
        final games = SqliteGameRepository(initial);
        final profile = await SqliteProfileRepository(initial).create(
          Profile(
            gameName: 'Игрок',
            profileType: ProfileType.normal,
            onboardingCompleted: true,
            createdAt: DateTime.utc(2026),
          ),
        );
        final profileId = profile.id!;
        await games.ensureInitialState(profileId);
        final day = decision == 'story' ? 3 : 4;
        final checkpoint = decision == 'story'
            ? _story.checkpoint
            : _promo.checkpoint;
        final period = await games.startPeriod(
          profileId: profileId,
          definitionId: 'period_$day',
          periodNumber: day,
          baseIncome: 500,
          requiredCheckpoints: [checkpoint],
          createdAt: DateTime.utc(2026),
        );
        final periodId = period.id!;
        await games.confirmBudget(profileId: profileId, periodId: periodId);
        final service = SpecialPurchaseService(
          SqliteSpecialPurchasePort(initial),
          content,
        );
        Future<void> perform(SpecialPurchaseService target) async {
          switch (decision) {
            case 'story':
              await target.purchaseStory(
                profileId: profileId,
                periodId: periodId,
                storyPurchaseId: _story.id,
                operationId: 'same-operation',
              );
              break;
            case 'promo-buy':
              await target.buyPromotion(
                profileId: profileId,
                periodId: periodId,
                promotionId: _promo.id,
                operationId: 'same-operation',
              );
              break;
            case 'promo-skip':
              await target.skipPromotion(
                profileId: profileId,
                periodId: periodId,
                promotionId: _promo.id,
                operationId: 'same-operation',
              );
              break;
          }
        }

        await perform(service);
        await games.completePeriod(profileId: profileId, periodId: periodId);
        final wallet = (await games.getGameState(profileId))!.walletBalance;
        final transactions = await games.getTransactions(profileId);
        final quantity = await games.getInventoryQuantity(profileId, _treat.id);
        await initial.close();

        final reopened = AppDatabase(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        addTearDown(reopened.close);
        final reloadedGames = SqliteGameRepository(reopened);
        await perform(
          SpecialPurchaseService(SqliteSpecialPurchasePort(reopened), content),
        );
        expect(
          (await reloadedGames.getGameState(profileId))!.walletBalance,
          wallet,
        );
        expect(
          await reloadedGames.getTransactions(profileId),
          hasLength(transactions.length),
        );
        expect(
          await reloadedGames.getInventoryQuantity(profileId, _treat.id),
          quantity,
        );
        final proofs = await (await reopened.database).query(
          'period_special_actions',
          where: 'profile_id = ?',
          whereArgs: [profileId],
        );
        expect(proofs, hasLength(1));
        expect(proofs.single['operation_id'], 'same-operation');
        expect(
          (await reloadedGames.getPeriodById(
            profileId,
            periodId,
          ))!.resolvedCheckpoints,
          contains(checkpoint),
        );
      },
    );
  }
}
