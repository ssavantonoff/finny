import 'dart:async';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/shop/shop_screen.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/purchase_exception.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shop_test_support.dart';

void main() {
  late ShopHarness h;
  ShopHarness? saleHarness;
  late List<ShopItem> canonicalItems;
  setUpAll(() async {
    canonicalItems = await AssetContentRepository().loadShopItems();
  });
  setUp(() {
    h = ShopHarness();
    saleHarness = null;
  });
  tearDown(() {
    h.dispose();
    saleHarness?.dispose();
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(360, 800),
    bool floatingNavigation = false,
    ShopHarness? harness,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Widget home;
    if (floatingNavigation) {
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetViewPadding);
      home = Stack(
        fit: StackFit.expand,
        children: [
          const ShopScreen(),
          Positioned(
            left: 12,
            right: 12,
            bottom: 32,
            height: 68,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const Key('test-floating-navigation'),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      home = const ShopScreen();
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: (harness ?? h).container,
        child: MaterialApp(theme: AppTheme.light, home: home),
      ),
    );
    if (floatingNavigation) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> details(WidgetTester tester, [String id = 'food_apple']) async {
    final card = find.byKey(Key('shop-item-$id'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    final buy = find.byKey(const Key('shop-buy'));
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-confirmation')), findsOneWidget);
    expect(h.generatedIds, 0);
    await tester.ensureVisible(buy);
    await tester.tap(buy);
  }

  ChoiceChip categoryChip(WidgetTester tester, ShopDisplaySection section) =>
      tester.widget<ChoiceChip>(
        find.byKey(Key('shop-category-${section.name}')),
      );

  testWidgets('sticky category navigation starts at Food on 360dp', (
    tester,
  ) async {
    await mount(tester);

    for (final section in ShopDisplaySection.values) {
      expect(find.byKey(Key('shop-category-${section.name}')), findsOneWidget);
    }
    expect(categoryChip(tester, ShopDisplaySection.food).selected, isTrue);
    expect(categoryChip(tester, ShopDisplaySection.care).selected, isFalse);
    expect(find.byKey(const Key('shop-category-navigation')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category taps reach Toys and Decorations', (tester) async {
    await mount(tester);

    final toys = find.byKey(const Key('shop-category-toys'));
    await tester.ensureVisible(toys);
    await tester.tap(toys);
    await tester.pumpAndSettle();
    final selectedAfterToys = ShopDisplaySection.values
        .where((section) => categoryChip(tester, section).selected)
        .toList();
    expect(
      categoryChip(tester, ShopDisplaySection.toys).selected,
      isTrue,
      reason: 'selected categories: $selectedAfterToys',
    );
    expect(
      find.byKey(const Key('shop-section-toys')).hitTestable(),
      findsOneWidget,
    );

    final accessories = find.byKey(const Key('shop-category-accessories'));
    await tester.ensureVisible(accessories);
    await tester.tap(accessories);
    await tester.pumpAndSettle();
    expect(
      categoryChip(tester, ShopDisplaySection.accessories).selected,
      isTrue,
    );
    expect(
      find.byKey(const Key('shop-section-accessories')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Украшения'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'manual catalog scroll updates active category and keeps bar visible',
    (tester) async {
      await mount(tester);

      await tester.ensureVisible(find.byKey(const Key('shop-section-care')));
      await tester.pumpAndSettle();

      expect(categoryChip(tester, ShopDisplaySection.care).selected, isTrue);
      expect(
        find.byKey(const Key('shop-category-navigation')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('items keep canonical order inside the four sections', (
    tester,
  ) async {
    h.content.items = [apple, feed, brush, ball, frisbee, bow];
    await mount(tester);

    final itemKeys = find
        .byType(InkWell)
        .evaluate()
        .map((element) => element.widget.key)
        .whereType<Key>()
        .where((key) => key.toString().contains('shop-item-'))
        .map((key) => key.toString())
        .toList();
    expect(
      itemKeys,
      containsAllInOrder([
        const Key('shop-item-food_apple').toString(),
        const Key('shop-item-food_feed').toString(),
        const Key('shop-item-care_comb').toString(),
        const Key('shop-item-toy_ball').toString(),
        const Key('shop-item-toy_frisbee').toString(),
        const Key('shop-item-accessory_bow').toString(),
      ]),
    );
  });

  testWidgets('Shop shows all 12 final product identities', (tester) async {
    h.content.items = canonicalItems;
    await mount(tester);
    expect(h.content.items, hasLength(12));
    for (final item in h.content.items) {
      final card = find.byKey(Key('shop-item-${item.id}'));
      expect(card, findsOneWidget, reason: item.id);
      expect(
        find.descendant(of: card, matching: find.text(item.name)),
        findsOneWidget,
        reason: item.id,
      );
    }
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets(
      'Day 5 last SALE card clears floating navigation at ${size.width}x${size.height}',
      (tester) async {
        saleHarness = ShopHarness(
          saleOffers: const [
            DayFiveSaleOffer(
              itemId: 'care_shampoo',
              discountAmount: 20,
              purchased: false,
            ),
            DayFiveSaleOffer(
              itemId: 'accessory_bow',
              discountAmount: 20,
              purchased: false,
            ),
            DayFiveSaleOffer(
              itemId: 'accessory_hat',
              discountAmount: 20,
              purchased: false,
            ),
          ],
        );
        saleHarness!.content.items = canonicalItems;
        saleHarness!.games.periods[1] = period(1, periodNumber: 5);
        await mount(
          tester,
          size: size,
          floatingNavigation: true,
          harness: saleHarness,
        );

        final lastSaleCard = find.byKey(
          const Key('shop-promo-card-accessory_hat'),
        );
        expect(lastSaleCard, findsOneWidget);
        expect(
          find.descendant(
            of: lastSaleCard,
            matching: find.byKey(const Key('shop-promo-marker-accessory_hat')),
          ),
          findsOneWidget,
        );
        final catalog = tester.widget<CustomScrollView>(
          find.byType(CustomScrollView),
        );
        final scrollController = catalog.controller!;
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pump();
        await tester.pump();

        final navTop = tester
            .getTopLeft(find.byKey(const Key('test-floating-navigation')))
            .dy;
        final saleToNavigationGap =
            navTop - tester.getBottomRight(lastSaleCard).dy;
        expect(saleToNavigationGap, greaterThanOrEqualTo(24));
        expect(saleToNavigationGap, lessThanOrEqualTo(80));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    '360dp list, details and confirmation; double tap/rebuild do not repurchase',
    (tester) async {
      final gate = Completer<void>();
      h.purchases.handler = (_) async {
        await gate.future;
        return wallet(1, 77);
      };
      await mount(tester);
      expect(find.text('40 монет • Еда'), findsOneWidget);
      expect(find.text('120 монет • Игрушки'), findsOneWidget);
      expect(find.text('Сытость Финни +10'), findsOneWidget);
      expect(find.text('Настроение Финни +8'), findsOneWidget);
      await details(tester);
      expect(h.purchases.calls, isEmpty);
      final buy = find.byKey(const Key('shop-buy'));
      final originalSize = tester.getSize(buy);
      await confirm(tester);
      await tester.tap(buy);
      await tester.pump();
      expect(h.purchases.calls, hasLength(1));
      expect(h.generatedIds, 1);
      expect(tester.widget<FilledButton>(buy).onPressed, isNull);
      expect(tester.getSize(buy), originalSize);
      await tester.pump();
      expect(h.purchases.calls, hasLength(1));
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Готово! Предмет куплен.'), findsOneWidget);
      expect(find.byKey(const Key('shop-buy')), findsNothing);
      expect(h.state.gameState?.walletBalance, 77);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Готово! Предмет куплен.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('confirmation cancellation generates no operation', (
    tester,
  ) async {
    await mount(tester);
    await details(tester);
    await tester.tap(find.byKey(const Key('shop-buy')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Отмена'));
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(h.purchases.calls, isEmpty);
    expect(h.generatedIds, 0);
    expect(find.byKey(const Key('shop-confirmation')), findsNothing);
  });

  testWidgets(
    'typed insufficient result displays canonical amounts without technical errors',
    (tester) async {
      h.purchases.handler = (_) async => throw InsufficientFundsException(
        itemPrice: 120,
        availableBalance: 80,
      );
      await mount(tester);
      await details(tester, ball.id);
      await confirm(tester);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Пока не хватает монет.\nЦена: 120\nУ тебя: 80\nНе хватает: 40',
        ),
        findsWidgets,
      );
      expect(find.text('Повторить'), findsNothing);
      expect(find.textContaining('InsufficientFunds'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('owned result rereads ownership and disables buy', (
    tester,
  ) async {
    h.purchases.handler = (_) async {
      h.games.quantities[1]![ball.id] = 1;
      throw PersistentItemAlreadyOwnedException(itemId: ball.id);
    };
    await mount(tester);
    await details(tester, ball.id);
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(find.text('Этот предмет уже куплен.'), findsWidgets);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('shop-buy'))).onPressed,
      isNull,
    );
    expect(find.text('Повторить'), findsNothing);
  });

  testWidgets('ambiguous retry remains available with no current period', (
    tester,
  ) async {
    h.purchases.handler = (_) async {
      h.games.periods[1] = null;
      throw StateError('SQL secret');
    };
    await mount(tester);
    await details(tester);
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(find.text('Не получилось купить предмет.'), findsWidgets);
    expect(find.textContaining('SQL secret'), findsNothing);
    h.purchases.handler = (_) async => wallet(1, 460);
    final retry = find.text('Повторить').last;
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(h.purchases.calls, hasLength(2));
    expect(
      h.purchases.calls.last.operationId,
      h.purchases.calls.first.operationId,
    );
    expect(h.purchases.calls.last.periodId, 91);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile switch closes old details and replaces wallet', (
    tester,
  ) async {
    await mount(tester);
    await details(tester);
    h.select(2);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-buy')), findsNothing);
    expect(h.state.gameState?.walletBalance, 800);
    expect(h.state.profileId, 2);
    expect(h.purchases.calls, isEmpty);
  });

  testWidgets('empty and load error are separate visible states', (
    tester,
  ) async {
    h.content.items = [];
    await mount(tester);
    expect(find.text('В магазине пока нет товаров.'), findsOneWidget);
    h.content.error = const FormatException('secret');
    await h.controller.load();
    await tester.pumpAndSettle();
    expect(find.text('В магазине пока нет товаров.'), findsNothing);
    expect(
      find.text('Не получилось открыть магазин. Попробуй ещё раз.'),
      findsOneWidget,
    );
    expect(find.textContaining('FormatException'), findsNothing);
  });

  testWidgets('null profile is safe and has no buy actions', (tester) async {
    h.select(null);
    await mount(tester);
    expect(find.text('Профиль пока не выбран.'), findsOneWidget);
    expect(find.byKey(const Key('shop-buy')), findsNothing);
    expect(h.purchases.calls, isEmpty);
  });

  testWidgets(
    'stale confirmation period invalidates and allows re-confirmation',
    (tester) async {
      await mount(tester);
      await details(tester);

      // Enter confirmation with period A (id=91).
      await tester.tap(find.byKey(const Key('shop-buy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-confirmation')), findsOneWidget);
      expect(h.purchases.calls, isEmpty);
      expect(h.generatedIds, 0);

      // Change canonical period to B (id=200).
      h.games.periods[1] = period(1, id: 200);
      await h.controller.load();
      await tester.pumpAndSettle();

      // Stale confirmation must be reset.
      expect(find.byKey(const Key('shop-confirmation')), findsNothing);
      expect(
        find.text('Игровой период изменился. Подтверди покупку ещё раз.'),
        findsOneWidget,
      );
      expect(h.purchases.calls, isEmpty);
      expect(h.generatedIds, 0);

      // Re-enter confirmation with period B.
      final buy = find.byKey(const Key('shop-buy'));
      await tester.ensureVisible(buy);
      await tester.tap(buy);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-confirmation')), findsOneWidget);

      // Final purchase.
      await tester.ensureVisible(buy);
      await tester.tap(buy);
      await tester.pumpAndSettle();

      expect(h.purchases.calls, hasLength(1));
      expect(h.purchases.calls.single.periodId, 200);
      expect(h.generatedIds, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stale confirmation invalidated when period becomes non-purchasable',
    (tester) async {
      await mount(tester);
      await details(tester);

      // Enter confirmation with period A (id=91, active).
      await tester.tap(find.byKey(const Key('shop-buy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-confirmation')), findsOneWidget);

      // Same id=91 but status changes to planning.
      h.games.periods[1] = period(1, id: 91, status: GamePeriodStatus.planning);
      await h.controller.load();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shop-confirmation')), findsNothing);
      expect(
        find.text('Игровой период изменился. Подтверди покупку ещё раз.'),
        findsOneWidget,
      );
      expect(h.purchases.calls, isEmpty);
      expect(h.generatedIds, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stale confirmation invalidated when period becomes null', (
    tester,
  ) async {
    await mount(tester);
    await details(tester);

    // Enter confirmation with period A (id=91, active).
    await tester.tap(find.byKey(const Key('shop-buy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-confirmation')), findsOneWidget);

    // Period disappears entirely.
    h.games.periods[1] = null;
    await h.controller.load();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shop-confirmation')), findsNothing);
    expect(
      find.text('Игровой период изменился. Подтверди покупку ещё раз.'),
      findsOneWidget,
    );
    expect(h.purchases.calls, isEmpty);
    expect(h.generatedIds, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'confirmation survives reload when canonical period id is unchanged',
    (tester) async {
      await mount(tester);
      await details(tester);

      // Enter confirmation with period A (id=91).
      await tester.tap(find.byKey(const Key('shop-buy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-confirmation')), findsOneWidget);
      expect(h.purchases.calls, isEmpty);
      expect(h.generatedIds, 0);

      // Reload without changing the canonical period.
      await h.controller.load();
      await tester.pumpAndSettle();

      // Confirmation must survive — no false invalidation.
      expect(find.byKey(const Key('shop-confirmation')), findsOneWidget);
      expect(
        find.text('Игровой период изменился. Подтверди покупку ещё раз.'),
        findsNothing,
      );
      expect(h.purchases.calls, isEmpty);
      expect(h.generatedIds, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmation closes on profile switch without period-changed message',
    (tester) async {
      await mount(tester);
      await details(tester);

      // Enter confirmation with profile 1.
      await tester.tap(find.byKey(const Key('shop-buy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shop-confirmation')), findsOneWidget);

      // Switch to profile 2.
      h.select(2);
      await tester.pumpAndSettle();

      // Details closed by existing profile-switch logic.
      expect(find.byKey(const Key('shop-buy')), findsNothing);
      expect(h.purchases.calls, isEmpty);
      expect(h.generatedIds, 0);
      // No false period-changed SnackBar.
      expect(
        find.text('Игровой период изменился. Подтверди покупку ещё раз.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('confirmation survives active to readyToFinish transition', (
    tester,
  ) async {
    await mount(tester);
    await details(tester);

    // Enter confirmation with period id=91, active.
    await tester.tap(find.byKey(const Key('shop-buy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shop-confirmation')), findsOneWidget);

    // Period transitions to readyToFinish (still purchasable).
    h.games.periods[1] = period(
      1,
      id: 91,
      status: GamePeriodStatus.readyToFinish,
    );
    await h.controller.load();
    await tester.pumpAndSettle();

    // Confirmation must survive — readyToFinish allows purchases.
    expect(find.byKey(const Key('shop-confirmation')), findsOneWidget);
    expect(
      find.text('Игровой период изменился. Подтверди покупку ещё раз.'),
      findsNothing,
    );
    expect(h.purchases.calls, isEmpty);
    expect(h.generatedIds, 0);
    expect(tester.takeException(), isNull);
  });
}
