import 'package:finny/app/providers.dart';
import 'package:finny/models/completed_goal.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/savings_exception.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/services/savings_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class SavingsViewState {
  const SavingsViewState();
}

class SavingsLoading extends SavingsViewState {
  const SavingsLoading();
}

class SavingsNoProfile extends SavingsViewState {
  const SavingsNoProfile();
}

class SavingsContentFailure extends SavingsViewState {
  const SavingsContentFailure();
}

class SavingsRuntimeFailure extends SavingsViewState {
  const SavingsRuntimeFailure();
}

sealed class PendingSavingsOperation {
  const PendingSavingsOperation();
}

class PendingSavingsDeposit extends PendingSavingsOperation {
  const PendingSavingsDeposit({
    required this.profileId,
    required this.periodId,
    required this.goalId,
    required this.amount,
    required this.operationId,
  });

  final int profileId;
  final int periodId;
  final String goalId;
  final int amount;
  final String operationId;
}

class PendingSavingsClaim extends PendingSavingsOperation {
  const PendingSavingsClaim({
    required this.profileId,
    required this.goalId,
    required this.operationId,
  });

  final int profileId;
  final String goalId;
  final String operationId;
}

class SavingsReady extends SavingsViewState {
  const SavingsReady({
    required this.profileId,
    required this.gameState,
    required this.goals,
    required this.completedGoals,
    required this.period,
    this.mutating = false,
    this.pendingOperation,
    this.message,
  });

  final int profileId;
  final GameState gameState;
  final List<SavingsGoal> goals;
  final List<CompletedGoal> completedGoals;
  final GamePeriod? period;
  final bool mutating;
  final PendingSavingsOperation? pendingOperation;
  final String? message;

  Set<String> get completedGoalIds =>
      completedGoals.map((goal) => goal.goalId).toSet();
  SavingsGoal? get activeGoal {
    final id = gameState.activeGoalId;
    if (id == null) return null;
    return goals.singleWhere((goal) => goal.id == id);
  }

  List<SavingsGoal> get availableGoals => goals
      .where((goal) => !completedGoalIds.contains(goal.id))
      .toList(growable: false);
  bool get allGoalsCompleted =>
      goals.isNotEmpty && completedGoalIds.containsAll(goals.map((g) => g.id));
  bool get goalReached =>
      activeGoal != null && gameState.savedAmount >= activeGoal!.price;
  int get missingAmount => activeGoal == null
      ? 0
      : (activeGoal!.price - gameState.savedAmount).clamp(0, activeGoal!.price);
  int get maxDeposit => gameState.walletBalance < missingAmount
      ? gameState.walletBalance
      : missingAmount;
  bool get savingsDecisionResolved =>
      period?.resolvedCheckpoints.contains('savings_decision') ?? false;
  bool get canDeposit =>
      pendingOperation == null &&
      !mutating &&
      activeGoal != null &&
      !goalReached &&
      maxDeposit > 0 &&
      (period?.status == GamePeriodStatus.active ||
          period?.status == GamePeriodStatus.readyToFinish);
  bool get canSkip =>
      pendingOperation == null &&
      !mutating &&
      activeGoal != null &&
      period?.status == GamePeriodStatus.active &&
      period!.actualSavings == 0 &&
      !savingsDecisionResolved;
  bool get canChange =>
      pendingOperation == null &&
      !mutating &&
      activeGoal != null &&
      !goalReached &&
      !gameState.goalChangeUsed &&
      availableGoals.any((goal) => goal.id != activeGoal!.id);
  bool get canClaim =>
      pendingOperation == null &&
      !mutating &&
      activeGoal != null &&
      goalReached;
  bool get canResolveAllGoals =>
      pendingOperation == null &&
      !mutating &&
      allGoalsCompleted &&
      activeGoal == null &&
      period?.status == GamePeriodStatus.active &&
      !savingsDecisionResolved;

