import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/period_summary/period_summary_controller.dart';
import 'package:finny/features/period_summary/period_summary_screen.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/period_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticSummaryController extends PeriodSummaryController {
  _StaticSummaryController(this.initial);
  final PeriodSummaryViewState initial;

  @override
  PeriodSummaryViewState build() => initial;

  @override
  Future<void> load() async {}
}

void main() {
  testWidgets('completed period summary renders neutral Plan and Fact', (
    tester,
  ) async {
    final state = PeriodSummaryReady(
      period: GamePeriod(
        id: 1,
        profileId: 1,
        definitionId: 'period_1',
        periodNumber: 1,
        startWalletBalance: 0,
        baseIncome: 500,
        extraIncome: 0,
        plannedNeed: 100,
        plannedWant: 100,
        plannedSavings: 100,
        plannedFree: 200,
        actualNeed: 80,
        actualWant: 120,
        actualSavings: 100,
        requiredCheckpoints: const [],
        resolvedCheckpoints: const [],
        endWalletBalance: 200,
        growthPointsEarned: 0,
        status: GamePeriodStatus.completed,
        createdAt: DateTime.utc(2026, 1, 1),
        completedAt: DateTime.utc(2026, 1, 2),
      ),
      summary: const PeriodSummary(
        openingWalletBalance: 0,
        baseIncome: 500,
        startingBudget: 500,
        additionalIncome: 0,
        plannedNeed: 100,
        plannedWant: 100,
        plannedSavings: 100,
        plannedRemainder: 200,
        factNeed: 80,
        factWant: 120,
        factSavings: 100,
        factRemainder: 200,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          periodSummaryControllerProvider.overrideWith(
            () => _StaticSummaryController(state),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const PeriodSummaryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('День 1 завершён'), findsOneWidget);
    expect(find.text('План'), findsOneWidget);
    expect(find.text('Факт'), findsOneWidget);
    expect(find.text('Нужное'), findsOneWidget);
    expect(find.text('Желания'), findsOneWidget);
    expect(find.text('Накопления'), findsOneWidget);
    expect(find.text('На потом'), findsOneWidget);
    expect(find.byKey(const Key('summary-home')), findsOneWidget);
  });
}
