import 'package:finny/core/widgets/feature_placeholder_screen.dart';
import 'package:flutter/widgets.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholderScreen(
    title: 'Бюджет',
    description: 'Планирование нужного, желаемого и накоплений.',
    currentPath: '/budget',
  );
}
