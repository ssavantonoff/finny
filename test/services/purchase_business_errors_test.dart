import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/purchase_exception.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/budget_service.dart';
import 'package:finny/services/period_service.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

const consumableItem = ShopItem(
  id: 'test_food',
  name: 'Еда',
  category: ShopItemCategory.need,
  price: 150,
  persistent: false,
  effectType: 'satiety',
  effectValue: 10,
  unlockType: 'available',
);

const persistentItem = ShopItem(
  id: 'test_ball',
  name: 'Мяч',
  category: ShopItemCategory.want,
  price: 120,
  persistent: true,
  effectType: 'mood',
  effectValue: 8,
  unlockType: 'available',
);

const expensiveItem = ShopItem(
  id: 'test_expensive',
  name: 'Дорогая вещь',
  category: ShopItemCategory.want,
  price: 600,
  persistent: true,
  effectType: 'mood',
  effectValue: 1,
  unlockType: 'available',
);

void main() {
  late AppDatabase database;
  late SqliteProfileRepository profiles;
  late SqliteGameRepository games;
  late PeriodService periods;
  late BudgetService budgets;
  late PurchaseService purchases;

  setUp(() {
    database = createTestDatabase();
    profiles = SqliteProfileRepository(database);
    games = SqliteGameRepository(database);
    final content = TestContentRepository(
      testPeriodDefinitions(count: 1),
      shopItems: const [consumableItem, persistentItem, expensiveItem],
    );
    periods = PeriodService(games, content);
    budgets = BudgetService(games);
    purchases = PurchaseService(SqlitePurchasePort(database), content);
  });

  tearDown(() => database.close());

  Future<({int profileId, int periodId})> createActivePlayer() async {
    final profile = await profiles.create(
      Profile(
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await games.ensureInitialState(profile.id!);
    final started = await periods.startNextPeriod(profileId: profile.id!);
    final active = await confirmPlanForTest(
      budgets,
      profileId: profile.id!,
      periodId: started!.id!,
    );
    return (profileId: profile.id!, periodId: active.id!);
  }

  test(
    'insufficient funds exposes canonical price and available balance',
    () async {
      final player = await createActivePlayer();
      final transactionsBefore = await games.getTransactions(
        player.profileId,
        periodId: player.periodId,
      );

      await expectLater(
        purchases.purchase(
          profileId: player.profileId,
          periodId: player.periodId,
          itemId: expensiveItem.id,
          operationId: 'insufficient',
        ),
        throwsA(
          isA<InsufficientFundsException>()
              .having((error) => error.itemPrice, 'itemPrice', 600)
              .having(
                (error) => error.availableBalance,
                'availableBalance',
                500,
              ),
        ),
      );

      expect((await games.getGameState(player.profileId))?.walletBalance, 500);
      expect(
        await games.getInventoryQuantity(player.profileId, expensiveItem.id),
        0,
      );
      expect(
        await games.getTransactions(
          player.profileId,
          periodId: player.periodId,
        ),
        hasLength(transactionsBefore.length),
      );
    },
  );

  test(
    'persistent purchase replays same operation and rejects a new one',
    () async {
      final player = await createActivePlayer();

      final first = await purchases.purchase(
        profileId: player.profileId,
        periodId: player.periodId,
        itemId: persistentItem.id,
        operationId: 'persistent-first',
      );
      final replay = await purchases.purchase(
        profileId: player.profileId,
        periodId: player.periodId,
        itemId: persistentItem.id,
        operationId: 'persistent-first',
      );

      expect(first.walletBalance, 380);
      expect(replay.walletBalance, 380);
      expect(
        await games.getInventoryQuantity(player.profileId, persistentItem.id),
        1,
      );
      expect(
        await games.getTransactions(
          player.profileId,
          periodId: player.periodId,
        ),
        hasLength(2),
      );

      await expectLater(
        purchases.purchase(
          profileId: player.profileId,
          periodId: player.periodId,
          itemId: persistentItem.id,
          operationId: 'persistent-second',
        ),
        throwsA(
          isA<PersistentItemAlreadyOwnedException>().having(
            (error) => error.itemId,
            'itemId',
            persistentItem.id,
          ),
        ),
      );

      expect((await games.getGameState(player.profileId))?.walletBalance, 380);
      expect(
        await games.getInventoryQuantity(player.profileId, persistentItem.id),
        1,
      );
      expect(
        await games.getTransactions(
          player.profileId,
          periodId: player.periodId,
        ),
        hasLength(2),
      );
    },
  );

  test('consumable items can be purchased repeatedly', () async {
    final player = await createActivePlayer();

    await purchases.purchase(
      profileId: player.profileId,
      periodId: player.periodId,
      itemId: consumableItem.id,
      operationId: 'consumable-first',
    );
    await purchases.purchase(
      profileId: player.profileId,
      periodId: player.periodId,
      itemId: consumableItem.id,
      operationId: 'consumable-second',
    );

    expect((await games.getGameState(player.profileId))?.walletBalance, 200);
    expect(
      await games.getInventoryQuantity(player.profileId, consumableItem.id),
      2,
    );
    expect(
      await games.getTransactions(player.profileId, periodId: player.periodId),
      hasLength(3),
    );
  });

  test('concurrent persistent purchases allow exactly one success', () async {
    final player = await createActivePlayer();

    Future<Object> attempt(String operationId) async {
      try {
        return await purchases.purchase(
          profileId: player.profileId,
          periodId: player.periodId,
          itemId: persistentItem.id,
          operationId: operationId,
        );
      } catch (error) {
        return error;
      }
    }

    final results = await Future.wait([
      attempt('concurrent-a'),
      attempt('concurrent-b'),
    ]);

    expect(results.whereType<GameState>(), hasLength(1));
    expect(
      results.whereType<PersistentItemAlreadyOwnedException>(),
      hasLength(1),
    );
    expect((await games.getGameState(player.profileId))?.walletBalance, 380);
    expect(
      await games.getInventoryQuantity(player.profileId, persistentItem.id),
      1,
    );
    expect(
      await games.getTransactions(player.profileId, periodId: player.periodId),
      hasLength(2),
    );
  });
}
