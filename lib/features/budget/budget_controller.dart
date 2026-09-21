import 'package:finny/app/providers.dart';
import 'package:finny/models/content_entry.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/services/budget_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BudgetCategory { need, want, savings }

sealed class BudgetViewState {
  const BudgetViewState();
}

class BudgetLoading extends BudgetViewState {
  const BudgetLoading();
}

class BudgetNeedsBootstrap extends BudgetViewState {
  const BudgetNeedsBootstrap();
}

class BudgetFailure extends BudgetViewState {
  const BudgetFailure();
}

class BudgetReady extends BudgetViewState {
  const BudgetReady({
    required this.profile,
    required this.gameState,
    required this.period,
    required this.definition,
    required this.draft,
    required this.persistedDraft,
    this.saving = false,
    this.saveFailed = false,
    this.confirming = false,
    this.confirmFailed = false,
  });

  final Profile profile;
  final GameState gameState;
  final GamePeriod period;
  final PeriodDefinition definition;
  final BudgetAllocation draft;
  final BudgetAllocation persistedDraft;
  final bool saving;
  final bool saveFailed;
  final bool confirming;
  final bool confirmFailed;

  bool get editable => period.status == GamePeriodStatus.planning;
  int get remainder => draft.remainderFor(period.startingBudget);
  bool get draftIsPersisted => sameAllocation(draft, persistedDraft);
  bool get canConfirm =>
      editable &&
      !saving &&
      !saveFailed &&
      !confirming &&
      draftIsPersisted &&
      !draft.hasNegativeValue &&
      draft.meetsMinimumAllocation &&
      remainder >= 0;

  BudgetReady copyWith({
    GameState? gameState,
    GamePeriod? period,
    BudgetAllocation? draft,
    BudgetAllocation? persistedDraft,
    bool? saving,
    bool? saveFailed,
    bool? confirming,
    bool? confirmFailed,
  }) => BudgetReady(
    profile: profile,
    gameState: gameState ?? this.gameState,
    period: period ?? this.period,
    definition: definition,
    draft: draft ?? this.draft,
    persistedDraft: persistedDraft ?? this.persistedDraft,
    saving: saving ?? this.saving,
    saveFailed: saveFailed ?? this.saveFailed,
    confirming: confirming ?? this.confirming,
    confirmFailed: confirmFailed ?? this.confirmFailed,
  );
}

bool sameAllocation(BudgetAllocation first, BudgetAllocation second) =>
    first.need == second.need &&
    first.want == second.want &&
    first.savings == second.savings;

final budgetControllerProvider =
    NotifierProvider<BudgetController, BudgetViewState>(BudgetController.new);

class BudgetController extends Notifier<BudgetViewState> {
  Future<void> _saveTail = Future.value();
  int _pendingSaves = 0;
  int _session = 0;

  @override
  BudgetViewState build() => const BudgetLoading();

  Future<void> load() async {
    await waitForPendingSaves();
    final session = ++_session;
    _pendingSaves = 0;
    state = const BudgetLoading();
    final loaded = await _readSnapshot();
    if (session == _session) state = loaded;
  }

  int maximumFor(BudgetReady current, BudgetCategory category) =>
      switch (category) {
        BudgetCategory.need =>
          current.period.startingBudget -
              current.draft.want -
              current.draft.savings,
        BudgetCategory.want =>
          current.period.startingBudget -
              current.draft.need -
              current.draft.savings,
        BudgetCategory.savings =>
          current.period.startingBudget -
              current.draft.need -
              current.draft.want,
      };

  void previewValue(BudgetCategory category, int value) {
    final current = state;
    if (current is! BudgetReady || !current.editable) return;
    final allocation = _withValue(current.draft, category, value);
    if (!_isValid(allocation, current.period.startingBudget)) return;
    state = current.copyWith(draft: allocation, confirmFailed: false);
  }

  Future<void> setValue(BudgetCategory category, int value) {
    previewValue(category, value);
    return savePreview();
  }

