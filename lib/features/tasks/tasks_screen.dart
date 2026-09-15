import 'package:finny/core/widgets/feature_placeholder_screen.dart';
import 'package:flutter/widgets.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholderScreen(
    title: 'Финансовые задания',
    description: 'Сценарии заданий будут поступать из JSON-контента.',
    currentPath: '/tasks',
  );
}
