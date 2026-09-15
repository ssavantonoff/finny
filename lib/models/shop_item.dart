enum ShopItemCategory {
  need,
  want;

  static ShopItemCategory fromJson(String value) => switch (value) {
    'NEED' => ShopItemCategory.need,
    'WANT' => ShopItemCategory.want,
    _ => throw FormatException('Unknown shop category: $value'),
  };
}

class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.persistent,
    required this.effectType,
    required this.effectValue,
    required this.unlockType,
  });

  final String id;
  final String name;
  final ShopItemCategory category;
  final int price;
  final bool persistent;
  final String effectType;
  final int effectValue;
  final String unlockType;

  factory ShopItem.fromJson(Map<String, Object?> json) => ShopItem(
    id: json['id'] as String,
    name: json['name'] as String,
    category: ShopItemCategory.fromJson(json['category'] as String),
    price: json['price'] as int,
    persistent: json['persistent'] as bool,
    effectType: json['effectType'] as String,
    effectValue: json['effectValue'] as int,
    unlockType: json['unlockType'] as String,
  );
}
