import 'package:finny/core/widgets/feature_placeholder_screen.dart';
import 'package:flutter/widgets.dart';

class PeriodSummaryScreen extends StatelessWidget {
  const PeriodSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholderScreen(
    title: 'Итоги периода',
    description: 'Здесь позже появится сравнение плана и факта.',
    currentPath: '/period-summary',
  );
}
