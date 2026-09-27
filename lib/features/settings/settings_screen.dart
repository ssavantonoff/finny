import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_flow_visuals.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: FinnyFlowBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.medium),
            children: [
              const Text(
                'Узнай больше',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: AppSpacing.small),
              Card(
                color: Colors.white.withValues(alpha: 0.94),
                child: ListTile(
                  key: const Key('settings-help'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.medium,
                    vertical: AppSpacing.small,
                  ),
                  leading: const _SettingsIcon(Icons.menu_book_rounded),
                  title: const Text('Финансовые термины'),
                  subtitle: const Text('Понятные объяснения слов из игры'),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                  ),
                  onTap: () => context.push('/help'),
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              Card(
                color: Colors.white.withValues(alpha: 0.94),
                child: ListTile(
                  key: const Key('settings-adult'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.medium,
                    vertical: AppSpacing.small,
                  ),
                  leading: const _SettingsIcon(Icons.shield_rounded),
                  title: const Text('Для взрослого'),
                  subtitle: const Text(
                    'Об игре, прогрессе и настройках данных',
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                  ),
                  onTap: () => context.push('/adult'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Icon(icon, color: AppColors.primary),
  );
}
