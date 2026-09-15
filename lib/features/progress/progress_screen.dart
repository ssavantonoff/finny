import 'package:finny/core/widgets/feature_placeholder_screen.dart';
import 'package:flutter/widgets.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholderScreen(
    title: 'Прогресс Финни',
    description: 'Развитие питомца будет отображаться на этом экране.',
    currentPath: '/progress',
  );
}