  Future<void> savePreview() {
    final current = state;
    if (current is! BudgetReady ||
        !current.editable ||
        !_isValid(current.draft, current.period.startingBudget)) {
      return Future.value();
    }
    if (current.draftIsPersisted && !current.saveFailed) {
      return Future.value();
    }
    return _enqueueSave(current.draft);
  }

  Future<void> retrySave() => savePreview();

  Future<void> waitForPendingSaves() async {
    while (_pendingSaves > 0) {
      final pending = _saveTail;
      await pending;
      if (identical(pending, _saveTail) && _pendingSaves == 0) return;
    }
  }

  Future<BudgetAllocation?> prepareConfirmation() async {
    await waitForPendingSaves();
    final current = state;
    if (current is! BudgetReady || !current.canConfirm) return null;
    try {
      final persisted = await ref
          .read(gameRepositoryProvider)
          .getPeriodById(current.profile.id!, current.period.id!);
      if (persisted == null) {
        state = const BudgetFailure();
        return null;
      }
      final allocation = _allocationFrom(persisted);
      if (persisted.status != GamePeriodStatus.planning ||
          !sameAllocation(allocation, current.draft)) {
        if (persisted.status == GamePeriodStatus.active ||
            persisted.status == GamePeriodStatus.readyToFinish) {
          state = current.copyWith(
            period: persisted,
            draft: allocation,
            persistedDraft: allocation,
          );
        } else {
          state = current.copyWith(
            persistedDraft: allocation,
            saveFailed: true,
          );
        }
        return null;
      }
      state = current.copyWith(period: persisted, persistedDraft: allocation);
      return allocation;
    } catch (_) {
      state = current.copyWith(saveFailed: true);
      return null;
    }
  }

  Future<bool> confirmPlan() async {
    final allocation = await prepareConfirmation();
    final current = state;
    if (allocation == null || current is! BudgetReady || !current.canConfirm) {
      return false;
    }
    state = current.copyWith(confirming: true, confirmFailed: false);
    GamePeriod? confirmed;
    try {
      confirmed = await ref
          .read(budgetServiceProvider)
          .confirmPlan(
            profileId: current.profile.id!,
            periodId: current.period.id!,
          );
    } catch (_) {
      try {
        final persisted = await ref
            .read(gameRepositoryProvider)
            .getPeriodById(current.profile.id!, current.period.id!);
        if (persisted != null &&
            (persisted.status == GamePeriodStatus.active ||
                persisted.status == GamePeriodStatus.readyToFinish) &&
            sameAllocation(_allocationFrom(persisted), allocation)) {
          confirmed = persisted;
        }
      } catch (_) {
        // The friendly mutation error below remains authoritative for the UI.
      }
    }
    final latest = state;
    if (latest is! BudgetReady) return false;
    if (confirmed == null) {
      state = latest.copyWith(confirming: false, confirmFailed: true);
      return false;
    }
    final persistedAllocation = _allocationFrom(confirmed);
    state = latest.copyWith(
      period: confirmed,
      draft: persistedAllocation,
      persistedDraft: persistedAllocation,
      confirming: false,
      confirmFailed: false,
    );
    return true;
  }

  Future<void> _enqueueSave(BudgetAllocation allocation) {
    final current = state;
    if (current is! BudgetReady) return Future.value();
    final session = _session;
    final profileId = current.profile.id!;
    final periodId = current.period.id!;
    _pendingSaves++;
    state = current.copyWith(
      saving: true,
      saveFailed: false,
      confirmFailed: false,
    );
    final operation = _saveTail.then(
      (_) => _persistDraft(
        session: session,
        profileId: profileId,
        periodId: periodId,
        allocation: allocation,
      ),
    );
    _saveTail = operation;
    return operation.whenComplete(() {
      if (session != _session) return;
      _pendingSaves--;
      final latest = state;
      if (latest is! BudgetReady) return;
      final unresolved =
          latest.saveFailed ||
          (_pendingSaves == 0 &&
              !sameAllocation(latest.draft, latest.persistedDraft));
      state = latest.copyWith(
        saving: _pendingSaves > 0,
        saveFailed: unresolved,
      );
    });
  }

