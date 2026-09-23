import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/campaign_lifecycle.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/virtual_day_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ThingsLoad { loading, ready, noProfile, contentError, runtimeError }

enum ItemUseResultKind {
  success,
  noEffect,
  alreadyUsed,
  itemMissing,
  slotUnavailable,
  ambiguous,
}

class ItemUseResult {
  const ItemUseResult(this.kind, {this.message});

  final ItemUseResultKind kind;
  final String? message;
}

class ItemUseAttempt {
  const ItemUseAttempt({
    required this.profileId,
    required this.periodId,
    required this.item,
    required this.operationId,
    required this.slot,
  });

  final int profileId;
  final int? periodId;
  final ShopItem item;
  final String operationId;
  final PetActionSlot slot;
}

class ThingsState {
  const ThingsState({
    this.load = ThingsLoad.loading,
    this.profileId,
    this.period,
    this.freePlay = false,
    this.items = const [],
    this.quantities = const {},
    this.usageCounts = const {},
    this.equipped = const {},
    this.mutating = false,
    this.result,
    this.pending,
  });

  final ThingsLoad load;
  final int? profileId;
  final GamePeriod? period;
  final bool freePlay;
  final List<ShopItem> items;
  final Map<String, int> quantities;
  final Map<String, int> usageCounts;
  final Map<ShopEquipSlot, String> equipped;
  final bool mutating;
  final ItemUseResult? result;
  final ItemUseAttempt? pending;

  int quantityOf(String itemId) => quantities[itemId] ?? 0;

  int usageOf(String itemId, PetActionSlot slot) =>
      usageCounts['$itemId:${slot.storageValue}'] ?? 0;

  bool canUse(ShopItem item) {
    if (profileId == null ||
        load != ThingsLoad.ready ||
        mutating ||
        pending != null) {
      return false;
    }
    if (quantityOf(item.id) <= 0) return false;
    if (item.usagePolicy == ItemUsagePolicy.none) return false;
    if (freePlay) return true;
    if (period == null) return false;
    if (period!.status != GamePeriodStatus.active &&
        period!.status != GamePeriodStatus.readyToFinish) {
      return false;
    }
    if (item.usagePolicy == ItemUsagePolicy.toothbrush) {
      if (VirtualDayRules.morningToothbrushAvailable(period!.dayProgress)) {
        return usageOf(item.id, PetActionSlot.morning) == 0;
      }
      if (VirtualDayRules.eveningToothbrushAvailable(period!.dayProgress)) {
        return usageOf(item.id, PetActionSlot.evening) == 0;
      }
      return false;
    }
    if (item.usagePolicy == ItemUsagePolicy.oncePerPeriod) {
      return usageOf(item.id, PetActionSlot.defaultSlot) == 0;
    }
    return true;
  }

  String? actionStatus(ShopItem item) {
    if (freePlay) {
      return item.displaySection == ShopDisplaySection.accessories
          ? 'Аксессуар'
          : null;
    }
    if (item.displaySection == ShopDisplaySection.accessories) {
      return 'Аксессуар';
    }
    if (item.usagePolicy == ItemUsagePolicy.toothbrush) {
      if (period != null &&
          VirtualDayRules.morningToothbrushAvailable(period!.dayProgress)) {
        if (usageOf(item.id, PetActionSlot.morning) > 0) {
          return 'Утром использовано';
        }
      } else if (period != null &&
          VirtualDayRules.eveningToothbrushAvailable(period!.dayProgress)) {
        if (usageOf(item.id, PetActionSlot.evening) > 0) {
          return 'Вечером использовано';
        }
      } else {
        return 'Сейчас использовать нельзя';
      }
    } else if (item.usagePolicy == ItemUsagePolicy.oncePerPeriod) {
      if (usageOf(item.id, PetActionSlot.defaultSlot) > 0) {
        return 'Сегодня использовано';
      }
    }
    return null;
  }

  String actionButtonLabel(ShopItem item) {
    if (item.usagePolicy == ItemUsagePolicy.toothbrush &&
        period != null &&
        VirtualDayRules.eveningToothbrushAvailable(period!.dayProgress)) {
      return 'Почистить зубы вечером';
    }
    if (item.usagePolicy == ItemUsagePolicy.toothbrush) {
      return 'Почистить зубы';
    }
    return 'Использовать';
  }

  ThingsState withOperation({
    bool mutating = false,
    ItemUseResult? result,
    ItemUseAttempt? pending,
  }) => ThingsState(
    load: load,
    profileId: profileId,
    period: period,
    freePlay: freePlay,
    items: items,
    quantities: quantities,
    usageCounts: usageCounts,
    equipped: equipped,
    mutating: mutating,
    result: result,
    pending: pending,
  );
}

