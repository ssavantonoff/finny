import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/features/things/things_controller.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/purchase_exception.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ShopLoad {
  loading,
  ready,
  noProfile,
  contentError,
  runtimeError,
  noGameState,
}

enum ShopResultKind {
  success,
  insufficientFunds,
  alreadyOwned,
  ambiguous,
  contentChanged,
}

class ShopResult {
  const ShopResult(this.kind, {this.itemPrice, this.availableBalance});

  final ShopResultKind kind;
  final int? itemPrice;
  final int? availableBalance;
}

class PurchaseAttempt {
  const PurchaseAttempt({
    required this.profileId,
    required this.periodId,
    required this.item,
    required this.operationId,
    this.promotionId,
    this.saleItemId,
  });

  final int profileId;
  final int periodId;
  final ShopItem item;
  final String operationId;
  final String? promotionId;
  final String? saleItemId;
}

class ShopState {
  const ShopState({
    this.load = ShopLoad.loading,
    this.profileId,
    this.items = const [],
    this.gameState,
    this.period,
    this.quantities = const {},
    this.promotion,
    this.promotionPurchased = false,
    this.saleOffers = const [],
    this.purchasing = false,
    this.result,
    this.pending,
  });

  final ShopLoad load;
  final int? profileId;
  final List<ShopItem> items;
  final GameState? gameState;
  final GamePeriod? period;
  final Map<String, int> quantities;
  final ShopPromotion? promotion;
  final bool promotionPurchased;
  final List<DayFiveSaleOffer> saleOffers;
  final bool purchasing;
  final ShopResult? result;
  final PurchaseAttempt? pending;

  ShopItem? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  bool isPromotionActiveFor(ShopItem item) =>
      period?.periodNumber == 4 &&
      promotion != null &&
      !promotionPurchased &&
      promotion!.itemId == item.id;

  bool get isDayFiveSaleDay => period?.periodNumber == 5;

  DayFiveSaleOffer? activeSaleFor(ShopItem item) {
    if (!isDayFiveSaleDay) return null;
    for (final offer in saleOffers) {
      if (offer.itemId == item.id && !offer.purchased) return offer;
    }
    return null;
  }

  bool isDiscountActiveFor(ShopItem item) =>
      isPromotionActiveFor(item) || activeSaleFor(item) != null;

  int? discountAmountFor(ShopItem item) =>
      activeSaleFor(item)?.discountAmount ??
      (isPromotionActiveFor(item) ? item.price - promotion!.promoPrice : null);

  int effectivePriceFor(ShopItem item) {
    final sale = activeSaleFor(item);
    if (sale != null) return item.price - sale.discountAmount;
    return isPromotionActiveFor(item) ? promotion!.promoPrice : item.price;
  }

  String? unavailableReason(ShopItem item) {
    if (profileId == null) return 'Профиль пока не выбран.';
    if (load != ShopLoad.ready) return 'Сначала обнови магазин.';
    if (item.unlockType != 'available') return 'Этот предмет пока недоступен.';
    if (item.persistent && (quantities[item.id] ?? 0) > 0) return 'Уже куплено';
    if (period?.id == null || period!.id! <= 0) {
      return 'Сначала начни игровой период.';
    }
    if (period!.status == GamePeriodStatus.planning) {
      return 'Сначала подтверди план.';
    }
    if (period!.status != GamePeriodStatus.active &&
        period!.status != GamePeriodStatus.readyToFinish) {
      return 'В этом периоде покупки недоступны.';
    }
    if (!quantities.containsKey(item.id)) return 'Сначала обнови магазин.';
    if (pending != null) return 'Сначала проверь предыдущую покупку.';
    return null;
  }

  bool canBuy(ShopItem item) => !purchasing && unavailableReason(item) == null;

  ShopState withOperation({
    bool purchasing = false,
    ShopResult? result,
    PurchaseAttempt? pending,
  }) => ShopState(
    load: load,
    profileId: profileId,
    items: items,
    gameState: gameState,
    period: period,
    quantities: quantities,
    promotion: promotion,
    promotionPurchased: promotionPurchased,
    saleOffers: saleOffers,
    purchasing: purchasing,
    result: result,
    pending: pending,
  );
}

typedef ShopOperationIdFactory = String Function(int profileId, String itemId);

