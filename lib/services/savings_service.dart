import 'package:finny/models/game_state.dart';
import 'package:finny/repositories/game_repository.dart';

class SavingsService {
  SavingsService(this._gameRepository);

  final GameRepository _gameRepository;

  Future<GameState> deposit({
    required int profileId,
    required int periodId,
    required int amount,
    required String operationId,
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be positive.');
    }
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'Must not be empty.',
      );
    }
    return _gameRepository.depositSavings(
      profileId: profileId,
      periodId: periodId,
      amount: amount,
      operationId: operationId,
    );
  }

  Future<GameState> withdraw({
    required int profileId,
    required int? periodId,
    required int amount,
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be positive.');
    }
    return _gameRepository.moveSavings(
      profileId: profileId,
      periodId: periodId,
      amount: -amount,
      source: 'savings_withdrawal',
      description: 'Возврат из накоплений',
    );
  }
}
