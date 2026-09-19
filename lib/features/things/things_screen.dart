import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/shop/shop_widgets.dart';
import 'package:finny/features/things/things_controller.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

String formatItemEffects(ShopItem item) {
  final effects = item.petEffects;
  final parts = <String>[
    if (effects.satiety > 0) 'Сытость +${effects.satiety}',
    if (effects.care > 0) 'Уход +${effects.care}',
    if (effects.mood > 0) 'Настроение +${effects.mood}',
  ];
  return parts.join(' • ');
}

class ThingsScreen extends ConsumerStatefulWidget {
  const ThingsScreen({super.key});

  @override
  ConsumerState<ThingsScreen> createState() => _ThingsScreenState();
}

class _ThingsScreenState extends ConsumerState<ThingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(thingsControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(thingsControllerProvider);
    final controller = ref.read(thingsControllerProvider.notifier);

    ref.listen<int?>(activeProfileIdProvider, (_, _) {
      controller.load();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Вещи'),
        actions: [
          IconButton(
            tooltip: 'Обновить инвентарь',
            onPressed: state.mutating ? null : controller.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (state.load) {
          ThingsLoad.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          ThingsLoad.noProfile => const Center(
            child: Text('Профиль пока не выбран.'),
          ),
          ThingsLoad.contentError => _ErrorBody(
            message: 'Не получилось загрузить вещи. Попробуй ещё раз.',
            onRetry: controller.load,
          ),
          ThingsLoad.runtimeError => _ErrorBody(
            message: 'Не получилось открыть инвентарь. Попробуй ещё раз.',
            onRetry: controller.load,
          ),
          ThingsLoad.ready => _ReadyBody(state: state, controller: controller),
        },
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.state, required this.controller});

  final ThingsState state;
  final ThingsController controller;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            key: const Key('things-empty'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.backpack_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(
                'У тебя пока нет вещей',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.small),
              const Text(
                'Загляни в магазин, чтобы купить что-нибудь для Финни.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.large),
              FilledButton.icon(
                key: const Key('things-go-to-shop'),
                onPressed: () => context.go('/shop'),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Заглянуть в магазин'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        if (state.result case final result?)
          if (result.kind != ItemUseResultKind.success) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      result.message ?? 'Произошла ошибка.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    if (result.kind == ItemUseResultKind.ambiguous) ...[
                      const SizedBox(height: AppSpacing.small),
                      FilledButton.tonal(
                        key: const Key('things-retry'),
                        onPressed: state.mutating ? null : controller.retry,
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
          ],
        for (final section in ShopDisplaySection.values)
          if (state.items.any((item) => item.displaySection == section)) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.small,
                bottom: AppSpacing.small,
              ),
              child: Text(
                key: Key('things-section-${section.name}'),
                switch (section) {
                  ShopDisplaySection.food => 'Еда',
                  ShopDisplaySection.care => 'Уход',
                  ShopDisplaySection.toys => 'Игрушки',
                  ShopDisplaySection.accessories => 'Аксессуары',
                },
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final item in state.items.where(
              (item) => item.displaySection == section,
            ))
              _ItemCard(item: item, state: state, controller: controller),
          ],
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.state,
    required this.controller,
  });

  final ShopItem item;
  final ThingsState state;
  final ThingsController controller;

  @override
  Widget build(BuildContext context) {
    final quantity = state.quantityOf(item.id);
    final isConsumable = !item.persistent;
    final title = isConsumable ? '${item.name} ×$quantity' : item.name;
    final effectText = formatItemEffects(item);
    final status = state.actionStatus(item);
    final canUse = state.canUse(item);

    return Card(
      key: Key('things-item-${item.id}'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShopItemIcon(item: item),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  if (effectText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      effectText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.small),
            if (item.displaySection == ShopDisplaySection.accessories)
              Text(
                'Аксессуар',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.outline,
                ),
              )
            else if (status != null && !canUse)
              Text(
                status,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.outline,
                ),
              )
            else
              FilledButton(
                key: Key('things-use-${item.id}'),
                onPressed: canUse && !state.mutating
                    ? () => controller.use(item)
                    : null,
                child: state.mutating && state.pending?.item.id == item.id
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(state.actionButtonLabel(item)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.large),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Попробовать снова'),
          ),
        ],
      ),
    ),
  );
}
