import 'package:finny/features/budget/budget_visual.dart';
import 'package:finny/services/budget_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distribution uses all four shares of the starting budget', () {
    const allocation = BudgetAllocation(need: 250, want: 130, savings: 70);
    expect(budgetDistributionFractions(allocation, 570), [
      250 / 570,
      130 / 570,
      70 / 570,
      120 / 570,
    ]);
  });

  test('zero starting budget produces a neutral bar', () {
    expect(
      budgetDistributionFractions(
        const BudgetAllocation(need: 0, want: 0, savings: 0),
        0,
      ),
      [0, 0, 0, 1],
    );
  });
}
