import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
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
      body: _unlocked
          ? _AdultBody(state: ref.watch(adultControllerProvider))
          : _AdultBarrier(onUnlock: _unlock),
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
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Раздел для взрослого',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.small),
                  const Text(
                    'Нажмите и удерживайте кнопку, чтобы продолжить.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.large),
                  Semantics(
                    button: true,
                    label: 'Удерживать',
                    hint: 'Нажмите и удерживайте, чтобы открыть раздел',
                    child: Material(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppRadii.button),
                      child: InkWell(
                        key: const Key('adult-unlock'),
                        onTap: () {},
                        onLongPress: onUnlock,
                        borderRadius: BorderRadius.circular(AppRadii.button),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 160,
                            minHeight: 48,
                          ),
                          child: const Center(
                            child: Text(
                              'Удерживать',
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
                          const Icon(Icons.check_circle_outline, size: 20),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Сбросить игровой прогресс?'),
        content: const Text(
          'Дни, монеты, накопления, покупки и задания будут удалены. '
          'Имя профиля и внешний вид Финни сохранятся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Сбросить прогресс'),
          ),
        ],
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить локальный профиль?'),
        content: const Text(
          'Будут удалены профиль, Финни и весь игровой прогресс на этом '
          'устройстве. После удаления восстановить данные нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить профиль'),
          ),
        ],
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.small),
            child,
          ],
        ),
      ),
    );
  }
}
