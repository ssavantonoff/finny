import 'package:finny/app/providers.dart';
import 'package:finny/core/database/app_database.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/features/shop/shop_item_details.dart';
import 'package:finny/features/shop/shop_screen.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/special_purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

class _ActiveProfile extends ActiveProfileIdController {
  _ActiveProfile(this.id);
  final int id;
  @override
  int? build() => id;
}

class _FixedShopContent extends AssetContentRepository {
  _FixedShopContent(this.items, this.promotions, this.stories);

  final List<ShopItem> items;
  final List<ShopPromotion> promotions;
  final List<StoryPurchase> stories;

  @override
  Future<List<ShopItem>> loadShopItems() async => items;

  @override
  Future<List<ShopPromotion>> loadPromotions() async => promotions;

  @override
  Future<List<StoryPurchase>> loadStoryPurchases() async => stories;
}

class _AmbiguousPromotionService extends SpecialPurchaseService {
  _AmbiguousPromotionService(super.port, super.content);

  final operationIds = <String>[];

  @override
  Future<GameState> purchasePromotion({
    required int profileId,
    required int periodId,
    required String promotionId,
    required String operationId,
  }) async {
    operationIds.add(operationId);
    final state = await super.purchasePromotion(
      profileId: profileId,
      periodId: periodId,
      promotionId: promotionId,
      operationId: operationId,
    );
    if (operationIds.length == 1) {
      throw StateError('Response lost after commit');
    }
    return state;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late SqliteGameRepository games;
  late ProviderContainer container;
  late int profileId;
  late int periodId;
  late _FixedShopContent content;

  setUpAll(() async {
    final assets = AssetContentRepository();
    content = _FixedShopContent(
      await assets.loadShopItems(),
      await assets.loadPromotions(),
      await assets.loadStoryPurchases(),
    );
  });

  setUp(() async {
    database = createTestDatabase();
    games = SqliteGameRepository(database);
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
    await games.savePet(
      Pet(
        profileId: profileId,
        name: 'Финни',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 1,
        growthPoints: 0,
        satiety: 80,
        care: 80,
        mood: 80,
      ),
    );
    final period = await games.startPeriod(
      profileId: profileId,
      definitionId: 'period_4_discount',
      periodNumber: 4,
      baseIncome: 500,
      requiredCheckpoints: const ['financial_task', 'savings_decision'],
      createdAt: DateTime.utc(2026),
    );
    periodId = period.id!;
    container = ProviderContainer(
      overrides: [
        activeProfileIdProvider.overrideWith(() => _ActiveProfile(profileId)),
        appDatabaseProvider.overrideWithValue(database),
        contentRepositoryProvider.overrideWithValue(content),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 500; attempt++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      finder,
      findsOneWidget,
      reason:
          'shop load: ${container.read(shopControllerProvider).load}; '
          'error: ${tester.takeException()}',
    );
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ShopScreen()),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('shop-item-food_treat')));
  }

