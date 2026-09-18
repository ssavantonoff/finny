import 'dart:async';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/shop/shop_screen.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/purchase_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shop_test_support.dart';

void main() {
  late ShopHarness h;
  setUp(() => h = ShopHarness());
  tearDown(() => h.dispose());

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(theme: AppTheme.light, home: const ShopScreen()),
      ),
    );
    await tester.pumpAndSettle();
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
      expect(find.text('Готово! Предмет куплен.'), findsWidgets);
      expect(find.text('У тебя: 77 монет'), findsOneWidget);
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
    expect(find.text('У тебя: 800 монет'), findsOneWidget);
    expect(find.text('У тебя: 500 монет'), findsNothing);
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
