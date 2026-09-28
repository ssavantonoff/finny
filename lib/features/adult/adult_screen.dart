import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_flow_visuals.dart';
import 'package:finny/core/visual/finny_modal_actions.dart';
import 'package:finny/features/adult/adult_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AdultScreen extends ConsumerStatefulWidget {
  const AdultScreen({super.key});

  @override
  ConsumerState<AdultScreen> createState() => _AdultScreenState();
}

class _AdultScreenState extends ConsumerState<AdultScreen> {
  bool _unlocked = false;

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings');
    }
  }

  void _unlock() {
    if (_unlocked) return;
    setState(() => _unlocked = true);
    unawaited(ref.read(adultControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('adult-back'),
          tooltip: 'Назад',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Для взрослого'),
      ),
      body: FinnyFlowBackdrop(
        child: _unlocked
            ? _AdultBody(state: ref.watch(adultControllerProvider))
            : _AdultBarrier(onUnlock: _unlock),
      ),
    );
  }
}

class _AdultBarrier extends StatelessWidget {
  const _AdultBarrier({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Card(
            key: const Key('adult-barrier'),
            color: Colors.white.withValues(alpha: 0.94),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(
                      Icons.shield_rounded,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    'Раздел для взрослого',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  const Text(
                    'Здесь можно посмотреть прогресс и управлять данными. Нажмите и удерживайте кнопку, чтобы продолжить.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.large),
                  Semantics(
                    button: true,
                    label: 'Удерживать',
                    hint: 'Нажмите и удерживайте, чтобы открыть раздел',
                    child: Material(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadii.button),
                      child: InkWell(
                        key: const Key('adult-unlock'),
                        onTap: () {},
                        onLongPress: onUnlock,
                        borderRadius: BorderRadius.circular(AppRadii.button),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 200,
                            minHeight: 56,
                          ),
                          child: const Center(
                            child: Text(
                              'Удерживать для входа',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdultBody extends ConsumerWidget {
  const _AdultBody({required this.state});

  final AdultViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: switch (state) {
        AdultLoading() => const Center(child: CircularProgressIndicator()),
        AdultNoProfile() => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.large),
            child: Text('Профиль пока не выбран.'),
          ),
        ),
        AdultFailure() => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Не получилось загрузить прогресс.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.medium),
                FilledButton(
                  key: const Key('adult-retry'),
                  onPressed: () => unawaited(
                    ref.read(adultControllerProvider.notifier).load(),
                  ),
                  child: const Text('Попробовать снова'),
                ),
              ],
            ),
          ),
        ),
        AdultReady(:final overview) => _AdultOverviewContent(
          overview: overview,
          dataManagementState: ref.watch(adultDataManagementControllerProvider),
        ),
      },
    );
  }
}

class _AdultOverviewContent extends ConsumerWidget {
  const _AdultOverviewContent({
    required this.overview,
    required this.dataManagementState,
  });

  static const learningTopics = [
    'отличать нужное от желаемого',
    'планировать ограниченный бюджет',
    'выбирать приоритеты',
    'откладывать на цель',
    'менять план при неожиданной трате',
    'оценивать скидку без импульсивной покупки',
  ];