typedef ThingsOperationIdFactory = String Function(
  int profileId,
  String itemId,
);

final thingsControllerProvider =
    NotifierProvider<ThingsController, ThingsState>(ThingsController.new);

class ThingsController extends Notifier<ThingsState> {
  ThingsController({this.operationIdFactory});

  final ThingsOperationIdFactory? operationIdFactory;
  int _counter = 0;
  int _generation = 0;
  bool _alive = true;

  @override
  ThingsState build() {
    ref.onDispose(() => _alive = false);
    ref.listen<int?>(activeProfileIdProvider, (_, _) => unawaited(load()));
    return const ThingsState();
  }

  bool _current(int generation, int? profileId) =>
      _alive &&
      generation == _generation &&
      ref.read(activeProfileIdProvider) == profileId;

  Future<void> load() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (state.mutating && state.profileId == profileId) return;
    final previous = state.profileId == profileId ? state : const ThingsState();
    final generation = ++_generation;
    state = ThingsState(
      profileId: profileId,
      pending: previous.pending,
      result: previous.result,
    );
    final snapshot = await _readSnapshot(profileId);
    if (!_current(generation, profileId)) return;
    state = snapshot.withOperation(
      result: previous.result,
      pending: previous.pending,
    );
  }

  Future<ThingsState> _readSnapshot(int? profileId) async {
    if (profileId == null) {
      return const ThingsState(load: ThingsLoad.noProfile);
    }
    final content = ref.read(contentRepositoryProvider);
    final games = ref.read(gameRepositoryProvider);

    late List<ShopItem> allItems;
    try {
      allItems = await content.loadShopItems();
    } catch (_) {
      return ThingsState(load: ThingsLoad.contentError, profileId: profileId);
    }

    try {
      final period = await games.getCurrentPeriod(profileId);
      final freePlay =
          period == null &&
          (await ref.read(campaignLifecycleServiceProvider).load(profileId))
                  .mode ==
              CampaignMode.freePlay;
      final quantities = <String, int>{};
      final ownedItems = <ShopItem>[];

      for (final item in allItems) {
        final qty = await games.getInventoryQuantity(profileId, item.id);
        quantities[item.id] = qty;
        if (qty > 0) {
          ownedItems.add(item);
        }
      }

      final usageCounts = <String, int>{};
      if (period != null && period.id != null) {
        for (final item in ownedItems) {
          if (item.usagePolicy == ItemUsagePolicy.toothbrush) {
            usageCounts['${item.id}:${PetActionSlot.morning.storageValue}'] =
                await games.getPetDailyUsageCount(
                  profileId: profileId,
                  periodId: period.id!,
                  actionId: 'item:${item.id}',
                  slot: PetActionSlot.morning,
                );
            usageCounts['${item.id}:${PetActionSlot.evening.storageValue}'] =
                await games.getPetDailyUsageCount(
                  profileId: profileId,
                  periodId: period.id!,
                  actionId: 'item:${item.id}',
                  slot: PetActionSlot.evening,
                );
          } else if (item.usagePolicy == ItemUsagePolicy.oncePerPeriod) {
            usageCounts['${item.id}:${PetActionSlot.defaultSlot.storageValue}'] =
                await games.getPetDailyUsageCount(
                  profileId: profileId,
                  periodId: period.id!,
                  actionId: 'item:${item.id}',
                  slot: PetActionSlot.defaultSlot,
                );
          }
        }
      }

      return ThingsState(
        load: ThingsLoad.ready,
        profileId: profileId,
        period: period,
        freePlay: freePlay,
        items: List.unmodifiable(ownedItems),
        quantities: Map.unmodifiable(quantities),
        usageCounts: Map.unmodifiable(usageCounts),
        equipped: freePlay
            ? Map.unmodifiable(
                await ref.read(freePlayServiceProvider).equipped(profileId),
              )
            : const {},
      );
    } catch (_) {
      return ThingsState(load: ThingsLoad.runtimeError, profileId: profileId);
    }
  }

  Future<void> toggleAccessory(ShopItem item) async {
    final current = state;
    final slot = item.equipSlot;
    if (current.load != ThingsLoad.ready ||
        !current.freePlay ||
        current.mutating ||
        current.profileId == null ||
        slot == null ||
        current.quantityOf(item.id) <= 0) {
      return;
    }
    final generation = ++_generation;
    state = current.withOperation(mutating: true);
    try {
      final service = ref.read(freePlayServiceProvider);
      if (current.equipped[slot] == item.id) {
        await service.unequip(profileId: current.profileId!, slot: slot);
      } else {
        await service.equip(profileId: current.profileId!, itemId: item.id);
      }
      if (_current(generation, current.profileId)) {
        state = await _readSnapshot(current.profileId);
      }
      unawaited(ref.read(homeControllerProvider.notifier).load());
    } catch (_) {
      if (_current(generation, current.profileId)) {
        state = current.withOperation(
          result: const ItemUseResult(
            ItemUseResultKind.ambiguous,
            message: 'Не получилось изменить аксессуар. Попробуй ещё раз.',
          ),
        );
      }
    }
  }

  Future<void> use(ShopItem item) async {
    final current = state;
    if (current.load != ThingsLoad.ready || !current.canUse(item)) return;
    final profileId = current.profileId;
    final periodId = current.period?.id;
    if (profileId == null || (!current.freePlay && periodId == null)) return;

    final PetActionSlot slot;
    if (!current.freePlay && item.usagePolicy == ItemUsagePolicy.toothbrush) {
      if (VirtualDayRules.morningToothbrushAvailable(
        current.period!.dayProgress,
      )) {
        slot = PetActionSlot.morning;
      } else if (VirtualDayRules.eveningToothbrushAvailable(
        current.period!.dayProgress,
      )) {
        slot = PetActionSlot.evening;
      } else {
        return;
      }
    } else {
      slot = PetActionSlot.defaultSlot;
    }

    final String operationId;
    if (current.pending != null &&
        current.pending!.item.id == item.id &&
        current.pending!.slot == slot) {
      operationId = current.pending!.operationId;
    } else {
      operationId =
          operationIdFactory?.call(profileId, item.id) ??
          'things:$profileId:${item.id}:${slot.storageValue}:${DateTime.now().microsecondsSinceEpoch}:${++_counter}';
    }

    await _perform(
      ItemUseAttempt(
        profileId: profileId,
        periodId: periodId,
        item: item,
        operationId: operationId,
        slot: slot,
      ),
    );
  }

  Future<void> retry() async {
    final attempt = state.pending;
    if (attempt == null || state.mutating) return;
    await _perform(attempt);
  }

  void clearResult() {
    if (!state.mutating && state.pending == null) {
      state = state.withOperation();
    }
  }

  Future<void> _perform(ItemUseAttempt attempt) async {
    final service = ref.read(itemUseServiceProvider);
    final generation = ++_generation;
    state = state.withOperation(mutating: true, pending: attempt);

    ItemUseResult result;
    ItemUseAttempt? pending;

    try {
      if (attempt.periodId == null) {
        final outcome = await ref
            .read(freePlayServiceProvider)
            .useItem(
              profileId: attempt.profileId,
              itemId: attempt.item.id,
              operationId: attempt.operationId,
            );
        result = ItemUseResult(
          outcome.notice == null
              ? ItemUseResultKind.success
              : ItemUseResultKind.noEffect,
          message: outcome.notice,
        );
      } else {
        await service.useItem(
          profileId: attempt.profileId,
          periodId: attempt.periodId!,
          itemId: attempt.item.id,
          operationId: attempt.operationId,
          slot: attempt.slot,
        );
        result = const ItemUseResult(ItemUseResultKind.success);
      }
      pending = null;
      // Refresh Home so stat indicators update immediately
      unawaited(ref.read(homeControllerProvider.notifier).load());
    } on PetActionAlreadyUsedException {
      result = const ItemUseResult(
        ItemUseResultKind.alreadyUsed,
        message: 'Этот предмет сегодня уже использован.',
      );
      pending = null;
    } on PetItemNotOwnedException {
      result = const ItemUseResult(
        ItemUseResultKind.itemMissing,
        message: 'Этого предмета больше нет.',
      );
      pending = null;
    } on PetActionSlotUnavailableException {
      result = const ItemUseResult(
        ItemUseResultKind.slotUnavailable,
        message: 'Сейчас этот предмет использовать нельзя.',
      );
      pending = null;
    } catch (_) {
      result = const ItemUseResult(
        ItemUseResultKind.ambiguous,
        message: 'Не получилось использовать предмет. Попробуй ещё раз.',
      );
      pending = attempt;
    }

    if (!_current(generation, attempt.profileId)) return;
    final snapshot = await _readSnapshot(attempt.profileId);
    if (!_current(generation, attempt.profileId)) return;
    state = snapshot.withOperation(result: result, pending: pending);
  }
}
