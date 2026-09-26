import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/features/shop/shop_item_art.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_art.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_models.dart';
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
    final discounted = state.isDiscountActiveFor(item);
    return Semantics(
      label: discounted
          ? 'Было ${item.price} монет, сейчас ${state.effectivePriceFor(item)} монет'
          : 'Цена ${state.effectivePriceFor(item)} монет',
      child: ExcludeSemantics(
        child: Container(
          key: discounted ? Key('shop-promo-price-${item.id}') : null,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF2EFFF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (discounted) ...[
                Text(
                  '${item.price}',
                  style: TextStyle(
                    color: const Color(0xFF9392B3),
                    fontSize: fontSize - 2,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              const FinnyCatchArt(type: FinnyCatchObjectType.coin, size: 22),
              const SizedBox(width: 4),
              Text(
                '${state.effectivePriceFor(item)}',
                style: TextStyle(
                  color: discounted
                      ? const Color(0xFFEE3191)
                      : const Color(0xFF1A2368),
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Copy belongs to the Shop presentation only; canonical effects remain in content.
String shopItemDescription(ShopItem item) => switch (item.id) {
  'food_apple' => 'Лёгкий перекус для Финни',
  'food_feed' => 'Поможет Финни хорошо подкрепиться',
  'food_treat' => 'Вкусное угощение для хорошего настроения',
  'care_toothbrush' => 'Для заботы о зубах Финни',
  'care_shampoo' => 'Поможет Финни оставаться чистым',
  'care_comb' => 'Поможет Финни привести себя в порядок',
  'toy_ball' => 'Весёлая игра с мячом для Финни',
  'toy_frisbee' => 'Для активной игры с Финни',
  'toy_plush' => 'Машинка для весёлой игры',
  'accessory_bow' => 'Стильные наушники для Финни',
  'accessory_collar' => 'Очки для нового образа Финни',
  'accessory_hat' => 'Крылья для особенного образа Финни',
  _ => 'Предмет для Финни',
};

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