final shopControllerProvider = NotifierProvider<ShopController, ShopState>(
  ShopController.new,
);

class ShopController extends Notifier<ShopState> {
  ShopController({this.operationIdFactory});

  final ShopOperationIdFactory? operationIdFactory;
  int _counter = 0;
  int _generation = 0;
  bool _alive = true;

  @override
  ShopState build() {
    ref.onDispose(() => _alive = false);
    ref.listen<int?>(activeProfileIdProvider, (_, _) => unawaited(load()));
    return const ShopState();
  }

  bool _current(int generation, int? profileId) =>
      _alive &&
      generation == _generation &&
      ref.read(activeProfileIdProvider) == profileId;

  Future<void> load() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (state.purchasing && state.profileId == profileId) return;
    final previous = state.profileId == profileId ? state : const ShopState();
    final generation = ++_generation;
    state = ShopState(
      profileId: profileId,
      pending: previous.pending,
      result: previous.result,
    );
    final snapshot = await _readSnapshot(profileId);
    if (!_current(generation, profileId)) return;
    state = _reconcile(snapshot, previous.result, previous.pending);
  }

  Future<ShopState> _readSnapshot(
    int? profileId, {
    GameState? purchasedState,
  }) async {
    if (profileId == null) return const ShopState(load: ShopLoad.noProfile);
    final content = ref.read(contentRepositoryProvider);
    final games = ref.read(gameRepositoryProvider);
    late List<ShopItem> items;
    try {
      items = List.unmodifiable(await content.loadShopItems());
      if (items.map((item) => item.id).toSet().length != items.length) {
        throw StateError('Duplicate content IDs.');
      }
    } catch (_) {
      return ShopState(
        load: ShopLoad.contentError,
        profileId: profileId,
        gameState: purchasedState,
      );
    }
    try {
      final game = purchasedState ?? await games.getGameState(profileId);
      if (game == null) {
        return ShopState(
          load: ShopLoad.noGameState,
          profileId: profileId,
          items: items,
        );
      }
      final period = await games.getCurrentPeriod(profileId);
      final quantities = <String, int>{};
      for (final item in items) {
        quantities[item.id] = await games.getInventoryQuantity(
          profileId,
          item.id,
        );
      }
      final promotions = period?.id == null
          ? const <ShopPromotion>[]
          : await content.loadPromotions();
      final promotionState =
          period?.id == null ||
              !promotions.any(
                (promotion) => promotion.period == period!.periodNumber,
              )
          ? null
          : await ref
                .read(specialPurchaseServiceProvider)
                .loadPromotionState(
                  profileId: profileId,
                  periodId: period!.id!,
                  periodNumber: period.periodNumber,
                );
      final saleOffers = period?.periodNumber == 5 && period?.id != null
          ? await ref
                .read(specialPurchaseServiceProvider)
                .loadOrCreateDayFiveSale(
                  profileId: profileId,
                  periodId: period!.id!,
                )
          : const <DayFiveSaleOffer>[];
      return ShopState(
        load: ShopLoad.ready,
        profileId: profileId,
        items: items,
        gameState: game,
        period: period,
        quantities: Map.unmodifiable(quantities),
        promotion: promotionState?.promotion,
        promotionPurchased: promotionState?.purchased ?? false,
        saleOffers: saleOffers,
      );
    } catch (_) {
      // A failed inventory/period read must never look like zero ownership/no period.
      return ShopState(
        load: ShopLoad.runtimeError,
        profileId: profileId,
        items: items,
        gameState: purchasedState,
      );
    }
  }

  ShopState _reconcile(
    ShopState snapshot,
    ShopResult? result,
    PurchaseAttempt? pending,
  ) {
    if (pending != null &&
        snapshot.load != ShopLoad.contentError &&
        !sameShopItem(snapshot.itemById(pending.item.id), pending.item)) {
      return snapshot.withOperation(
        result: const ShopResult(ShopResultKind.contentChanged),
      );
    }
    return snapshot.withOperation(result: result, pending: pending);
  }

  Future<void> buy(
    String itemId, {
    required int profileId,
    required int periodId,
  }) async {
    final current = state;
    final item = current.itemById(itemId);
    if (item == null) return;
    if (ref.read(activeProfileIdProvider) != profileId ||
        current.profileId != profileId ||
        current.period?.id != periodId ||
        !current.canBuy(item)) {
      return;
    }
    final id =
        operationIdFactory?.call(profileId, item.id) ??
        'shop:$profileId:${item.id}:${DateTime.now().microsecondsSinceEpoch}:${++_counter}';
    await _perform(
      PurchaseAttempt(
        profileId: profileId,
        periodId: periodId,
        item: item,
        operationId: id,
        promotionId: current.isPromotionActiveFor(item)
            ? current.promotion!.id
            : null,
        saleItemId: current.activeSaleFor(item) != null ? item.id : null,
      ),
    );
  }

  Future<void> retry() async {
    final attempt = state.pending;
    if (attempt == null ||
        state.purchasing ||
        ref.read(activeProfileIdProvider) != attempt.profileId ||
        state.profileId != attempt.profileId) {
      return;
    }
    // Replay intentionally uses the original period even when there is no current one.
    await _perform(attempt);
  }

  void clearResult() {
    if (!state.purchasing && state.pending == null) {
      state = state.withOperation();
    }
  }

  Future<void> _perform(PurchaseAttempt attempt) async {
    final generation = ++_generation;
    state = state.withOperation(purchasing: true, pending: attempt);
    GameState? purchasedState;
    ShopResult result;
    PurchaseAttempt? pending;
    try {
      purchasedState = attempt.saleItemId != null
          ? await ref
                .read(specialPurchaseServiceProvider)
                .purchaseDayFiveSale(
                  profileId: attempt.profileId,
                  periodId: attempt.periodId,
                  itemId: attempt.saleItemId!,
                  operationId: attempt.operationId,
                )
          : attempt.promotionId == null
          ? await ref
                .read(purchaseServiceProvider)
                .purchase(
                  profileId: attempt.profileId,
                  periodId: attempt.periodId,
                  itemId: attempt.item.id,
                  operationId: attempt.operationId,
                )
          : await ref
                .read(specialPurchaseServiceProvider)
                .purchasePromotion(
                  profileId: attempt.profileId,
                  periodId: attempt.periodId,
                  promotionId: attempt.promotionId!,
                  operationId: attempt.operationId,
                );
      result = const ShopResult(ShopResultKind.success);
      unawaited(ref.read(thingsControllerProvider.notifier).load());
    } on InsufficientFundsException catch (error) {
      result = ShopResult(
        ShopResultKind.insufficientFunds,
        itemPrice: error.itemPrice,
        availableBalance: error.availableBalance,
      );
    } on PersistentItemAlreadyOwnedException {
      result = const ShopResult(ShopResultKind.alreadyOwned);
    } catch (_) {
      result = const ShopResult(ShopResultKind.ambiguous);
      pending = attempt;
    }
    if (!_current(generation, attempt.profileId)) return;
    // Refresh failure does not turn an acknowledged success into a retryable purchase.
    final snapshot = await _readSnapshot(
      attempt.profileId,
      purchasedState: purchasedState,
    );
    if (!_current(generation, attempt.profileId)) return;
    state = _reconcile(snapshot, result, pending);
  }
}

