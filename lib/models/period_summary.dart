class PeriodSummary {
  const PeriodSummary({
    required this.openingWalletBalance,
    required this.baseIncome,
    required this.startingBudget,
    required this.additionalIncome,
    required this.plannedNeed,
    required this.plannedWant,
    required this.plannedSavings,
    required this.plannedRemainder,
    required this.factNeed,
    required this.factWant,
    required this.factSavings,
    required this.factRemainder,
  });

  final int openingWalletBalance;
  final int baseIncome;
  final int startingBudget;
  final int additionalIncome;
  final int plannedNeed;
  final int plannedWant;
  final int plannedSavings;
  final int plannedRemainder;
  final int factNeed;
  final int factWant;
  final int factSavings;
  final int factRemainder;

  int get totalExpenses => factNeed + factWant;
  int get endingWalletBalance => factRemainder;
  int get needDeviation => factNeed - plannedNeed;
  int get wantDeviation => factWant - plannedWant;
  int get savingsDeviation => factSavings - plannedSavings;
}