  final AdultOverview overview;
  final AdultDataManagementState dataManagementState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = (overview.completedDays / adultCampaignDays)
        .clamp(0.0, 1.0)
        .toDouble();
    final operationRunning = dataManagementState is AdultDataManagementRunning;
    String? failureMessage;
    final failureState = dataManagementState;
    if (failureState is AdultDataManagementFailure) {
      failureMessage = switch (failureState.operation) {
        AdultDataManagementOperation.reset =>
          'Не получилось сбросить прогресс. Попробуйте ещё раз.',
        AdultDataManagementOperation.delete =>
          'Не получилось удалить профиль. Попробуйте ещё раз.',
      };
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.medium),
          children: [
            const _SectionCard(
              title: 'О проекте',
              child: Text(
                'Finny помогает ребёнку тренировать базовые финансовые '
                'навыки через игровые решения: планирование, обязательные и '
                'необязательные траты, накопления и последствия выбора.',
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            _SectionCard(
              title: 'Чему учится ребёнок',
              child: Column(
                children: [
                  for (final topic in learningTopics)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.small),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.small),
                          Expanded(child: Text(topic)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            _SectionCard(
              title: 'Общий прогресс',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Пройдено дней: ${overview.completedDays} из '
                    '$adultCampaignDays',
                  ),
                  const SizedBox(height: AppSpacing.small),
                  LinearProgressIndicator(
                    key: const Key('adult-campaign-progress'),
                    value: progress,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.primary,
                    backgroundColor: AppColors.primaryLight,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            _SectionCard(
              title: 'Финни',
              child: Text(
                key: const Key('adult-development'),
                overview.developmentStage == null
                    ? 'Финни ещё не создан.'
                    : 'Этап развития Финни: '
                          '${overview.developmentStage} из 3',
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            _SectionCard(
              title: 'Накопления',
              child: Text(
                key: const Key('adult-savings'),
                'В копилке: ${overview.savedAmount} монет',
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            _SectionCard(
              key: const Key('adult-data-management'),
              title: 'Управление данными',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    key: const Key('adult-reset-progress'),
                    onPressed: operationRunning
                        ? null
                        : () => unawaited(_confirmReset(context, ref)),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Сбросить игровой прогресс'),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  OutlinedButton.icon(
                    key: const Key('adult-delete-profile'),
                    onPressed: operationRunning
                        ? null
                        : () => unawaited(_confirmDelete(context, ref)),
                    icon: const Icon(Icons.delete_outline),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    label: const Text('Удалить локальный профиль'),
                  ),
                  if (failureMessage != null) ...[
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      failureMessage,
                      key: Key('adult-data-management-error'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _AdultConfirmDialog(
        icon: Icons.restart_alt_rounded,
        title: 'Сбросить игровой прогресс?',
        body:
            'Дни, монеты, накопления, покупки и задания будут удалены. '
            'Имя профиля и внешний вид Финни сохранятся.',
        confirmLabel: 'Сбросить прогресс',
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final succeeded = await ref
        .read(adultDataManagementControllerProvider.notifier)
        .resetProgress();
    if (!succeeded || !context.mounted) return;
    ref.read(activeProfileIdProvider.notifier).clear();
    context.go('/startup');
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _AdultConfirmDialog(
        icon: Icons.delete_forever_rounded,
        title: 'Удалить локальный профиль?',
        body:
            'Будут удалены профиль, Финни и весь игровой прогресс на этом '
            'устройстве. После удаления восстановить данные нельзя.',
        confirmLabel: 'Удалить профиль',
        destructive: true,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final succeeded = await ref
        .read(adultDataManagementControllerProvider.notifier)
        .deleteProfile();
    if (!succeeded || !context.mounted) return;
    ref.read(activeProfileIdProvider.notifier).clear();
    context.go('/startup');
  }
}

class _AdultConfirmDialog extends StatelessWidget {
  const _AdultConfirmDialog({
    required this.icon,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Dialog(
    key: Key(destructive ? 'adult-delete-dialog' : 'adult-reset-dialog'),
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: destructive
                  ? const Color(0xFFFFE8E8)
                  : AppColors.primaryLight,
              child: Icon(
                icon,
                size: 30,
                color: destructive ? Colors.red.shade700 : AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: destructive
                    ? FinnyModalActions.primary.copyWith(
                        backgroundColor: WidgetStatePropertyAll(
                          Colors.red.shade700,
                        ),
                      )
                    : FinnyModalActions.primary,
                onPressed: onConfirm,
                child: Text(confirmLabel),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                style: FinnyModalActions.secondary,
                onPressed: onCancel,
                child: const Text('Отмена'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final icon = switch (title) {
      'О проекте' => Icons.auto_stories_rounded,
      'Чему учится ребёнок' => Icons.school_rounded,
      'Общий прогресс' => Icons.timeline_rounded,
      'Финни' => Icons.pets_rounded,
      'Накопления' => Icons.savings_rounded,
      _ => Icons.admin_panel_settings_rounded,
    };
    return Card(
      color: Colors.white.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.primaryLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            child,
          ],
        ),
      ),
    );
  }
}