bool sameShopItem(ShopItem? a, ShopItem b) =>
    a != null &&
    a.id == b.id &&
    a.name == b.name &&
    a.price == b.price &&
    a.category == b.category &&
    a.persistent == b.persistent &&
    a.effectType == b.effectType &&
    a.effectValue == b.effectValue &&
    a.usagePolicy == b.usagePolicy &&
    a.effects == b.effects &&
    a.unlockType == b.unlockType &&
    a.displaySection == b.displaySection &&
    a.equipSlot == b.equipSlot;

String shopSectionLabel(ShopDisplaySection section) => switch (section) {
  ShopDisplaySection.food => 'Еда',
  ShopDisplaySection.care => 'Уход',
  ShopDisplaySection.toys => 'Игрушки',
  ShopDisplaySection.accessories => 'Украшения',
};

String shopCategory(ShopItem item) => shopSectionLabel(item.displaySection);

String? shopEffect(ShopItem item) {
  final effects = item.petEffects;
  final labels = [
    if (effects.satiety > 0) 'Сытость Финни +${effects.satiety}',
    if (effects.care > 0) 'Уход за Финни +${effects.care}',
    if (effects.mood > 0) 'Настроение Финни +${effects.mood}',
  ];
  return labels.isEmpty ? null : labels.join(', ');
}
