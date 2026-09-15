import 'package:finny/models/game_period.dart';
import 'package:finny/repositories/game_repository.dart';

class BudgetAllocation {
  const BudgetAllocation({
    required this.need,
    required this.want,
    required this.savings,
    required this.free,
  });

  final int need;
  final int want;
  final int savings;
  final int free;

  int get total => need + want + savings + free;
  bool get hasNegativeValue => need < 0 || want < 0 || savings < 0 || free < 0;
}

class BudgetService {
  BudgetService(this._gameRepository);

  final GameRepository _gameRepository;

  Future<GamePeriod> confirmPlan({
    required int profileId,
    required int periodNumber,
    required BudgetAllocation allocation,
  }) async {
    if (allocation.hasNegativeValue) {
      throw ArgumentError('Budget values cannot be negative.');
    }
    final period = await _gameRepository.getPeriod(profileId, periodNumber);
    if (period == null) {
      throw StateError('Period $periodNumber does not exist.');
    }
    if (period.status != GamePeriodStatus.planning) {
      throw StateError('Only a planning period can be confirmed.');
    }
    if (allocation.total != period.availableToPlan) {
      throw StateError('The plan must allocate all available money.');
    }
    final updated = period.copyWith(
      plannedNeed: allocation.need,
      plannedWant: allocation.want,
      plannedSavings: allocation.savings,
      plannedFree: allocation.free,
      status: GamePeriodStatus.active,
    );
    await _gameRepository.savePeriod(updated);
    return updated;
  }
}
