import 'package:finny/models/game_period.dart';
import 'package:finny/repositories/game_repository.dart';

class BudgetAllocation {
  const BudgetAllocation({
    required this.need,
    required this.want,
    required this.savings,
  });

  final int need;
  final int want;
  final int savings;

  int get allocated => need + want + savings;
  bool get hasNegativeValue => need < 0 || want < 0 || savings < 0;
  bool get meetsMinimumAllocation =>
      need >= GamePeriod.minimumBudgetCategoryAllocation &&
      want >= GamePeriod.minimumBudgetCategoryAllocation &&
      savings >= GamePeriod.minimumBudgetCategoryAllocation;
  int remainderFor(int startingBudget) => startingBudget - allocated;
}

class BudgetService {
  BudgetService(this._gameRepository);

  final GameRepository _gameRepository;

  Future<GamePeriod> saveDraft({
    required int profileId,
    required int periodId,
    required BudgetAllocation allocation,
  }) {
    _validateAllocation(allocation);
    return _gameRepository.saveBudget(
      profileId: profileId,
      periodId: periodId,
      plannedNeed: allocation.need,
      plannedWant: allocation.want,
      plannedSavings: allocation.savings,
    );
  }

  Future<GamePeriod> confirmPlan({
    required int profileId,
    required int periodId,
  }) => _gameRepository.confirmBudget(profileId: profileId, periodId: periodId);

  void _validateAllocation(BudgetAllocation allocation) {
    if (allocation.hasNegativeValue) {
      throw ArgumentError('Budget values cannot be negative.');
    }
  }
}
