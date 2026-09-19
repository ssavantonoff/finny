import 'package:finny/models/content_entry.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/period_summary.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';

class PeriodService {
  PeriodService(this._gameRepository, this._contentRepository);

  final GameRepository _gameRepository;
  final ContentRepository _contentRepository;

  Future<GamePeriod?> startNextPeriod({required int profileId}) async {
    final definitions = await _loadValidDefinitions();
    if (definitions.isEmpty) return null;

    final unfinished = await _gameRepository.getCurrentPeriod(profileId);
    if (unfinished != null) {
      throw StateError('Complete the current period before starting another.');
    }

    final history = await _gameRepository.getPeriods(profileId);
    PeriodDefinition? next;
    if (history.isEmpty) {
      next = definitions.first;
    } else {
      final latest = history.last;
      final latestIndex = definitions.indexWhere(
        (definition) =>
            definition.id == latest.definitionId ||
            definition.number == latest.periodNumber,
      );
      if (latestIndex < 0) {
        throw StateError(
          'The latest period does not match the current content sequence.',
        );
      }
      if (latestIndex == definitions.length - 1) return null;
      next = definitions[latestIndex + 1];
    }

    return _gameRepository.startPeriod(
      profileId: profileId,
      definitionId: next.id,
      periodNumber: next.number,
      baseIncome: next.baseIncome,
      requiredCheckpoints: next.requiredCheckpoints,
      createdAt: DateTime.now().toUtc(),
    );
  }

  Future<GamePeriod> resolveCheckpoint({
    required int profileId,
    required int periodId,
    required String checkpointId,
  }) {
    if (checkpointId.trim().isEmpty) {
      throw ArgumentError.value(
        checkpointId,
        'checkpointId',
        'Must not be empty.',
      );
    }
    return _gameRepository.resolveCheckpoint(
      profileId: profileId,
      periodId: periodId,
      checkpointId: checkpointId,
    );
  }

  Future<GameState> addExplicitIncome({
    required int profileId,
    required int periodId,
    required int amount,
    required String operationId,
    required String source,
    required String description,
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be positive.');
    }
    if (operationId.trim().isEmpty ||
        source.trim().isEmpty ||
        description.trim().isEmpty) {
      throw ArgumentError(
        'operationId, source, and description must not be empty.',
      );
    }
    return _gameRepository.applyIdempotentWalletChange(
      GameTransaction(
        profileId: profileId,
        periodId: periodId,
        type: GameTransactionType.otherIncome,
        amount: amount,
        source: source,
        description: description,
        createdAt: DateTime.now().toUtc(),
        deduplicationKey: 'operation:$operationId',
      ),
    );
  }

  Future<PeriodSummary> getSummary({
    required int profileId,
    required int periodId,
  }) async {
    final period = await _gameRepository.getPeriodById(profileId, periodId);
    if (period == null) {
      throw StateError(
        'Period $periodId does not exist for profile $profileId.',
      );
    }
    final transactions = await _gameRepository.getTransactions(
      profileId,
      periodId: periodId,
    );
    final state = await _gameRepository.getGameState(profileId);
    if (state == null) {
      throw StateError('Game state for profile $profileId is missing.');
    }

    var additionalIncome = 0;
    var factNeed = 0;
    var factWant = 0;
    var factSavings = 0;
    for (final transaction in transactions) {
      switch (transaction.type) {
        case GameTransactionType.periodIncome:
          break;
        case GameTransactionType.needExpense:
          factNeed += -transaction.amount;
        case GameTransactionType.wantExpense:
          factWant += -transaction.amount;
        case GameTransactionType.savingsDeposit:
          factSavings += -transaction.amount;
        case GameTransactionType.savingsWithdrawal:
          break;
        default:
          if (transaction.amount > 0) {
            additionalIncome += transaction.amount;
          }
      }
    }

    final factRemainder = period.status == GamePeriodStatus.completed
        ? period.endWalletBalance!
        : state.walletBalance;
    return PeriodSummary(
      openingWalletBalance: period.startWalletBalance,
      baseIncome: period.baseIncome,
      startingBudget: period.startingBudget,
      additionalIncome: additionalIncome,
      plannedNeed: period.plannedNeed,
      plannedWant: period.plannedWant,
      plannedSavings: period.plannedSavings,
      plannedRemainder: period.plannedFree,
      factNeed: factNeed,
      factWant: factWant,
      factSavings: factSavings,
      factRemainder: factRemainder,
    );
  }

  Future<List<PeriodDefinition>> _loadValidDefinitions() async {
    final definitions = await _contentRepository.loadPeriods();
    final ids = <String>{};
    final numbers = <int>{};
    var previousNumber = 0;
    for (final definition in definitions) {
      if (definition.id.trim().isEmpty ||
          definition.number <= 0 ||
          definition.baseIncome < 0 ||
          !ids.add(definition.id) ||
          !numbers.add(definition.number) ||
          definition.number <= previousNumber) {
        throw const FormatException(
          'Period definitions have invalid identity or order.',
        );
      }
      final checkpoints = <String>{};
      for (final checkpoint in definition.requiredCheckpoints) {
        if (checkpoint.trim().isEmpty || !checkpoints.add(checkpoint)) {
          throw FormatException(
            'Period ${definition.id} has invalid required checkpoints.',
          );
        }
      }
      previousNumber = definition.number;
    }
    return definitions;
  }
}
