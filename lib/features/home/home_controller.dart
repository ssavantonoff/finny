import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/features/home/campaign_event_controller.dart';
import 'package:finny/models/content_entry.dart';
import 'package:finny/models/completed_goal.dart';
import 'package:finny/models/campaign_lifecycle.dart';
import 'package:finny/models/day_lifecycle.dart';
import 'package:finny/models/day_five_task.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/story_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class HomeViewState {
  const HomeViewState();
}

class HomeLoading extends HomeViewState {
  const HomeLoading();
}

class HomeNeedsBootstrap extends HomeViewState {
  const HomeNeedsBootstrap();
}

class HomeFailure extends HomeViewState {
  const HomeFailure();
}

class HomeReady extends HomeViewState {
  HomeReady({
    required this.profile,
    required this.pet,
    required this.gameState,
    required this.period,
    required this.definition,
    required this.completedDays,
    required this.allDaysCompleted,
    this.freePlay = false,
    this.activeGoal,
    this.bowlEvent,
    this.dayFiveTaskCompletion,
    this.petUsageCount = 0,
    this.interacting = false,
    this.interactionNotice,
    this.pendingInteraction,
    this.startingDay = false,
    this.startFailed = false,
    this.finishingDay = false,
    this.finishFailed = false,
    Map<ShopEquipSlot, String> equippedAccessories = const {},
    List<CompletedGoal> completedGoals = const [],
    List<ShopItem> shopItems = const [],
    List<SavingsGoal> goals = const [],
    this.ownedPersistentItemCount = 0,
  }) : equippedAccessories = Map.unmodifiable(equippedAccessories),
       completedGoals = List.unmodifiable(completedGoals),
       shopItems = List.unmodifiable(shopItems),
       goals = List.unmodifiable(goals);

  final Profile profile;
  final Pet pet;
  final GameState gameState;
  final GamePeriod? period;
  final PeriodDefinition? definition;
  final int completedDays;
  final bool allDaysCompleted;
  final bool freePlay;
  final SavingsGoal? activeGoal;
  final StoryEventSnapshot? bowlEvent;
  final DayFiveTaskCompletion? dayFiveTaskCompletion;
  final int petUsageCount;
  final bool interacting;
  final String? interactionNotice;
  final ({FreePetInteraction interaction, String operationId})?
  pendingInteraction;
  final bool startingDay;
  final bool startFailed;
  final bool finishingDay;
  final bool finishFailed;
  final Map<ShopEquipSlot, String> equippedAccessories;
  final List<CompletedGoal> completedGoals;
  final List<ShopItem> shopItems;
  final List<SavingsGoal> goals;
  final int ownedPersistentItemCount;

  HomeReady copyWith({
    SavingsGoal? activeGoal,
    StoryEventSnapshot? bowlEvent,
    int? petUsageCount,
    bool? interacting,
    String? interactionNotice,
    bool clearInteractionNotice = false,
    ({FreePetInteraction interaction, String operationId})? pendingInteraction,
    bool clearPendingInteraction = false,
    bool? startingDay,
    bool? startFailed,
    bool? finishingDay,
    bool? finishFailed,
  }) => HomeReady(
    profile: profile,
    pet: pet,
    gameState: gameState,
    period: period,
    definition: definition,
    completedDays: completedDays,
    allDaysCompleted: allDaysCompleted,
    freePlay: freePlay,
    activeGoal: activeGoal ?? this.activeGoal,
    bowlEvent: bowlEvent ?? this.bowlEvent,
    dayFiveTaskCompletion: dayFiveTaskCompletion,
    petUsageCount: petUsageCount ?? this.petUsageCount,
    interacting: interacting ?? this.interacting,
    interactionNotice: clearInteractionNotice
        ? null
        : (interactionNotice ?? this.interactionNotice),
    pendingInteraction: clearPendingInteraction
        ? null
        : (pendingInteraction ?? this.pendingInteraction),
    startingDay: startingDay ?? this.startingDay,
    startFailed: startFailed ?? this.startFailed,
    finishingDay: finishingDay ?? this.finishingDay,
    finishFailed: finishFailed ?? this.finishFailed,
    equippedAccessories: equippedAccessories,
    completedGoals: completedGoals,
    shopItems: shopItems,
    goals: goals,
    ownedPersistentItemCount: ownedPersistentItemCount,
  );
}

