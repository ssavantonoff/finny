import 'dart:async';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/shop/shop_item_details.dart';
import 'package:finny/features/shop/shop_screen.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/purchase_exception.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shop_test_support.dart';

void main() {
  late ShopHarness h;
  late List<ShopItem> canonicalItems;
  setUpAll(() async {
    canonicalItems = await AssetContentRepository().loadShopItems();
  });
  setUp(() => h = ShopHarness());
  tearDown(() => h.dispose());

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(360, 800),
    bool floatingNavigation = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (floatingNavigation) {
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetViewPadding);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: floatingNavigation
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    const ShopScreen(),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 32,
                      height: 68,
                      child: IgnorePointer(
                        child: ColoredBox(
                          key: const Key('test-floating-navigation'),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
              : const ShopScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, ShopDisplaySection section) async {
    final chip = find.byKey(Key('shop-category-${section.name}'));
    final row = find.byKey(const Key('shop-category-navigation'));
    final width = tester.getSize(row).width;
    for (var attempt = 0; attempt < 4; attempt++) {
      if (chip.evaluate().isNotEmpty) {
        final bounds = tester.getRect(chip);
        if (bounds.left >= 16 && bounds.right <= width - 16) break;
      }
      final direction = chip.evaluate().isNotEmpty
          ? (tester.getRect(chip).left < 16 ? 300.0 : -300.0)
          : (section == ShopDisplaySection.food ? 300.0 : -300.0);
      await tester.drag(row, Offset(direction, 0));
      await tester.pumpAndSettle();
    }
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  Future<void> open(
    WidgetTester tester,
    ShopItem item, {
    int? expectedOperations = 0,
  }) async {
    await select(tester, item.displaySection);
    final card = find.byKey(Key('shop-item-${item.id}'));
    await tester.ensureVisible(card);
    final button = find.byKey(Key('shop-card-buy-${item.id}'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(ShopItemDetails), findsOneWidget);
    expect(find.byKey(const Key('shop-confirmation')), findsOneWidget);
    if (expectedOperations != null) expect(h.generatedIds, expectedOperations);
  }

  testWidgets('four category filters show only matching canonical items', (
    tester,
  ) async {
    h.content.items = canonicalItems;
    await mount(tester);
    expect(find.text('Магазин'), findsOneWidget);
    expect(find.byKey(const Key('shop-wallet')), findsOneWidget);
    for (final section in ShopDisplaySection.values) {
      await select(tester, section);
      final items = canonicalItems.where(
        (item) => item.displaySection == section,
      );
      expect(items.length, 3);
      for (final item in items) {
        expect(find.byKey(Key('shop-item-${item.id}')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(Key('shop-item-${item.id}')),
            matching: find.text(item.name),
          ),
          findsOneWidget,
        );
      }
      for (final item in canonicalItems.where(
        (item) => item.displaySection != section,
      )) {
        expect(find.byKey(Key('shop-item-${item.id}')), findsNothing);
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('each filtered grid keeps canonical item order', (tester) async {
    h.content.items = [apple, feed, brush, ball, frisbee, bow];
    await mount(tester);
    for (final section in ShopDisplaySection.values) {
      await select(tester, section);
      final visible = h.content.items
          .where((item) => item.displaySection == section)
          .toList();
      for (var index = 0; index < visible.length; index++) {
        final card = find.byKey(Key('shop-item-${visible[index].id}'));
        expect(card, findsOneWidget);
        if (index > 0) {
          final previous = find.byKey(
            Key('shop-item-${visible[index - 1].id}'),
          );
          expect(
            tester.getTopLeft(card).dx,
            greaterThan(tester.getTopLeft(previous).dx),
          );
        }
      }
    }
  });

  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets(
      'mouse drag and selected auto-reveal Accessories at ${size.width}x${size.height}',
      (tester) async {
        h.content.items = canonicalItems;
        await mount(tester, size: size);
        final row = find.byKey(const Key('shop-category-navigation'));
        final position = tester
            .state<ScrollableState>(
              find.descendant(of: row, matching: find.byType(Scrollable)),
            )
            .position;
        expect(position.pixels, 0);
        await tester.drag(
          row,
          const Offset(-150, 0),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(position.pixels, greaterThan(0));
        for (
          var attempt = 0;
          attempt < 4 && position.pixels < position.maxScrollExtent - 1;
          attempt++
        ) {
          await tester.drag(
            row,
            const Offset(-150, 0),
            kind: PointerDeviceKind.mouse,
          );
          await tester.pumpAndSettle();
        }
        final accessories = find.byKey(const Key('shop-category-accessories'));
        expect(accessories, findsOneWidget);
        final bounds = tester.getRect(accessories);
        expect(bounds.left, greaterThanOrEqualTo(16));
        expect(
          bounds.right,
          lessThanOrEqualTo(size.width - 16),
          reason: 'offset ${position.pixels} / ${position.maxScrollExtent}',
        );
        position.jumpTo(position.maxScrollExtent - 24);
        await tester.pump();
        expect(tester.getRect(accessories).right, greaterThan(size.width - 16));
        await tester.tap(accessories);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(accessories).right,
          lessThanOrEqualTo(size.width - 16),
        );
        expect(
          find.byKey(const Key('shop-item-accessory_bow')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'two-column cards and safe sheet at ${size.width}x${size.height}',
      (tester) async {
        h.content.items = canonicalItems;
        await mount(tester, size: size);
        final appleCard = find.byKey(const Key('shop-item-food_apple'));
        final feedCard = find.byKey(const Key('shop-item-food_feed'));
        expect(tester.getTopLeft(appleCard).dy, tester.getTopLeft(feedCard).dy);
        expect(
          tester.getTopLeft(appleCard).dx,
          lessThan(tester.getTopLeft(feedCard).dx),
        );
        expect(find.text('Сытость Финни +20'), findsNothing);
        await open(tester, canonicalItems.first);
        expect(
          tester.getBottomRight(find.byType(ShopItemDetails)).dy,
          lessThanOrEqualTo(size.height),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'last SALE card clears floating navigation at ${size.width}x${size.height}',
      (tester) async {
        h.dispose();
        h = ShopHarness(
          saleOffers: const [
            DayFiveSaleOffer(
              itemId: 'accessory_hat',
              discountAmount: 20,
              purchased: false,
            ),
          ],
        );
        h.content.items = canonicalItems;
        h.games.periods[1] = period(1, periodNumber: 5);
        await mount(tester, size: size, floatingNavigation: true);
        await select(tester, ShopDisplaySection.accessories);
        final card = find.byKey(const Key('shop-promo-card-accessory_hat'));
        expect(card, findsOneWidget);
        expect(
          find.descendant(
            of: card,
            matching: find.byKey(const Key('shop-promo-marker-accessory_hat')),
          ),
          findsOneWidget,
        );
        final catalog = tester.widget<CustomScrollView>(
          find.byType(CustomScrollView),
        );
        catalog.controller!.jumpTo(
          catalog.controller!.position.maxScrollExtent,
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('shop-card-buy-accessory_hat')));
        await tester.pumpAndSettle();
        expect(find.text('Купить «Крылья» за 160 монет?'), findsOneWidget);
        expect(
          find.byKey(const Key('shop-promo-price-accessory_hat')),
          findsWidgets,
        );
        await tester.tap(find.byKey(const Key('shop-cancel')));
        await tester.pumpAndSettle();
        catalog.controller!.jumpTo(
          catalog.controller!.position.maxScrollExtent,
        );
        await tester.pump();
        final navTop = tester
            .getTopLeft(find.byKey(const Key('test-floating-navigation')))
            .dy;
        final gap = navTop - tester.getBottomRight(card).dy;
        expect(gap, greaterThanOrEqualTo(24));
        expect(gap, lessThanOrEqualTo(80));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'card opens one confirmation and a single buy creates one operation',
    (tester) async {
      final gate = Completer<void>();
      h.purchases.handler = (_) async {
        await gate.future;
        return wallet(1, 77);
      };
      await mount(tester);
      await open(tester, apple);
      expect(find.text('Лёгкий перекус для Финни'), findsOneWidget);
      expect(find.text('Купить «Яблоко» за 40 монет?'), findsOneWidget);
      final buy = find.byKey(const Key('shop-buy'));
      await tester.tap(buy);
      await tester.pump();
      expect(h.purchases.calls, hasLength(1));
      expect(h.generatedIds, 1);
      expect(tester.widget<FilledButton>(buy).onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ShopItemDetails), findsNothing);
      expect(h.state.gameState?.walletBalance, 77);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Cancel and close create no operation', (tester) async {
    await mount(tester);
    await open(tester, apple);
    await tester.tap(find.byKey(const Key('shop-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(ShopItemDetails), findsNothing);
    await open(tester, apple);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.byType(ShopItemDetails), findsNothing);
    expect(h.purchases.calls, isEmpty);
    expect(h.generatedIds, 0);
  });

  testWidgets(
    'insufficient funds keeps inventory and wallet, no technical error',
    (tester) async {
      h.purchases.handler = (_) async => throw InsufficientFundsException(
        itemPrice: 120,
        availableBalance: 80,
      );
      await mount(tester);
      await open(tester, ball);
      await tester.tap(find.byKey(const Key('shop-buy')));
      await tester.pumpAndSettle();
      final message = find.textContaining('Пока не хватает монет.');
      expect(
        find.descendant(of: find.byType(ShopItemDetails), matching: message),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(ShopScreen), matching: message),
        findsNothing,
      );
      expect(h.state.gameState?.walletBalance, 500);
      expect(h.state.quantities[ball.id], 0);
      expect(find.textContaining('InsufficientFunds'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('shop-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shop-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(ShopItemDetails), findsNothing);
      expect(message, findsNothing);
    },
  );

  testWidgets('persistent owned item is disabled while consumable can reopen', (
    tester,
  ) async {
    h.games.quantities[1]![ball.id] = 1;
    await mount(tester);
    await select(tester, ShopDisplaySection.toys);
    final owned = find.byKey(const Key('shop-card-buy-toy_ball'));
    expect(
      find.descendant(of: owned, matching: find.text('Куплено')),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(owned).onPressed, isNull);
    await open(tester, apple);
    await tester.tap(find.byKey(const Key('shop-buy')));
    await tester.pumpAndSettle();
    await open(tester, apple, expectedOperations: 1);
    expect(find.byType(ShopItemDetails), findsOneWidget);
  });

  testWidgets(
    'already-owned purchase result rereads ownership and disables card',
    (tester) async {
      h.purchases.handler = (_) async {
        h.games.quantities[1]![ball.id] = 1;
        throw PersistentItemAlreadyOwnedException(itemId: ball.id);
      };
      await mount(tester);
      await open(tester, ball);
      await tester.tap(find.byKey(const Key('shop-buy')));
      await tester.pumpAndSettle();
      expect(find.text('Этот предмет уже куплен.'), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('shop-buy')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('shop-cancel')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('shop-card-buy-toy_ball')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('ambiguous retry uses the original operation', (tester) async {
    h.purchases.handler = (_) async {
      h.games.periods[1] = null;
      throw StateError('SQL secret');
    };
    await mount(tester);
    await open(tester, apple);
    await tester.tap(find.byKey(const Key('shop-buy')));
    await tester.pumpAndSettle();
    expect(find.text('Не получилось купить предмет.'), findsWidgets);
    h.purchases.handler = (_) async => wallet(1, 460);
    await tester.tap(find.text('Повторить').last);
    await tester.pumpAndSettle();
    expect(h.purchases.calls, hasLength(2));
    expect(
      h.purchases.calls.last.operationId,
      h.purchases.calls.first.operationId,
    );
    expect(h.purchases.calls.last.periodId, 91);
  });

  testWidgets('profile or period change closes stale confirmation', (
    tester,
  ) async {
    await mount(tester);
    await open(tester, apple);
    h.games.periods[1] = period(1, id: 200);
    await h.controller.load();
    await tester.pumpAndSettle();
    expect(find.byType(ShopItemDetails), findsNothing);
    expect(h.generatedIds, 0);
    await open(tester, apple);
    h.select(2);
    await tester.pumpAndSettle();
    expect(find.byType(ShopItemDetails), findsNothing);
    expect(h.state.gameState?.walletBalance, 800);
  });

  for (final nextPeriod in [
    period(1, status: GamePeriodStatus.planning),
    null,
  ]) {
    testWidgets(
      'non-purchasable period invalidates open confirmation: $nextPeriod',
      (tester) async {
        await mount(tester);
        await open(tester, apple);
        h.games.periods[1] = nextPeriod;
        await h.controller.load();
        await tester.pumpAndSettle();
        expect(find.byType(ShopItemDetails), findsNothing);
        expect(h.purchases.calls, isEmpty);
        expect(h.generatedIds, 0);
      },
    );
  }

  testWidgets('unchanged period reload and readyToFinish retain confirmation', (
    tester,
  ) async {
    await mount(tester);
    await open(tester, apple);
    await h.controller.load();
    await tester.pumpAndSettle();
    expect(find.byType(ShopItemDetails), findsOneWidget);
    h.games.periods[1] = period(1, status: GamePeriodStatus.readyToFinish);
    await h.controller.load();
    await tester.pumpAndSettle();
    expect(find.byType(ShopItemDetails), findsOneWidget);
  });

  testWidgets('empty, error and no profile remain distinct', (tester) async {
    h.content.items = [];
    await mount(tester);
    expect(find.text('В магазине пока нет товаров.'), findsOneWidget);
    h.content.error = const FormatException('secret');
    await h.controller.load();
    await tester.pumpAndSettle();
    expect(
      find.text('Не получилось открыть магазин. Попробуй ещё раз.'),
      findsOneWidget,
    );
    h.select(null);
    await tester.pumpAndSettle();
    expect(find.text('Профиль пока не выбран.'), findsOneWidget);
  });
}
