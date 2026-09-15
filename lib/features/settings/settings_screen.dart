import 'package:finny/core/widgets/feature_placeholder_screen.dart';
import 'package:flutter/widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholderScreen(
    title: 'Настройки',
    description: 'Локальные настройки приложения будут добавлены здесь.',
    currentPath: '/settings',
  );
}
