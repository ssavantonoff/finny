import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_flow_visuals.dart';
import 'package:finny/features/onboarding/finny_concepts.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        key: const Key('how-to-play-back'),
        tooltip: 'Назад',
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/settings'),
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text('Как играть'),
    ),
    body: FinnyFlowBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              key: const Key('how-to-play-list'),
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: [
                const Text(
                  'Три простых решения помогают заботиться о Финни и распоряжаться монетами.',
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                for (var index = 0; index < finnyConcepts.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.compact),
                  FinnyConceptCard(
                    concept: finnyConcepts[index],
                    showExample: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
