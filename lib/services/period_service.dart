import 'package:finny/models/game_period.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/game_repository.dart';

class PeriodService {
  PeriodService(this._gameRepository);

  final GameRepository _gameRepository;

  Future<GamePeriod> startPeriod({
    required int profileId,
    required int periodNumber,
    required int baseIncome,
    int extraIncome = 0,
  }) async {
    if (periodNumber <= 0 || baseIncome < 0 || extraIncome < 0) {
      throw ArgumentError('Period and income values are invalid.');
    }
    if (await _gameRepository.getPeriod(profileId, periodNumber) != null) {
      throw StateError('Period $periodNumber already exists.');
    }
    final state = await _gameRepository.getGameState(profileId);
    if (state == null) {
      throw StateError('Game state for profile $profileId is missing.');
    }
    final period = await _gameRepository.createPeriod(
      GamePeriod(
        profileId: profileId,
        periodNumber: periodNumber,
        startWalletBalance: state.walletBalance,
        baseIncome: baseIncome,
        extraIncome: extraIncome,
        plannedNeed: 0,
        plannedWant: 0,
        plannedSavings: 0,
        plannedFree: 0,
        actualNeed: 0,
        actualWant: 0,
        actualSavings: 0,
        growthPointsEarned: 0,
        status: GamePeriodStatus.planning,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    final totalIncome = baseIncome + extraIncome;
    if (totalIncome > 0) {
      await _gameRepository.applyWalletChange(
        GameTransaction(
          profileId: profileId,
          periodId: period.id,
          type: 'income',
          amount: totalIncome,
          source: 'period_income',
          description: 'Доход периода $periodNumber',
          createdAt: DateTime.now().toUtc(),
          deduplicationKey: 'period_income_$periodNumber',
        ),
      );
    }
    await _gameRepository.setCurrentPeriod(profileId, periodNumber);
    return period;
  }

  Future<GamePeriod> completePeriod({
    required int profileId,
    required int periodNumber,
    required int growthPointsEarned,
  }) async {
    final period = await _gameRepository.getPeriod(profileId, periodNumber);
    if (period == null) {
      throw StateError('Period $periodNumber does not exist.');
    }
    if (period.status != GamePeriodStatus.readyToFinish) {
      throw StateError('Period must be ready before it can be completed.');
    }
    final state = await _gameRepository.getGameState(profileId);
    if (state == null) {
      throw StateError('Game state for profile $profileId is missing.');
    }
    final completed = period.copyWith(
      endWalletBalance: state.walletBalance,
      growthPointsEarned: growthPointsEarned,
      status: GamePeriodStatus.completed,
      completedAt: DateTime.now().toUtc(),
    );
    await _gameRepository.savePeriod(completed);
    return completed;
  }
}