  Future<void> openTreat(WidgetTester tester) async {
    final item = find.byKey(const Key('shop-item-food_treat'));
    await tester.ensureVisible(item);
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Day 4 planning shows 60 → 35, then active purchase uses 35 and reverts to 60',
    (tester) async {
      await mount(tester);
      expect(
        container
            .read(shopControllerProvider)
            .effectivePriceFor(
              container.read(shopControllerProvider).itemById('food_treat')!,
            ),
        35,
      );
      expect(
        find.byKey(const Key('shop-promo-price-food_treat')),
        findsOneWidget,
      );
      expect(find.text('35 монет'), findsOneWidget);
      final oldPrice = tester.widget<Text>(find.text('60'));
      expect(oldPrice.style?.decoration, TextDecoration.lineThrough);
      await openTreat(tester);
      expect(
        find.descendant(
          of: find.byType(ShopItemDetails),
          matching: find.byKey(const Key('shop-promo-price-food_treat')),
        ),
        findsOneWidget,
      );
      expect(find.text('Сначала подтверди план.'), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('shop-buy')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => confirmBudgetForTest(
          games,
          profileId: profileId,
          periodId: periodId,
        ),
      );
      final reload = container.read(shopControllerProvider.notifier).load();
      for (
        var attempt = 0;
        attempt < 100 &&
            container.read(shopControllerProvider).period?.status !=
                GamePeriodStatus.active;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(
        container.read(shopControllerProvider).period?.status,
        GamePeriodStatus.active,
      );
      await reload;
      await openTreat(tester);
      final buy = find.byKey(const Key('shop-buy'));
      await tester.tap(buy);
      await tester.pump();
      expect(find.text('Купить «Лакомство» за 35 монет?'), findsOneWidget);
      await tester.tap(buy);
      await pumpUntil(tester, find.text('Готово! Предмет куплен.'));
      final first = await tester.runAsync(
        () async => (
          await games.getGameState(profileId),
          await games.getPeriodById(profileId, periodId),
          await games.getInventoryQuantity(profileId, 'food_treat'),
          await games.getTaskProgress(profileId, 'task_shopping_trip_04'),
        ),
      );
      expect(first!.$1!.walletBalance, 465);
      expect(first.$2!.actualWant, 35);
      expect(first.$3, 1);
      expect(first.$4, isNull);
      final state = container.read(shopControllerProvider);
      expect(state.promotionPurchased, isTrue);
      expect(state.effectivePriceFor(state.itemById('food_treat')!), 60);
      await tester.pumpAndSettle();
      await openTreat(tester);
      await tester.tap(find.byKey(const Key('shop-buy')));
      await tester.pump();
      expect(find.text('Купить «Лакомство» за 60 монет?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('shop-buy')));
      for (
        var attempt = 0;
        attempt < 100 &&
            container.read(shopControllerProvider).quantities['food_treat'] !=
                2;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(
        container.read(shopControllerProvider).quantities['food_treat'],
        2,
      );
      final second = await tester.runAsync(
        () async => (
          await games.getGameState(profileId),
          await games.getInventoryQuantity(profileId, 'food_treat'),
        ),
      );
      expect(second!.$1!.walletBalance, 405);
      expect(second.$2, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'insufficient 35 coins reports promo price and does not consume offer',
    (tester) async {
      await tester.runAsync(() async {
        await confirmBudgetForTest(
          games,
          profileId: profileId,
          periodId: periodId,
        );
        await (await database.database).update(
          'game_states',
          {'wallet_balance': 20},
          where: 'profile_id = ?',
          whereArgs: [profileId],
        );
      });
      await mount(tester);
      await openTreat(tester);
      await tester.tap(find.byKey(const Key('shop-buy')));
      await tester.pump();
      expect(find.text('Купить «Лакомство» за 35 монет?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('shop-buy')));
      await pumpUntil(tester, find.textContaining('Цена: 35'));
      final state = container.read(shopControllerProvider);
      expect(state.promotionPurchased, isFalse);
      expect(state.effectivePriceFor(state.itemById('food_treat')!), 35);
      expect(
        await tester.runAsync(
          () => games.getInventoryQuantity(profileId, 'food_treat'),
        ),
        0,
      );
    },
  );

  test(
    'ambiguous promo retry preserves the same operation and price',
    () async {
      await confirmBudgetForTest(
        games,
        profileId: profileId,
        periodId: periodId,
      );
      container.dispose();
      final service = _AmbiguousPromotionService(
        SqliteSpecialPurchasePort(database),
        content,
      );
      container = ProviderContainer(
        overrides: [
          activeProfileIdProvider.overrideWith(() => _ActiveProfile(profileId)),
          appDatabaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(content),
          specialPurchaseServiceProvider.overrideWithValue(service),
        ],
      );
      final controller = container.read(shopControllerProvider.notifier);
      await controller.load();
      expect(
        container
            .read(shopControllerProvider)
            .effectivePriceFor(
              container.read(shopControllerProvider).itemById('food_treat')!,
            ),
        35,
      );
      await controller.buy(
        'food_treat',
        profileId: profileId,
        periodId: periodId,
      );
      final uncertain = container.read(shopControllerProvider);
      expect(uncertain.result?.kind, ShopResultKind.ambiguous);
      expect(uncertain.pending?.promotionId, 'day4_treat_discount');
      expect(uncertain.promotionPurchased, isTrue);
      expect(
        uncertain.effectivePriceFor(uncertain.itemById('food_treat')!),
        60,
      );
      await controller.retry();
      final settled = container.read(shopControllerProvider);
      expect(settled.result?.kind, ShopResultKind.success);
      expect(settled.pending, isNull);
      expect(service.operationIds, hasLength(2));
      expect(service.operationIds[1], service.operationIds[0]);
      expect((await games.getGameState(profileId))!.walletBalance, 465);
      expect(await games.getInventoryQuantity(profileId, 'food_treat'), 1);
    },
  );

  test('promotion price never applies to Days 1, 2, 3 or 5', () async {
    final period = (await games.getPeriodById(profileId, periodId))!;
    final treat = content.items.singleWhere((item) => item.id == 'food_treat');
    for (final day in [1, 2, 3, 5]) {
      final otherDay = GamePeriod.fromMap({
        ...period.toMap(),
        'period_number': day,
      });
      final state = ShopState(
        load: ShopLoad.ready,
        profileId: profileId,
        period: otherDay,
        items: content.items,
        promotion: content.promotions.single,
      );
      expect(state.isPromotionActiveFor(treat), isFalse);
      expect(state.effectivePriceFor(treat), 60);
    }
  });
}
