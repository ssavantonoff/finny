import 'package:finny/core/widgets/feature_placeholder_screen.dart';
import 'package:flutter/widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholderScreen(
    title: 'Дом Финни',
    description: 'Главный игровой экран будет собран поверх сервисного слоя.',
    currentPath: '/home',
  );
}
