import 'dart:io';
import 'dart:math';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/special_purchase_service.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase database;
  late SqliteGameRepository games;
  late SpecialPurchaseService sale;
  late List<ShopItem> catalog;
  late int profileId;
  late int periodId;

  setUp(() async {
    database = createTestDatabase();
    games = SqliteGameRepository(database);
    final content = AssetContentRepository();
    catalog = await content.loadShopItems();
    sale = SpecialPurchaseService(
      SqliteSpecialPurchasePort(database, random: Random(5)),
      content,
    );
    final profile = await SqliteProfileRepository(database).create(
      Profile(
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026),
      ),
    );
    profileId = profile.id!;
    await games.ensureInitialState(profileId);
    final period = await games.startPeriod(
      profileId: profileId,
      definitionId: 'period_5',
      periodNumber: 5,
      baseIncome: 500,
      requiredCheckpoints: const ['financial_task', 'savings_decision'],
      createdAt: DateTime.utc(2026),
    );
    periodId = period.id!;
  });
  tearDown(() => database.close());

  Future<List<DayFiveSaleOffer>> offers() =>
      sale.loadOrCreateDayFiveSale(profileId: profileId, periodId: periodId);

  test(
    'assignment uses canonical shampoo and two unique unowned persistent WANTs',
    () async {
      final all = await offers();
      expect(all, hasLength(3));
      expect(all.map((offer) => offer.itemId).toSet(), hasLength(3));
      expect(
        all
            .singleWhere((offer) => offer.itemId == 'care_shampoo')
            .discountAmount,
        20,
      );
      for (final offer in all.where(
        (offer) => offer.itemId != 'care_shampoo',
      )) {
        final item = catalog.singleWhere((entry) => entry.id == offer.itemId);
        expect(item.category, ShopItemCategory.want);
        expect(item.persistent, isTrue);
        expect(offer.discountAmount, anyOf(10, 20, 30));
        expect(offer.discountAmount, lessThan(item.price));
      }
      expect(
        (await offers())
            .map((offer) => (offer.itemId, offer.discountAmount))
            .toList(),
        all.map((offer) => (offer.itemId, offer.discountAmount)).toList(),
      );
    },
  );

  test('zero or one eligible WANT does not synthesize extra items', () async {
    final port = SqliteSpecialPurchasePort(database, random: Random(1));
    final onlyShampoo = catalog
        .where((item) => item.id == 'care_shampoo')
        .toList();
    final zero = await port.loadOrCreateDayFiveSale(
      profileId: profileId,
      periodId: periodId,
      canonicalItems: onlyShampoo,
    );
    expect(zero.map((offer) => offer.itemId), ['care_shampoo']);
    final second = await SqliteProfileRepository(database).create(
      Profile(
        gameName: 'Второй игрок',
        profileType: ProfileType.demo,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026),
      ),
    );
    await games.ensureInitialState(second.id!);
    final secondPeriod = await games.startPeriod(
      profileId: second.id!,
      definitionId: 'period_5',
      periodNumber: 5,
      baseIncome: 500,
      requiredCheckpoints: const ['financial_task'],
      createdAt: DateTime.utc(2026),
    );
    final one = await port.loadOrCreateDayFiveSale(
      profileId: second.id!,
      periodId: secondPeriod.id!,
      canonicalItems: catalog
          .where((item) => item.id == 'care_shampoo' || item.id == 'toy_ball')
          .toList(),
    );
    expect(one.map((offer) => offer.itemId).toSet(), {
      'care_shampoo',
      'toy_ball',
    });
  });

  test('owned WANTs are excluded when assignment is first generated', () async {
    final db = await database.database;
    for (final item in catalog.where(
      (entry) => entry.category == ShopItemCategory.want && entry.persistent,
    )) {
      await db.insert('inventory', {
        'profile_id': profileId,
        'item_id': item.id,
        'quantity': 1,
        'acquired_at': DateTime.utc(2026).toIso8601String(),
      });
    }
    final assigned = await offers();
    expect(assigned.map((offer) => offer.itemId), ['care_shampoo']);
  });

  test(
    'sale purchase is atomic, retry safe, and keeps canonical expense category',
    () async {
      final all = await offers();
      await confirmBudgetForTest(
        games,
        profileId: profileId,
        periodId: periodId,
      );
      final want = all.firstWhere((offer) => offer.itemId != 'care_shampoo');
      final first = await sale.purchaseDayFiveSale(
        profileId: profileId,
        periodId: periodId,
        itemId: 'care_shampoo',
        operationId: 'sale-shampoo',
      );
      expect(first.walletBalance, 460);
      await sale.purchaseDayFiveSale(
        profileId: profileId,
        periodId: periodId,
        itemId: 'care_shampoo',
        operationId: 'sale-shampoo',
      );
      expect(await games.getInventoryQuantity(profileId, 'care_shampoo'), 1);
      await expectLater(
        sale.purchaseDayFiveSale(
          profileId: profileId,
          periodId: periodId,
          itemId: 'care_shampoo',
          operationId: 'another',
        ),
        throwsA(isA<SpecialPurchaseAlreadyDecidedException>()),
      );
      await sale.purchaseDayFiveSale(
        profileId: profileId,
        periodId: periodId,
        itemId: want.itemId,
        operationId: 'sale-want',
      );
      final item = catalog.singleWhere((entry) => entry.id == want.itemId);
      final expenses = (await games.getTransactions(profileId))
          .where((entry) => entry.source.startsWith('day5_sale_'))
          .toList();
      expect(expenses, hasLength(2));
      expect(
        expenses
            .singleWhere((entry) => entry.source == 'day5_sale_care_shampoo')
            .type,
        GameTransactionType.needExpense,
      );
      expect(
        expenses
            .singleWhere((entry) => entry.source == 'day5_sale_${want.itemId}')
            .type,
        GameTransactionType.wantExpense,
      );
      expect(
        expenses
            .singleWhere((entry) => entry.source == 'day5_sale_${want.itemId}')
            .amount,
        -(item.price - want.discountAmount),
      );
      expect((await offers()).where((offer) => offer.purchased), hasLength(2));
      await PurchaseService(
        SqlitePurchasePort(database),
        AssetContentRepository(),
      ).purchase(
        profileId: profileId,
        periodId: periodId,
        itemId: 'care_shampoo',
        operationId: 'normal-shampoo',
      );
      expect(await games.getInventoryQuantity(profileId, 'care_shampoo'), 2);
      expect(
        (await games.getTransactions(profileId))
            .singleWhere(
              (entry) => entry.deduplicationKey == 'operation:normal-shampoo',
            )
            .amount,
        -60,
      );
      await expectLater(
        sale.purchaseDayFiveSale(
          profileId: profileId,
          periodId: periodId,
          itemId: want.itemId,
          operationId: 'sale-want-again',
        ),
        throwsA(isA<SpecialPurchaseAlreadyDecidedException>()),
      );
    },
  );

  test('assignment and purchase survive database reopening', () async {
    final directory = await Directory.systemTemp.createTemp('finny_sale_');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final path = '${directory.path}/game.sqlite';
    final firstDb = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    final firstGames = SqliteGameRepository(firstDb);
    final profile = await SqliteProfileRepository(firstDb).create(
      Profile(
        gameName: 'Сохранение',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026),
      ),
    );
    final id = profile.id!;
    await firstGames.ensureInitialState(id);
    final period = await firstGames.startPeriod(
      profileId: id,
      definitionId: 'period_5',
      periodNumber: 5,
      baseIncome: 500,
      requiredCheckpoints: const ['financial_task'],
      createdAt: DateTime.utc(2026),
    );
    final pid = period.id!;
    final firstSale = SpecialPurchaseService(
      SqliteSpecialPurchasePort(firstDb, random: Random(4)),
      AssetContentRepository(),
    );
    final initial = await firstSale.loadOrCreateDayFiveSale(
      profileId: id,
      periodId: pid,
    );
    await confirmBudgetForTest(firstGames, profileId: id, periodId: pid);
    await firstSale.purchaseDayFiveSale(
      profileId: id,
      periodId: pid,
      itemId: 'care_shampoo',
      operationId: 'persisted-sale',
    );
    await firstDb.close();

    final reopened = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    addTearDown(reopened.close);
    final reopenedSale = SpecialPurchaseService(
      SqliteSpecialPurchasePort(reopened, random: Random(99)),
      AssetContentRepository(),
    );
    final after = await reopenedSale.loadOrCreateDayFiveSale(
      profileId: id,
      periodId: pid,
    );
    expect(
      after.map((offer) => (offer.itemId, offer.discountAmount)).toList(),
      initial.map((offer) => (offer.itemId, offer.discountAmount)).toList(),
    );
    expect(
      after.singleWhere((offer) => offer.itemId == 'care_shampoo').purchased,
      isTrue,
    );
    await reopenedSale.purchaseDayFiveSale(
      profileId: id,
      periodId: pid,
      itemId: 'care_shampoo',
      operationId: 'persisted-sale',
    );
    expect(
      (await SqliteGameRepository(reopened).getGameState(id))!.walletBalance,
      460,
    );
  });
}