  Future<void> _persistDraft({
    required int session,
    required int profileId,
    required int periodId,
    required BudgetAllocation allocation,
  }) async {
    GamePeriod? persisted;
    try {
      persisted = await ref
          .read(budgetServiceProvider)
          .saveDraft(
            profileId: profileId,
            periodId: periodId,
            allocation: allocation,
          );
    } catch (_) {
      try {
        final refreshed = await ref
            .read(gameRepositoryProvider)
            .getPeriodById(profileId, periodId);
        if (refreshed != null &&
            refreshed.status == GamePeriodStatus.planning &&
            sameAllocation(_allocationFrom(refreshed), allocation)) {
          persisted = refreshed;
        }
      } catch (_) {
        // The save is marked unresolved below.
      }
    }
    if (session != _session) return;
    final current = state;
    if (current is! BudgetReady) return;
    if (persisted == null) {
      state = current.copyWith(saveFailed: true);
      return;
    }
    state = current.copyWith(
      period: persisted,
      persistedDraft: _allocationFrom(persisted),
      saveFailed: false,
    );
  }

  Future<BudgetViewState> _readSnapshot() async {
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) return const BudgetFailure();
    try {
      final values = await Future.wait<Object?>([
        ref.read(profileRepositoryProvider).findById(profileId),
        ref.read(gameRepositoryProvider).getPet(profileId),
        ref.read(gameRepositoryProvider).getGameState(profileId),
        ref.read(gameRepositoryProvider).getPeriods(profileId),
        ref.read(contentRepositoryProvider).loadPeriods(),
      ]);
      final profile = values[0] as Profile?;
      final pet = values[1] as Pet?;
      final gameState = values[2] as GameState?;
      final periods = values[3] as List<GamePeriod>;
      final definitions = values[4] as List<PeriodDefinition>;
      if (profile == null || profile.profileType != ProfileType.normal) {
        return const BudgetFailure();
      }
      if (pet == null) return const BudgetNeedsBootstrap();
      if (gameState == null) return const BudgetFailure();
      final unfinished = periods
          .where((period) => period.status != GamePeriodStatus.completed)
          .toList(growable: false);
      if (unfinished.length != 1) return const BudgetFailure();
      final period = unfinished.single;
      if (period.status != GamePeriodStatus.planning &&
          period.status != GamePeriodStatus.active &&
          period.status != GamePeriodStatus.readyToFinish) {
        return const BudgetFailure();
      }
      final matches = definitions
          .where(
            (candidate) =>
                candidate.id == period.definitionId &&
                candidate.number == period.periodNumber,
          )
          .toList(growable: false);
      if (matches.length != 1) return const BudgetFailure();
      final allocation = _allocationFrom(period);
      if (!_isValid(allocation, period.startingBudget) ||
          allocation.remainderFor(period.startingBudget) !=
              period.plannedFree) {
        return const BudgetFailure();
      }
      return BudgetReady(
        profile: profile,
        gameState: gameState,
        period: period,
        definition: matches.single,
        draft: allocation,
        persistedDraft: allocation,
      );
    } catch (_) {
      return const BudgetFailure();
    }
  }

  BudgetAllocation _allocationFrom(GamePeriod period) => BudgetAllocation(
    need: period.plannedNeed,
    want: period.plannedWant,
    savings: period.plannedSavings,
  );

  BudgetAllocation _withValue(
    BudgetAllocation current,
    BudgetCategory category,
    int value,
  ) => switch (category) {
    BudgetCategory.need => BudgetAllocation(
      need: value,
      want: current.want,
      savings: current.savings,
    ),
    BudgetCategory.want => BudgetAllocation(
      need: current.need,
      want: value,
      savings: current.savings,
    ),
    BudgetCategory.savings => BudgetAllocation(
      need: current.need,
      want: current.want,
      savings: value,
    ),
  };

  bool _isValid(BudgetAllocation allocation, int startingBudget) =>
      !allocation.hasNegativeValue &&
      allocation.remainderFor(startingBudget) >= 0;
}