  SavingsReady copyWith({
    GameState? gameState,
    List<SavingsGoal>? goals,
    List<CompletedGoal>? completedGoals,
    GamePeriod? period,
    bool clearPeriod = false,
    bool? mutating,
    PendingSavingsOperation? pendingOperation,
    bool clearPending = false,
    String? message,
    bool clearMessage = false,
  }) => SavingsReady(
    profileId: profileId,
    gameState: gameState ?? this.gameState,
    goals: goals ?? this.goals,
    completedGoals: completedGoals ?? this.completedGoals,
    period: clearPeriod ? null : period ?? this.period,
    mutating: mutating ?? this.mutating,
    pendingOperation: clearPending
        ? null
        : pendingOperation ?? this.pendingOperation,
    message: clearMessage ? null : message ?? this.message,
  );
}

final savingsControllerProvider =
    NotifierProvider<SavingsController, SavingsViewState>(
      SavingsController.new,
    );

class SavingsController extends Notifier<SavingsViewState> {
  int _generation = 0;
  int _operationCounter = 0;

  @override
  SavingsViewState build() => const SavingsLoading();

  Future<void> load() async {
    final generation = ++_generation;
    final profileId = ref.read(activeProfileIdProvider);
    if (profileId == null) {
      state = const SavingsNoProfile();
      return;
    }
    state = const SavingsLoading();
    try {
      final snapshot = await ref
          .read(savingsServiceProvider)
          .loadSnapshot(profileId);
      if (_isCurrent(generation, profileId)) {
        state = _ready(profileId, snapshot);
      }
    } on FormatException {
      if (_isCurrent(generation, profileId)) {
        state = const SavingsContentFailure();
      }
    } catch (_) {
      if (_isCurrent(generation, profileId)) {
        state = const SavingsRuntimeFailure();
      }
    }
  }

  Future<void> selectGoal(String goalId) => _simpleMutation(
    (service, ready) =>
        service.selectGoal(profileId: ready.profileId, goalId: goalId),
  );

  Future<void> changeGoal(String goalId) => _simpleMutation(
    (service, ready) =>
        service.changeGoal(profileId: ready.profileId, goalId: goalId),
  );

  Future<void> skipToday() => _simpleMutation((service, ready) {
    final period = ready.period;
    if (period?.id == null) throw const SavingsPeriodNotAvailableException();
    return service.skipToday(profileId: ready.profileId, periodId: period!.id!);
  });

  Future<void> resolveAllGoalsCompletedDecision() => _simpleMutation((
    service,
    ready,
  ) {
    final period = ready.period;
    if (period?.id == null) throw const SavingsPeriodNotAvailableException();
    return service.resolveAllGoalsCompletedDecision(
      profileId: ready.profileId,
      periodId: period!.id!,
    );
  });

  Future<void> deposit(int amount) async {
    final current = state;
    if (current is! SavingsReady ||
        current.mutating ||
        current.pendingOperation != null ||
        current.period?.id == null ||
        current.activeGoal == null) {
      return;
    }
    final pending = PendingSavingsDeposit(
      profileId: current.profileId,
      periodId: current.period!.id!,
      goalId: current.activeGoal!.id,
      amount: amount,
      operationId: _operationId(
        'deposit',
        current.profileId,
        '${current.period!.id}',
      ),
    );
    await _runPending(current, pending);
  }

  Future<void> claimGoal() async {
    final current = state;
    if (current is! SavingsReady ||
        current.mutating ||
        current.pendingOperation != null ||
        current.activeGoal == null) {
      return;
    }
    final pending = PendingSavingsClaim(
      profileId: current.profileId,
      goalId: current.activeGoal!.id,
      operationId: _operationId(
        'claim',
        current.profileId,
        current.activeGoal!.id,
      ),
    );
    await _runPending(current, pending);
  }

  Future<void> retryPendingOperation() async {
    final current = state;
    if (current is! SavingsReady ||
        current.mutating ||
        current.pendingOperation == null) {
      return;
    }
    await _runPending(current, current.pendingOperation!);
  }

