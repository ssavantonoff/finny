import 'package:finny/models/completed_goal.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/savings_exception.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';

class SavingsSnapshot {
  const SavingsSnapshot({
    required this.state,
    required this.goals,
    required this.completedGoals,
    required this.period,
  });

  final GameState state;
  final List<SavingsGoal> goals;
  final List<CompletedGoal> completedGoals;
  final GamePeriod? period;
}

class SavingsService {
  SavingsService(this._gameRepository, this._contentRepository);

  final GameRepository _gameRepository;
  final ContentRepository _contentRepository;

  Future<SavingsSnapshot> loadSnapshot(int profileId) async {
    final goals = await loadValidatedGoals();
    final values = await Future.wait<Object?>([
      _gameRepository.getGameState(profileId),
      _gameRepository.getCompletedGoals(profileId),
      _gameRepository.getCurrentPeriod(profileId),
    ]);
    final state = values[0] as GameState?;
    if (state == null) {
      throw StateError('Game state for profile $profileId is missing.');
    }
    final completed = values[1] as List<CompletedGoal>;
    _validateRuntimeIdentity(state, completed, goals);
    return SavingsSnapshot(
      state: state,
      goals: goals,
      completedGoals: completed,
      period: values[2] as GamePeriod?,
    );
  }

  Future<List<SavingsGoal>> loadValidatedGoals() async {
    final goals = await _contentRepository.loadGoals();
    final shopItems = await _contentRepository.loadShopItems();
    if (goals.isEmpty) {
      throw const FormatException('Savings goals must not be empty.');
    }
    final ids = <String>{};
    final rewards = <String>{};
    final shopIds = shopItems.map((item) => item.id).toSet();
    for (final goal in goals) {
      if (goal.id.trim().isEmpty ||
          goal.name.trim().isEmpty ||
          goal.price <= 0 ||
          goal.rewardAssetId.trim().isEmpty ||
          !goal.rewardAssetId.startsWith('reward_') ||
          !ids.add(goal.id) ||
          !rewards.add(goal.rewardAssetId) ||
          shopIds.contains(goal.rewardAssetId)) {
        throw const FormatException('Savings goal content is invalid.');
      }
    }
    return List.unmodifiable(goals);
  }

  Future<GameState> selectGoal({
    required int profileId,
    required String goalId,
  }) async {
    final goal = await _resolveGoal(goalId);
    return _gameRepository.selectSavingsGoal(profileId: profileId, goal: goal);
  }

  Future<GameState> changeGoal({
    required int profileId,
    required String goalId,
  }) async {
    final goals = await loadValidatedGoals();
    final state = await _requireState(profileId);
    final activeGoalId = state.activeGoalId;
    if (activeGoalId == null) throw const SavingsGoalRequiredException();
    return _gameRepository.changeSavingsGoal(
      profileId: profileId,
      currentGoal: _findGoal(goals, activeGoalId),
      newGoal: _findGoal(goals, goalId),
    );
  }

  Future<GameState> deposit({
    required int profileId,
    required int periodId,
    required int amount,
    required String operationId,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be positive.');
    }
    _validateOperationId(operationId);
    final goals = await loadValidatedGoals();
    final state = await _requireState(profileId);
    final existing = (await _gameRepository.getTransactions(profileId))
        .where(
          (transaction) =>
              transaction.deduplicationKey == 'operation:$operationId',
        )
        .firstOrNull;
    SavingsGoal goal;
    if (existing?.type == GameTransactionType.savingsDeposit &&
        existing!.source.startsWith('savings_deposit:')) {
      goal = _findGoal(
        goals,
        existing.source.substring('savings_deposit:'.length),
      );
    } else if (state.activeGoalId != null) {
      goal = _findGoal(goals, state.activeGoalId!);
    } else if (existing != null) {
      // The repository will turn a reused ID from another command into a
      // typed conflict before validating mutable savings state.
      goal = goals.first;
    } else {
      throw const SavingsGoalRequiredException();
    }
    return _gameRepository.depositSavings(
      profileId: profileId,
      periodId: periodId,
      goal: goal,
      amount: amount,
      operationId: operationId,
    );
  }

  Future<GamePeriod> skipToday({
    required int profileId,
    required int periodId,
  }) => _gameRepository.skipSavingsDecision(
    profileId: profileId,
    periodId: periodId,
  );

  Future<GamePeriod> resolveAllGoalsCompletedDecision({
    required int profileId,
    required int periodId,
  }) async {
    final goals = await loadValidatedGoals();
    return _gameRepository.resolveSavingsDecisionForCompletedGoals(
      profileId: profileId,
      periodId: periodId,
      canonicalGoalIds: goals.map((goal) => goal.id).toSet(),
    );
  }

  Future<GameState> claimGoal({
    required int profileId,
    required String goalId,
    required String operationId,
  }) async {
    _validateOperationId(operationId);
    return _gameRepository.claimSavingsGoal(
      profileId: profileId,
      goal: await _resolveGoal(goalId),
      operationId: operationId,
    );
  }

  Future<GameState> _requireState(int profileId) async {
    final state = await _gameRepository.getGameState(profileId);
    if (state == null) {
      throw StateError('Game state for profile $profileId is missing.');
    }
    return state;
  }

  Future<SavingsGoal> _resolveGoal(String goalId) async =>
      _findGoal(await loadValidatedGoals(), goalId);

  SavingsGoal _findGoal(List<SavingsGoal> goals, String goalId) {
    final matches = goals.where((goal) => goal.id == goalId);
    if (matches.length != 1) throw SavingsGoalNotFoundException(goalId);
    return matches.single;
  }

  void _validateRuntimeIdentity(
    GameState state,
    List<CompletedGoal> completed,
    List<SavingsGoal> goals,
  ) {
    if (state.activeGoalId == null && state.goalChangeUsed) {
      throw StateError('goalChangeUsed is true without an active goal.');
    }
    if (state.activeGoalId != null) _findGoal(goals, state.activeGoalId!);
    for (final item in completed) {
      final canonical = _findGoal(goals, item.goalId);
      if (item.pricePaid != canonical.price ||
          item.rewardAssetId != canonical.rewardAssetId) {
        throw StateError('Completed goal identity conflicts with content.');
      }
    }
  }

  void _validateOperationId(String operationId) {
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'Must not be empty.',
      );
    }
  }
}
