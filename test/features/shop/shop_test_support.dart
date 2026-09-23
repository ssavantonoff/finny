import '../../helpers/campaign_only_lifecycle_service.dart';

import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/core/database/app_database.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../helpers/test_database.dart';

const apple = ShopItem(
  id: 'food_apple',
  name: 'Яблоко',
  category: ShopItemCategory.need,
  price: 40,
  persistent: false,
  effectType: 'satiety',
  effectValue: 10,
  unlockType: 'available',
  displaySection: ShopDisplaySection.food,
);
const feed = ShopItem(
  id: 'food_feed',
  name: 'Корм',
  category: ShopItemCategory.need,
  price: 90,
  persistent: false,
  effectType: 'satiety',
  effectValue: 50,
  unlockType: 'available',
  displaySection: ShopDisplaySection.food,
  usagePolicy: ItemUsagePolicy.unlimited,
);
const ball = ShopItem(
  id: 'toy_ball',
  name: 'Мяч',
  category: ShopItemCategory.want,
  price: 120,
  persistent: true,
  effectType: 'mood',
  effectValue: 8,
  unlockType: 'available',
  displaySection: ShopDisplaySection.toys,
);
const frisbee = ShopItem(
  id: 'toy_frisbee',
  name: 'Фрисби',
  category: ShopItemCategory.want,
  price: 140,
  persistent: true,
  effectType: 'mood',
  effectValue: 40,
  unlockType: 'available',
  displaySection: ShopDisplaySection.toys,
  usagePolicy: ItemUsagePolicy.oncePerPeriod,
);
const brush = ShopItem(
  id: 'care_comb',
  name: 'Расчёска',
  category: ShopItemCategory.need,
  price: 70,
  persistent: true,
  effectType: 'care',
  effectValue: 25,
  unlockType: 'available',
  displaySection: ShopDisplaySection.care,
  usagePolicy: ItemUsagePolicy.oncePerPeriod,
);
const bow = ShopItem(
  id: 'accessory_bow',
  name: 'Бантик',
  category: ShopItemCategory.want,
  price: 80,
  persistent: true,
  effectType: 'none',
  effectValue: 0,
  unlockType: 'available',
  displaySection: ShopDisplaySection.accessories,
  equipSlot: ShopEquipSlot.head,
  usagePolicy: ItemUsagePolicy.none,
);

GameState wallet(int profileId, [int balance = 500]) => GameState(
  profileId: profileId,
  walletBalance: balance,
  currentPeriod: 3,
  savedAmount: 0,
  updatedAt: DateTime.utc(2026),
);
GamePeriod period(
  int profileId, {
  int id = 91,
  GamePeriodStatus status = GamePeriodStatus.active,
}) => GamePeriod(
  id: id,
  profileId: profileId,
  definitionId: 'day-3',
  periodNumber: 3,
  startWalletBalance: 0,
  baseIncome: 500,
  extraIncome: 0,
  plannedNeed: 100,
  plannedWant: 100,
  plannedSavings: 100,
  plannedFree: 200,
  actualNeed: 0,
  actualWant: 0,
  actualSavings: 0,
  requiredCheckpoints: const [],
  resolvedCheckpoints: const [],
  growthPointsEarned: 0,
  status: status,
  createdAt: DateTime.utc(2026),
);

class ShopContent implements ContentRepository {
  List<ShopItem> items = [apple, brush, ball, bow];
  Object? error;
  Completer<void>? gate;
  @override
  Future<List<StoryPurchase>> loadStoryPurchases() async => const [];
  @override
  Future<List<ShopPromotion>> loadPromotions() async => const [];
  @override
  Future<List<ShopItem>> loadShopItems() async {
    final snapshot = items;
    final failure = error;
    await gate?.future;
    if (failure != null) throw failure;
    return snapshot;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class ShopGames implements GameRepository {
  final states = <int, GameState?>{1: wallet(1), 2: wallet(2, 800)};
  final periods = <int, GamePeriod?>{1: period(1), 2: period(2, id: 92)};
  final quantities = <int, Map<String, int>>{1: {}, 2: {}};
  final inventoryReads = <(int, String)>[];
  Object? gameError;
  Object? periodError;
  Object? inventoryError;
  String? gatedStage;
  int gatedProfile = 1;
  Completer<void>? gate;
  Future<void> wait(String stage, int profileId) async {
    if (gatedStage == stage && profileId == gatedProfile) await gate?.future;
  }

  @override
  Future<GameState?> getGameState(int profileId) async {
    final value = states[profileId];
    await wait('game', profileId);
    if (gameError != null) throw gameError!;
    return value;
  }

  @override
  Future<GamePeriod?> getCurrentPeriod(int profileId) async {
    final value = periods[profileId];
    await wait('period', profileId);
    if (periodError != null) throw periodError!;
    return value;
  }

  @override
  Future<int> getInventoryQuantity(int profileId, String itemId) async {
    inventoryReads.add((profileId, itemId));
    final value = quantities[profileId]?[itemId] ?? 0;
    await wait('inventory', profileId);
    if (inventoryError != null) throw inventoryError!;
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class ShopPurchases extends PurchaseService {
  ShopPurchases(ShopContent content)
    : _content = content,
      super(_UnusedPurchasePort(), content);
  final ShopContent _content;
  final calls = <PurchaseAttempt>[];
  Future<GameState> Function(PurchaseAttempt)? handler;
  @override
  Future<GameState> purchase({
    required int profileId,
    required int periodId,
    required String itemId,
    required String operationId,
  }) async {
    final attempt = PurchaseAttempt(
      profileId: profileId,
      periodId: periodId,
      item: _content.items.singleWhere((item) => item.id == itemId),
      operationId: operationId,
    );
    calls.add(attempt);
    return handler == null ? wallet(profileId, 77) : await handler!(attempt);
  }
}

class _UnusedPurchasePort implements PurchasePort {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class ShopHarness {
  ShopHarness({int? profileId = 1}) {
    purchases = ShopPurchases(content);
    container = ProviderContainer(
      overrides: [
        campaignLifecycleServiceProvider.overrideWithValue(
          CampaignOnlyLifecycleService(),
        ),
        appDatabaseProvider.overrideWithValue(database),
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(content),
        purchaseServiceProvider.overrideWithValue(purchases),
        shopControllerProvider.overrideWith(
          () => ShopController(
            operationIdFactory: (_, _) => 'test-op-${++generatedIds}',
          ),
        ),
      ],
    );
    if (profileId != null) {
      container
          .read(activeProfileIdProvider.notifier)
          .setActiveProfileId(profileId);
    }
    controller = container.read(shopControllerProvider.notifier);
  }
  final games = ShopGames();
  final AppDatabase database = createTestDatabase();
  final content = ShopContent();
  late final ShopPurchases purchases;
  late final ProviderContainer container;
  late final ShopController controller;
  int generatedIds = 0;
  ShopState get state => container.read(shopControllerProvider);
  Future<void> buy([ShopItem item = apple]) =>
      controller.buy(item.id, profileId: 1, periodId: 91);
  void select(int? id) {
    final active = container.read(activeProfileIdProvider.notifier);
    id == null ? active.clear() : active.setActiveProfileId(id);
  }

  void dispose() {
    container.dispose();
    unawaited(database.close());
  }
}
