import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/features/shop/shop_item_art.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShopItemIcon extends StatelessWidget {
  const ShopItemIcon({super.key, required this.item});
  final ShopItem item;
  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: 56, child: ShopItemArt(item: item));
}

class ShopPriceLabel extends StatelessWidget {
  const ShopPriceLabel({
    super.key,
    required this.item,
    required this.state,
    required this.fontSize,
  });

  final ShopItem item;
  final ShopState state;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!state.isDiscountActiveFor(item)) {
      return Text(
        '${item.price} монет • ${shopCategory(item)}',
        style: theme.textTheme.bodyLarge?.copyWith(fontSize: fontSize),
      );
    }
    return Wrap(
      key: Key('shop-promo-price-${item.id}'),
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Text(
              state.isDayFiveSaleDay ? 'Распродажа' : 'Акция',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Text(
          '${item.price}',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: fontSize,
            decoration: TextDecoration.lineThrough,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          '${state.effectivePriceFor(item)} монет',
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: fontSize + 2,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.tertiary,
          ),
        ),
        if (state.isDayFiveSaleDay)
          Text(
            'Скидка ${state.discountAmountFor(item)} 🪙',
            key: Key('shop-sale-discount-${item.id}'),
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: fontSize),
          ),
        Text(
          '• ${shopCategory(item)}',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: fontSize,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class ShopPurchaseNotice extends ConsumerWidget {
  const ShopPurchaseNotice({super.key, required this.state});
  final ShopState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = state.result;
    final message = state.purchasing
        ? 'Покупаем…'
        : switch (result?.kind) {
            ShopResultKind.success => 'Готово! Предмет куплен.',
            ShopResultKind.insufficientFunds =>
              'Пока не хватает монет.\nЦена: ${result!.itemPrice}\nУ тебя: ${result.availableBalance}\nНе хватает: ${result.itemPrice! - result.availableBalance!}',
            ShopResultKind.alreadyOwned => 'Этот предмет уже куплен.',
            ShopResultKind.ambiguous => 'Не получилось купить предмет.',
            ShopResultKind.contentChanged =>
              'Товар обновился. Выбери актуальный предмет снова.',
            null => '',
          };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: const TextStyle(fontSize: 16)),
            if (state.pending != null && !state.purchasing) ...[
              const SizedBox(height: AppSpacing.small),
              FilledButton.tonal(
                onPressed: ref.read(shopControllerProvider.notifier).retry,
                child: const Text('Повторить'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ShopNotice extends StatelessWidget {
  const ShopNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.medium),
    child: Text(message, style: const TextStyle(fontSize: 16)),
  );
}
