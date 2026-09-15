import 'package:finny/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FinnyRouteLink {
  const FinnyRouteLink(this.path, this.label);

  final String path;
  final String label;
}

const finnyRouteLinks = <FinnyRouteLink>[
  FinnyRouteLink('/onboarding', 'Старт'),
  FinnyRouteLink('/pet-creation', 'Создание Финни'),
  FinnyRouteLink('/home', 'Дом'),
  FinnyRouteLink('/budget', 'Бюджет'),
  FinnyRouteLink('/shop', 'Магазин'),
  FinnyRouteLink('/savings', 'Накопления'),
  FinnyRouteLink('/tasks', 'Задания'),
  FinnyRouteLink('/period-summary', 'Итоги периода'),
  FinnyRouteLink('/progress', 'Прогресс'),
  FinnyRouteLink('/adult', 'Для взрослых'),
  FinnyRouteLink('/settings', 'Настройки'),
];

class FeaturePlaceholderScreen extends StatelessWidget {
  const FeaturePlaceholderScreen({
    required this.title,
    required this.description,
    required this.currentPath,
    super.key,
  });

  final String title;
  final String description;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finny')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.medium),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.large),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.large),
            Text(
              'Каркас навигации',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.medium),
            Wrap(
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.small,
              children: [
                for (final link in finnyRouteLinks)
                  if (link.path != currentPath)
                    FilledButton.tonal(
                      onPressed: () => context.go(link.path),
                      child: Text(link.label),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