typedef FreeInteractionOperationIdFactory = String Function(
  int profileId,
  String actionId,
);

final homeControllerProvider = NotifierProvider<HomeController, HomeViewState>(
  HomeController.new,
);

class HomeController extends Notifier<HomeViewState> {
  HomeController({this.operationIdFactory});

  final FreeInteractionOperationIdFactory? operationIdFactory;
  int _loadGeneration = 0;
  int _interactionCounter = 0;
  bool _startingDay = false;
  bool _finishingDay = false;
  bool _interacting = false;
  ({FreePetInteraction interaction, String operationId})? _pendingInteraction;

  @override
  HomeViewState build() {
    ref.listen<int?>(activeProfileIdProvider, (_, _) => unawaited(load()));
    return const HomeLoading();
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    state = const HomeLoading();
    final loaded = await _readSnapshot();
    if (ref.mounted && generation == _loadGeneration) state = loaded;
  }

  Future<GamePeriod?> startDay() async {
    final current = state;
    if (_startingDay ||
        current is! HomeReady ||
        current.period != null ||
        current.allDaysCompleted) {
      return null;
    }
    _startingDay = true;
    state = current.copyWith(startingDay: true, startFailed: false);
    Object? mutationError;
    try {
      await ref
          .read(periodServiceProvider)
          .startNextPeriod(profileId: current.profile.id!);
    } catch (error) {
      mutationError = error;
    }

    final refreshed = await _readSnapshot();
    _startingDay = false;
    if (refreshed case HomeReady(:final period)) {
      if (period != null && period.status == GamePeriodStatus.planning) {
        state = refreshed;
        return period;
      }
      state = refreshed.copyWith(startFailed: mutationError != null);
      return null;
    }
    state = refreshed;
    return null;
  }

  Future<BedtimeDecision?> evaluateBedtime() async {
    final current = state;
    final period = current is HomeReady ? current.period : null;
    if (current is! HomeReady ||
        period?.id == null ||
        (period!.status != GamePeriodStatus.active &&
            period.status != GamePeriodStatus.readyToFinish)) {
      return null;
    }
    try {
      return await ref
          .read(dayLifecycleServiceProvider)
          .evaluateBedtime(
            profileId: current.profile.id!,
            periodId: period.id!,
          );
    } catch (_) {
      state = current.copyWith(finishFailed: true);
      return null;
    }
  }

  Future<bool> sleep({required bool allowFallback}) async {
    final current = state;
    final period = current is HomeReady ? current.period : null;
    if (_finishingDay ||
        current is! HomeReady ||
        period?.id == null ||
        (period!.status != GamePeriodStatus.active &&
            period.status != GamePeriodStatus.readyToFinish)) {
      return false;
    }
    _finishingDay = true;
    state = current.copyWith(finishingDay: true, finishFailed: false);
    try {
      await ref
          .read(dayLifecycleServiceProvider)
          .sleep(
            profileId: current.profile.id!,
            periodId: period.id!,
            allowFallback: allowFallback,
          );
    } catch (_) {
      _finishingDay = false;
      final refreshed = await _readSnapshot();
      if (refreshed is HomeReady &&
          refreshed.completedDays > current.completedDays) {
        state = refreshed;
        return true;
      }
      state = current.copyWith(finishingDay: false, finishFailed: true);
      return false;
    }
    _finishingDay = false;
    state = await _readSnapshot();
    return true;
  }

