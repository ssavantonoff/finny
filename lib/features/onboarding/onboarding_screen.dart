import 'package:finny/core/widgets/feature_placeholder_screen.dart';
import 'package:flutter/widgets.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeaturePlaceholderScreen(
    title: 'Добро пожаловать в Finny',
    description: 'Здесь позже появится короткое знакомство с игрой.',
    currentPath: '/onboarding',
  );
}
