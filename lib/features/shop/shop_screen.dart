import 'dart:async';

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/features/shop/shop_item_details.dart';
import 'package:finny/features/shop/shop_widgets.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});
  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) unawaited(ref.read(shopControllerProvider.notifier).load());
    });
  }

  void _details(ShopItem item, ShopState state) {
    ref.read(shopControllerProvider.notifier).clearResult();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ShopItemDetails(item: item, profileId: state.profileId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shopControllerProvider);
    final controller = ref.read(shopControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Магазин'),
        leading: BackButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить магазин',
            onPressed: state.purchasing ? null : controller.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.medium),
              children: [
                if (state.gameState != null) ...[
                  Text(
                    'У тебя: ${state.gameState!.walletBalance} монет',
                    key: const Key('shop-wallet'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                ],
                if (state.result != null || state.purchasing)
                  ShopPurchaseNotice(state: state),
                if (state.load == ShopLoad.loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (state.load != ShopLoad.ready) ...[
                  ShopNotice(switch (state.load) {
                    ShopLoad.noProfile => 'Профиль пока не выбран.',
                    ShopLoad.contentError =>
                      'Не получилось открыть магазин. Попробуй ещё раз.',
                    _ => 'Не получилось обновить магазин. Попробуй ещё раз.',
                  }),
                  FilledButton.tonal(
                    onPressed: state.purchasing ? null : controller.load,
                    child: const Text('Обновить'),
                  ),
                ] else ...[
                  if (state.items.isEmpty)
                    const Text('В магазине пока нет товаров.'),
                  if (state.period == null)
                    const ShopNotice('Сначала начни игровой период.')
                  else if (state.period!.status == GamePeriodStatus.planning)
                    const ShopNotice('Сначала подтверди план.'),
                  for (final section in ShopDisplaySection.values)
                    if (state.items.any(
                      (item) => item.displaySection == section,
                    )) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.medium),
                        child: Text(switch (section) {
                          ShopDisplaySection.food => 'Еда',
                          ShopDisplaySection.care => 'Уход',
                          ShopDisplaySection.toys => 'Игрушки',
                          ShopDisplaySection.accessories => 'Аксессуары',
                        }, style: Theme.of(context).textTheme.titleLarge),
                      ),
                      for (final item in state.items.where(
                        (item) => item.displaySection == section,
                      ))
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: Key('shop-item-${item.id}'),
                            onTap:
                                item.persistent &&
                                    (state.quantities[item.id] ?? 0) > 0
                                ? null
                                : () => _details(item, state),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.medium),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      ShopItemIcon(item: item),
                                      const SizedBox(width: AppSpacing.medium),
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.small),
                                  Text(
                                    '${item.price} монет • ${shopCategory(item)}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  if (shopEffect(item) case final effect?)
                                    Text(
                                      effect,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  if (item.persistent &&
                                      (state.quantities[item.id] ?? 0) > 0)
                                    const Text(
                                      '✓ Куплено',
                                      style: TextStyle(fontSize: 16),
                                    )
                                  else if (item.unlockType != 'available')
                                    const Text('Этот предмет пока недоступен.'),
                                  const SizedBox(height: AppSpacing.small),
                                  const Text(
                                    'Посмотреть',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