  Future<bool> performFreeInteraction(FreePetInteraction interaction) async {
    final current = state;
    if (_interacting ||
        current is! HomeReady ||
        (!current.freePlay && current.period == null) ||
        (!current.freePlay &&
            current.period!.status != GamePeriodStatus.active &&
            current.period!.status != GamePeriodStatus.readyToFinish)) {
      return false;
    }
    _interacting = true;
    final profileId = current.profile.id!;
    final periodId = current.period?.id;
    final actionId = interaction.actionId;

    final String operationId;
    if (_pendingInteraction != null &&
        _pendingInteraction!.interaction == interaction) {
      operationId = _pendingInteraction!.operationId;
    } else {
      operationId =
          operationIdFactory?.call(profileId, actionId) ??
          'free:$profileId:${interaction.name}:${periodId ?? 'play'}:${DateTime.now().microsecondsSinceEpoch}:${++_interactionCounter}';
      _pendingInteraction = (
        interaction: interaction,
        operationId: operationId,
      );
    }

    state = current.copyWith(
      interacting: true,
      pendingInteraction: _pendingInteraction,
      clearInteractionNotice: true,
    );

    try {
      if (current.freePlay) {
        await ref
            .read(freePlayServiceProvider)
            .pet(profileId: profileId, operationId: operationId);
      } else {
        await ref
            .read(itemUseServiceProvider)
            .performFreeInteraction(
              profileId: profileId,
              periodId: periodId!,
              interaction: interaction,
              operationId: operationId,
            );
      }
      _pendingInteraction = null;
      _interacting = false;
      final refreshed = await _readSnapshot();
      state = refreshed;
      if (!current.freePlay) {
        unawaited(ref.read(campaignEventControllerProvider.notifier).load());
      }
      return true;
    } on PetActionAlreadyUsedException {
      _pendingInteraction = null;
      _interacting = false;
      final refreshed = await _readSnapshot();
      if (refreshed is HomeReady) {
        state = refreshed.copyWith(
          interactionNotice: 'Это действие сегодня уже выполнено.',
          clearPendingInteraction: true,
        );
      } else {
        state = refreshed;
      }
      return false;
    } catch (_) {
      _interacting = false;
      final refreshed = await _readSnapshot();
      if (refreshed is HomeReady) {
        state = refreshed.copyWith(
          interacting: false,
          pendingInteraction: _pendingInteraction,
          interactionNotice:
              'Не получилось выполнить действие. Попробуй ещё раз.',
        );
      } else {
        state = refreshed;
      }
      return false;
    }
  }

  Future<bool> prepareBowlPurchase() async {
    final current = state;
    if (current is! HomeReady || current.period?.id == null) return false;
    final snapshot = await ref
        .read(storyEventServiceProvider)
        .armOrLoadDay3Bowl(profileId: current.profile.id!);
    if (snapshot == null || snapshot.isPurchased || !snapshot.isOutstanding) {
      return false;
    }
    await ref
        .read(campaignEventControllerProvider.notifier)
        .prepareBowlPurchase();
    return true;
  }

