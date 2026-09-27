import 'package:finny/features/budget/budget_visual.dart';
import 'package:finny/services/budget_service.dart';
import 'package:flutter/material.dart';
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

  testWidgets('zero starting budget renders without an overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BudgetDistributionBar(
            allocation: BudgetAllocation(need: 0, want: 0, savings: 0),
            total: 0,
            legend: true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('budget-distribution')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
