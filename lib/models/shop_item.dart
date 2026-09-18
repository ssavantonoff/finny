enum ShopItemCategory {
  need,
  want;

  static ShopItemCategory fromJson(String value) => switch (value) {
    'NEED' => ShopItemCategory.need,
    'WANT' => ShopItemCategory.want,
    _ => throw FormatException('Unknown shop category: $value'),
  };
}

enum ItemUsagePolicy {
  none,
  unlimited,
  oncePerPeriod,
  toothbrush;

  static ItemUsagePolicy fromJson(String? value) => switch (value) {
    null || 'none' => ItemUsagePolicy.none,
    'unlimited' => ItemUsagePolicy.unlimited,
    'oncePerPeriod' => ItemUsagePolicy.oncePerPeriod,
    'toothbrush' => ItemUsagePolicy.toothbrush,
    _ => throw FormatException('Unknown item usage policy: $value'),
  };
}

class PetStatEffects {
  const PetStatEffects({this.satiety = 0, this.care = 0, this.mood = 0});

  final int satiety;
  final int care;
  final int mood;

  bool get isEmpty => satiety == 0 && care == 0 && mood == 0;

  factory PetStatEffects.fromJson(Map<String, Object?> json) => PetStatEffects(
    satiety: json['satiety'] as int? ?? 0,
    care: json['care'] as int? ?? 0,
    mood: json['mood'] as int? ?? 0,
  );

  static PetStatEffects fromLegacy(String type, int value) => switch (type) {
    'satiety' => PetStatEffects(satiety: value),
    'care' => PetStatEffects(care: value),
    'mood' => PetStatEffects(mood: value),
    'none' => const PetStatEffects(),
    _ => throw FormatException('Unknown item effect type: $type'),
  };

  @override
  bool operator ==(Object other) =>
      other is PetStatEffects &&
      satiety == other.satiety &&
      care == other.care &&
      mood == other.mood;

  @override
  int get hashCode => Object.hash(satiety, care, mood);
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
    this.usagePolicy = ItemUsagePolicy.none,
    this.effects,
  });

  final String id;
  final String name;
  final ShopItemCategory category;
  final int price;
  final bool persistent;
  final String effectType;
  final int effectValue;
  final String unlockType;
  final ItemUsagePolicy usagePolicy;
  final PetStatEffects? effects;

  PetStatEffects get petEffects =>
      effects ?? PetStatEffects.fromLegacy(effectType, effectValue);

  factory ShopItem.fromJson(Map<String, Object?> json) => ShopItem(
    id: json['id'] as String,
    name: json['name'] as String,
    category: ShopItemCategory.fromJson(json['category'] as String),
    price: json['price'] as int,
    persistent: json['persistent'] as bool,
    effectType: json['effectType'] as String,
    effectValue: json['effectValue'] as int,
    unlockType: json['unlockType'] as String,
    usagePolicy: ItemUsagePolicy.fromJson(json['usagePolicy'] as String?),
    effects: switch (json['effects']) {
      final Map value => PetStatEffects.fromJson(
        Map<String, Object?>.from(value),
      ),
      null => null,
      _ => throw const FormatException('Item effects must be an object.'),
    },
  );
}