  Future<HomeViewState> _readSnapshot() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return const HomeFailure();
    try {
      final values = await Future.wait<Object?>([
        ref.read(profileRepositoryProvider).findById(profileId),
        ref.read(gameRepositoryProvider).getPet(profileId),
        ref.read(gameRepositoryProvider).getGameState(profileId),
        ref.read(gameRepositoryProvider).getPeriods(profileId),
        ref.read(contentRepositoryProvider).loadPeriods(),
        ref.read(contentRepositoryProvider).loadGoals(),
        ref.read(contentRepositoryProvider).loadShopItems(),
        ref.read(gameRepositoryProvider).getCompletedGoals(profileId),
      ]);
      if (!ref.mounted) return const HomeFailure();
      final profile = values[0] as Profile?;
      final pet = values[1] as Pet?;
      final gameState = values[2] as GameState?;
      final periods = values[3] as List<GamePeriod>;
      final definitions = values[4] as List<PeriodDefinition>;
      final goals = values[5] as List<SavingsGoal>;
      final shopItems = values[6] as List<ShopItem>;
      final completedGoals = values[7] as List<CompletedGoal>;
      final freePlay =
          periods.length >= 5 &&
          (await ref.read(campaignLifecycleServiceProvider).load(profileId))
                  .mode ==
              CampaignMode.freePlay;

      if (profile == null || profile.profileType != ProfileType.normal) {
        return const HomeFailure();
      }
      if (pet == null) return const HomeNeedsBootstrap();
      if (gameState == null) return const HomeFailure();

      final unfinished = periods
          .where((period) => period.status != GamePeriodStatus.completed)
          .toList(growable: false);
      if (unfinished.length > 1) return const HomeFailure();
      final period = unfinished.isEmpty ? null : unfinished.single;
      PeriodDefinition? definition;
      if (period != null) {
        final matches = definitions
            .where(
              (candidate) =>
                  candidate.id == period.definitionId &&
                  candidate.number == period.periodNumber,
            )
            .toList(growable: false);
        if (matches.length != 1) return const HomeFailure();
        definition = matches.single;
      }

      SavingsGoal? activeGoal;
      if (gameState.activeGoalId != null) {
        final matches = goals.where((g) => g.id == gameState.activeGoalId);
        if (matches.isNotEmpty) activeGoal = matches.single;
      }

      int petUsageCount = 0;
      if (!freePlay &&
          period != null &&
          period.id != null &&
          (period.status == GamePeriodStatus.active ||
              period.status == GamePeriodStatus.readyToFinish)) {
        petUsageCount = await ref
            .read(gameRepositoryProvider)
            .getPetDailyUsageCount(
              profileId: profileId,
              periodId: period.id!,
              actionId: FreePetInteraction.pet.actionId,
              slot: PetActionSlot.defaultSlot,
            );
      }

      StoryEventSnapshot? bowlEvent;
      if (!freePlay &&
          period != null &&
          period.periodNumber >= 3 &&
          period.periodNumber <= 5) {
        bowlEvent = await ref
            .read(storyEventServiceProvider)
            .armOrLoadDay3Bowl(profileId: profileId);
      } else if (!freePlay && periods.any((item) => item.periodNumber >= 3)) {
        bowlEvent = await ref
            .read(storyEventServiceProvider)
            .loadDay3Bowl(profileId: profileId);
      }

      final dayFiveTaskCompletion =
          period?.periodNumber == 5 && period?.id != null
          ? await ref
                .read(taskServiceProvider)
                .loadDayFiveCompletion(
                  profileId: profileId,
                  periodId: period!.id!,
                )
          : null;

      final equippedAccessories = freePlay
          ? await ref.read(freePlayServiceProvider).equipped(profileId)
          : const <ShopEquipSlot, String>{};
      var ownedPersistentItemCount = 0;
      if (freePlay) {
        for (final item in shopItems.where((item) => item.persistent)) {
          if (await ref
                  .read(gameRepositoryProvider)
                  .getInventoryQuantity(profileId, item.id) >
              0) {
            ownedPersistentItemCount++;
          }
        }
      }
      if (!ref.mounted || ref.read(activeProfileIdProvider) != profileId) {
        return const HomeFailure();
      }

      return HomeReady(
        profile: profile,
        pet: pet,
        gameState: gameState,
        period: period,
        definition: definition,
        completedDays: periods
            .where((item) => item.status == GamePeriodStatus.completed)
            .length,
        allDaysCompleted:
            definitions.isNotEmpty &&
            periods.length == definitions.length &&
            periods.every((item) => item.status == GamePeriodStatus.completed),
        freePlay: freePlay,
        activeGoal: activeGoal,
        bowlEvent: bowlEvent,
        dayFiveTaskCompletion: dayFiveTaskCompletion,
        petUsageCount: petUsageCount,
        pendingInteraction: _pendingInteraction,
        equippedAccessories: equippedAccessories,
        completedGoals: completedGoals
            .where((goal) => goal.profileId == profileId)
            .toList(growable: false),
        shopItems: shopItems,
        goals: goals,
        ownedPersistentItemCount: ownedPersistentItemCount,
      );
    } catch (_) {
      return const HomeFailure();
    }
  }
}
