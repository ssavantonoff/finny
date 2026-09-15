import 'package:finny/core/widgets/feature_placeholder_screen.dart';
import 'package:flutter/widgets.dart';

class PetCreationScreen extends StatelessWidget {
  const PetCreationScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholderScreen(
    title: 'Создание Финни',
    description: 'Выбор имени и внешнего вида питомца будет добавлен здесь.',
    currentPath: '/pet-creation',
  );
}
