import 'package:finny/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.medium),
          children: [
            Text('Справка', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.small),
            Card(
              child: ListTile(
                key: const Key('settings-help'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.medium,
                  vertical: AppSpacing.small,
                ),
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Финансовые термины'),
                subtitle: const Text('Короткие объяснения слов из игры'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/help'),
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Card(
              child: ListTile(
                key: const Key('settings-adult'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.medium,
                  vertical: AppSpacing.small,
                ),
                leading: const Icon(Icons.supervisor_account_outlined),
                title: const Text('Для взрослого'),
                subtitle: const Text('Цели обучения и общий прогресс'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/adult'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
