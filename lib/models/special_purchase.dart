import 'package:finny/models/shop_item.dart';

class StoryPurchase {
  const StoryPurchase({
    required this.id,
    required this.name,
    required this.period,
    required this.price,
    required this.category,
    required this.checkpoint,
  });

  final String id;
  final String name;
  final int period;
  final int price;
  final ShopItemCategory category;
  final String checkpoint;

  factory StoryPurchase.fromJson(Map<String, Object?> json) => StoryPurchase(
    id: json['id'] as String,
    name: json['name'] as String,
    period: json['period'] as int,
    price: json['price'] as int,
    category: ShopItemCategory.fromJson(json['financialCategory'] as String),
    checkpoint: json['checkpoint'] as String,
  );
}

class ShopPromotion {
  const ShopPromotion({
    required this.id,
    required this.period,
    required this.itemId,
    required this.promoPrice,
    required this.maxPromoQuantity,
  });

  final String id;
  final int period;
  final String itemId;
  final int promoPrice;
  final int maxPromoQuantity;

  bool isCanonicalDay4For(ShopItem item) =>
      id == 'day4_treat_discount' &&
      period == 4 &&
      itemId == 'food_treat' &&
      item.id == itemId &&
      item.price == 60 &&
      item.category == ShopItemCategory.want &&
      promoPrice == 35 &&
      maxPromoQuantity == 1;

  factory ShopPromotion.fromJson(Map<String, Object?> json) => ShopPromotion(
    id: json['id'] as String,
    period: json['period'] as int,
    itemId: json['itemId'] as String,
    promoPrice: json['promoPrice'] as int,
    maxPromoQuantity: json['maxPromoQuantity'] as int,
  );
}

void validateSpecialContent(
  List<StoryPurchase> stories,
  List<ShopPromotion> promotions,
  List<ShopItem> items,
) {
  final ids = <String>{};
  for (final story in stories) {
    if (!ids.add(story.id) ||
        story.id.trim().isEmpty ||
        story.name.trim().isEmpty ||
        story.period <= 0 ||
        story.price <= 0 ||
        story.checkpoint.trim().isEmpty) {
      throw FormatException('Invalid story purchase ${story.id}.');
    }
  }
  for (final promo in promotions) {
    final matching = items.where((item) => item.id == promo.itemId);
    if (!ids.add(promo.id) ||
        promo.id.trim().isEmpty ||
        promo.period <= 0 ||
        promo.promoPrice <= 0 ||
        promo.maxPromoQuantity != 1 ||
        matching.length != 1 ||
        promo.promoPrice >= matching.single.price) {
      throw FormatException('Invalid promotion ${promo.id}.');
    }
  }
}

class SpecialPurchaseConflictException implements Exception {
  const SpecialPurchaseConflictException(this.operationId);
  final String operationId;
}

class SpecialPurchaseAlreadyDecidedException implements Exception {
  const SpecialPurchaseAlreadyDecidedException(this.actionId);
  final String actionId;
}