  Future<void> _runPending(
    SavingsReady current,
    PendingSavingsOperation pending,
  ) async {
    final generation = _generation;
    state = current.copyWith(
      mutating: true,
      pendingOperation: pending,
      clearMessage: true,
    );
    try {
      final service = ref.read(savingsServiceProvider);
      switch (pending) {
        case PendingSavingsDeposit():
          await service.deposit(
            profileId: pending.profileId,
            periodId: pending.periodId,
            amount: pending.amount,
            operationId: pending.operationId,
          );
        case PendingSavingsClaim():
          await service.claimGoal(
            profileId: pending.profileId,
            goalId: pending.goalId,
            operationId: pending.operationId,
          );
      }
      await _refreshAfterMutation(
        current,
        generation,
        pending,
        clearPending: true,
      );
    } on SavingsException catch (error) {
      if (_isCurrent(generation, current.profileId)) {
        state = current.copyWith(
          mutating: false,
          clearPending: true,
          message: _friendlyMessage(error),
        );
      }
    } catch (_) {
      if (_isCurrent(generation, current.profileId)) {
        state = current.copyWith(
          mutating: false,
          pendingOperation: pending,
          message: 'Не удалось подтвердить операцию. Повтори попытку.',
        );
      }
    }
  }

  Future<void> _simpleMutation(
    Future<Object?> Function(SavingsService service, SavingsReady ready) action,
  ) async {
    final current = state;
    if (current is! SavingsReady ||
        current.mutating ||
        current.pendingOperation != null) {
      return;
    }
    final generation = _generation;
    state = current.copyWith(mutating: true, clearMessage: true);
    try {
      await action(ref.read(savingsServiceProvider), current);
      await _refreshAfterMutation(
        current,
        generation,
        null,
        clearPending: true,
      );
    } on SavingsException catch (error) {
      if (_isCurrent(generation, current.profileId)) {
        state = current.copyWith(
          mutating: false,
          clearPending: true,
          message: _friendlyMessage(error),
        );
      }
    } catch (_) {
      if (_isCurrent(generation, current.profileId)) {
        state = current.copyWith(
          mutating: false,
          message: 'Не получилось выполнить действие. Попробуй ещё раз.',
        );
      }
    }
  }

  Future<void> _refreshAfterMutation(
    SavingsReady previous,
    int generation,
    PendingSavingsOperation? pending, {
    required bool clearPending,
  }) async {
    try {
      final snapshot = await ref
          .read(savingsServiceProvider)
          .loadSnapshot(previous.profileId);
      if (_isCurrent(generation, previous.profileId)) {
        state = _ready(previous.profileId, snapshot);
      }
    } catch (_) {
      if (_isCurrent(generation, previous.profileId)) {
        state = previous.copyWith(
          mutating: false,
          pendingOperation: pending,
          clearPending: clearPending && pending == null,
          message: 'Данные изменились, но не удалось обновить экран.',
        );
      }
    }
  }

  SavingsReady _ready(int profileId, SavingsSnapshot snapshot) => SavingsReady(
    profileId: profileId,
    gameState: snapshot.state,
    goals: snapshot.goals,
    completedGoals: snapshot.completedGoals,
    period: snapshot.period,
  );

  bool _isCurrent(int generation, int profileId) =>
      generation == _generation &&
      ref.read(activeProfileIdProvider) == profileId;

  String _operationId(String kind, int profileId, String identity) {
    _operationCounter++;
    return 'savings:$kind:$profileId:$identity:'
        '${DateTime.now().microsecondsSinceEpoch}:$_operationCounter';
  }

  String _friendlyMessage(SavingsException error) => switch (error) {
    SavingsInsufficientWalletFundsException() =>
      'В кошельке недостаточно монет.',
    SavingsDepositExceedsGoalException() =>
      'До цели осталось меньше выбранной суммы.',
    SavingsGoalNotReachedException() =>
      'Для получения цели пока не хватает монет.',
    SavingsGoalChangeAlreadyUsedException() =>
      'В этом цикле цель уже менялась.',
    SavingsGoalAlreadyCompletedException() => 'Эта цель уже получена.',
    _ => 'Сейчас это действие недоступно.',
  };
}
