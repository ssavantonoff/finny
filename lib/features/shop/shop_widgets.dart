import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShopItemIcon extends StatelessWidget {
  const ShopItemIcon({super.key, required this.item});
  final ShopItem item;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 28,
    child: Icon(
      item.category == ShopItemCategory.need
          ? Icons.shopping_basket_outlined
          : Icons.redeem_outlined,
      size: 30,
    ),
  );
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
    if (!state.isPromotionActiveFor(item)) {
      return Text(
        '${item.price} монет • ${shopCategory(item)}',
        style: TextStyle(fontSize: fontSize),
      );
    }
    return Wrap(
      key: Key('shop-promo-price-${item.id}'),
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Акция'),
        Text(
          '${item.price}',
          style: TextStyle(
            fontSize: fontSize,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        Text(
          '${state.effectivePriceFor(item)} монет',
          style: TextStyle(fontSize: fontSize),
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
