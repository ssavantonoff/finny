import 'dart:async';

import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/purchase_exception.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shop_test_support.dart';

void main() {
  late ShopHarness h;
  setUp(() => h = ShopHarness());
  tearDown(() => h.dispose());

  test('null profile cannot purchase or generate operation ID', () async {
    h.select(null);
    await h.controller.load();
    await h.buy();
    expect(h.state.load, ShopLoad.noProfile);
    expect(h.purchases.calls, isEmpty);
    expect(h.generatedIds, 0);
  });
  test('loading, content success, empty and error remain distinct', () async {
    h.content.gate = Completer<void>();
    final load = h.controller.load();
    expect(h.state.load, ShopLoad.loading);
    h.content.gate!.complete();
    await load;
    expect(h.state.items, [apple, brush, ball, bow]);
    h.content.items = [];
    await h.controller.load();
    expect(h.state.load, ShopLoad.ready);
    expect(h.state.items, isEmpty);
    h.content.error = const FormatException('secret JSON');
    await h.controller.load();
    expect(h.state.load, ShopLoad.contentError);
    await h.buy();
    expect(h.purchases.calls, isEmpty);
  });
  for (final stage in ['game', 'period', 'inventory']) {
    test('late $stage response for A cannot overwrite B', () async {
      h.games.gatedStage = stage;
      h.games.gate = Completer<void>();
      final oldLoad = h.controller.load();
      await pumpEventQueue();
      h.select(2);
      await pumpEventQueue();
      expect(h.state.profileId, 2);
      expect(h.state.gameState?.walletBalance, 800);
      h.games.gate!.complete();
      await oldLoad;
      expect(h.state.profileId, 2);
      expect(h.state.gameState?.walletBalance, 800);
    });
  }
  test('late content response for A cannot replace B content', () async {
    final gate = Completer<void>();
    h.content.gate = gate;
    final oldLoad = h.controller.load();
    h.content.gate = null;
    h.content.items = [ball];
    h.select(2);
    await pumpEventQueue();
    gate.complete();
    await oldLoad;
    expect(h.state.items, [ball]);
    expect(h.state.profileId, 2);
  });
  test('missing state and repository errors disable purchase', () async {
    h.games.states[1] = null;
    await h.controller.load();
    expect(h.state.load, ShopLoad.noGameState);
    expect(h.state.gameState, isNull);
    h.games.gameError = StateError('database');
    await h.controller.load();
    expect(h.state.load, ShopLoad.runtimeError);
    await h.buy();
    expect(h.purchases.calls, isEmpty);
  });
  test(
    'inventory error is not zero ownership; period error is not no period',
    () async {
      h.games.inventoryError = StateError('read');
      await h.controller.load();
      expect(h.state.load, ShopLoad.runtimeError);
      expect(h.state.quantities.containsKey(ball.id), isFalse);
      await h.buy(ball);
      h.games.inventoryError = null;
      h.games.periodError = StateError('read');
      await h.controller.load();
      expect(h.state.load, ShopLoad.runtimeError);
      await h.buy();
      expect(h.purchases.calls, isEmpty);
    },
  );
  for (final status in GamePeriodStatus.values) {
    test('new purchase respects $status and uses database ID', () async {
      h.games.periods[1] = period(1, status: status);
      await h.controller.load();
      final allowed =
          status == GamePeriodStatus.active ||
          status == GamePeriodStatus.readyToFinish;
      expect(h.state.canBuy(apple), allowed);
      await h.buy();
      expect(h.purchases.calls.length, allowed ? 1 : 0);
      if (allowed) {
        expect(h.purchases.calls.single.periodId, 91);
        expect(h.purchases.calls.single.profileId, 1);
        expect(h.purchases.calls.single.item, same(apple));
        expect(h.purchases.calls.single.operationId, 'test-op-1');
      }
    });
  }
  test('no current period disables new purchases', () async {
    h.games.periods[1] = null;
    await h.controller.load();
    expect(h.state.load, ShopLoad.ready);
    expect(h.state.unavailableReason(apple), 'Сначала начни игровой период.');
    await h.buy();
    expect(h.purchases.calls, isEmpty);
  });
  test(
    'ownership, consumable repeat, unknown unlock and effect presentation',
    () async {
      h.games.quantities[1] = {apple.id: 2, ball.id: 1};
      const locked = ShopItem(
        id: 'locked',
        name: 'Товар',
        category: ShopItemCategory.want,
        price: 1,
        persistent: false,
        effectType: 'none',
        effectValue: 0,
        unlockType: 'future',
      );
      h.content.items.add(locked);
      await h.controller.load();
      expect(h.state.canBuy(apple), isTrue);
      expect(h.state.unavailableReason(ball), 'Уже куплено');
      expect(h.state.canBuy(locked), isFalse);
      expect(shopEffect(locked), isNull);
      expect(shopEffect(apple), 'Сытость Финни +10');
      expect(shopEffect(ball), 'Настроение Финни +8');
      expect(shopCategory(apple), 'Еда');
      expect(shopCategory(ball), 'Игрушки');
    },
  );
  test('double submit makes one call; success uses returned wallet and rereads inventory', () async {
    final gate = Completer<void>();
    h.purchases.handler = (_) async {
      await gate.future;
      h.games.quantities[1]![apple.id] = 1;
      return wallet(1, 123);
    };
    await h.controller.load();
    final first = h.buy();
    await h.buy();
    expect(h.generatedIds, 1);
    expect(h.state.purchasing, isTrue);
    gate.complete();
    await first;
    expect(h.purchases.calls, hasLength(1));
    expect(h.state.gameState!.walletBalance, 123);
    expect(h.state.quantities[apple.id], 1);
    expect(h.state.pending, isNull);
    expect(h.state.result?.kind, ShopResultKind.success);
    await h.buy();
    expect(h.purchases.calls.last.operationId, 'test-op-2');
  });
  test('refresh failure after success is terminal, not ambiguous', () async {
    await h.controller.load();
    h.purchases.handler = (_) async {
      h.games.inventoryError = StateError('refresh failed');
      return wallet(1, 77);
    };
    await h.buy();
    expect(h.state.result?.kind, ShopResultKind.success);
    expect(h.state.load, ShopLoad.runtimeError);
    expect(h.state.gameState?.walletBalance, 77);
    expect(h.state.pending, isNull);
    await h.controller.retry();
    expect(h.purchases.calls, hasLength(1));
  });
  test(
    'low presentation balance does not block authoritative insufficient result',
    () async {
      h.games.states[1] = wallet(1, 0);
      h.purchases.handler = (_) async => throw InsufficientFundsException(
        itemPrice: 120,
        availableBalance: 80,
      );
      await h.controller.load();
      expect(h.state.canBuy(ball), isTrue);
      await h.buy(ball);
      expect(h.state.result?.kind, ShopResultKind.insufficientFunds);
      expect(h.state.result?.itemPrice, 120);
      expect(h.state.result?.availableBalance, 80);
      expect(h.state.pending, isNull);
      await h.controller.retry();
      expect(h.purchases.calls, hasLength(1));
      await h.buy(apple);
      expect(h.purchases.calls.last.operationId, 'test-op-2');
      expect(h.purchases.calls.last.item.id, apple.id);
    },
  );
  test('already owned is terminal and inventory is refreshed', () async {
    h.purchases.handler = (_) async {
      h.games.quantities[1]![ball.id] = 1;
      throw PersistentItemAlreadyOwnedException(itemId: ball.id);
    };
    await h.controller.load();
    await h.buy(ball);
    expect(h.state.result?.kind, ShopResultKind.alreadyOwned);
    expect(h.state.pending, isNull);
    expect(h.state.quantities[ball.id], 1);
    expect(h.state.canBuy(ball), isFalse);
    await h.controller.retry();
    expect(h.purchases.calls, hasLength(1));
  });
  for (final nextPeriod in [
    null,
    period(1, status: GamePeriodStatus.completed),
    period(1, id: 777),
  ]) {
    test(
      'retry keeps original context despite period ${nextPeriod?.id}/${nextPeriod?.status}',
      () async {
        h.purchases.handler = (_) async {
          h.games.periods[1] = nextPeriod;
          throw StateError('response lost');
        };
        await h.controller.load();
        await h.buy();
        final pending = h.state.pending!;
        expect(h.state.result?.kind, ShopResultKind.ambiguous);
        expect(h.state.canBuy(ball), isFalse);
        h.purchases.handler = (_) async => wallet(1, 460);
        await h.controller.retry();
        final replay = h.purchases.calls.last;
        expect(replay.operationId, pending.operationId);
        expect(replay.profileId, pending.profileId);
        expect(replay.periodId, 91);
        expect(replay.item, same(pending.item));
        expect(h.generatedIds, 1);
        expect(h.state.pending, isNull);
      },
    );
  }
  test(
    'profile switch discards pending and suppresses late purchase result',
    () async {
      final gate = Completer<void>();
      h.purchases.handler = (_) async {
        await gate.future;
        throw StateError('lost');
      };
      await h.controller.load();
      final purchase = h.buy();
      h.select(2);
      await pumpEventQueue();
      gate.complete();
      await purchase;
      expect(h.state.profileId, 2);
      expect(h.state.gameState?.walletBalance, 800);
      expect(h.state.pending, isNull);
      expect(h.state.result, isNull);
      await h.controller.retry();
      expect(h.purchases.calls, hasLength(1));
    },
  );
  test(
    'profile switch during purchase refresh cannot leak old inventory',
    () async {
      await h.controller.load();
      h.games.gatedStage = 'inventory';
      h.games.gate = Completer<void>();
      final purchase = h.buy();
      await pumpEventQueue();
      h.select(2);
      await pumpEventQueue();
      h.games.gate!.complete();
      await purchase;
      expect(h.state.profileId, 2);
      expect(h.state.result, isNull);
      expect(h.state.gameState?.walletBalance, 800);
    },
  );
  test('removed content invalidates ambiguous attempt safely', () async {
    h.purchases.handler = (_) async {
      h.content.items = [ball];
      throw StateError('unknown item');
    };
    await h.controller.load();
    await h.buy();
    expect(h.state.pending, isNull);
    expect(h.state.result?.kind, ShopResultKind.contentChanged);
    await h.controller.retry();
    expect(h.purchases.calls, hasLength(1));
  });
}
