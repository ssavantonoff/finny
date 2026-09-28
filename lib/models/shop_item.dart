enum ShopItemCategory {
  need,
  want;

  static ShopItemCategory fromJson(String value) => switch (value) {
    'NEED' => ShopItemCategory.need,
    'WANT' => ShopItemCategory.want,
    _ => throw FormatException('Unknown shop category: $value'),
  };
}

enum ShopDisplaySection {
  food,
  care,
  toys,
  accessories;

  static ShopDisplaySection fromJson(String value) => values.firstWhere(
    (section) => section.name == value,
    orElse: () => throw FormatException('Unknown shop section: $value'),
  );
}

enum ShopEquipSlot {
  head,
  neck,
  back;

  static ShopEquipSlot fromJson(String value) => values.firstWhere(
    (slot) => slot.name == value,
    orElse: () => throw FormatException('Unknown equip slot: $value'),
  );
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

  factory PetStatEffects.fromJson(Map<String, Object?> json) {
    if (json.keys.any((key) => !{'satiety', 'care', 'mood'}.contains(key))) {
      throw const FormatException('Unsupported pet effect.');
    }
    return PetStatEffects(
      satiety: json['satiety'] as int? ?? 0,
      care: json['care'] as int? ?? 0,
      mood: json['mood'] as int? ?? 0,
    );
  }

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
    this.displaySection = ShopDisplaySection.food,
    this.equipSlot,
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
  final ShopDisplaySection displaySection;
  final ShopEquipSlot? equipSlot;
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
    displaySection: ShopDisplaySection.fromJson(
      json['displaySection'] as String,
    ),
    equipSlot: switch (json['equipSlot']) {
      final String value => ShopEquipSlot.fromJson(value),
      null => null,
      _ => throw const FormatException('Invalid equip slot.'),
    },
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

void validateShopContent(List<ShopItem> items) {
  final ids = <String>{};
  for (final item in items) {
    if (item.id.trim().isEmpty || !ids.add(item.id)) {
      throw const FormatException(
        'Shop item IDs must be non-empty and unique.',
      );
    }
    if (item.name.trim().isEmpty ||
        item.price <= 0 ||
        !{'none', 'satiety', 'care', 'mood'}.contains(item.effectType) ||
        item.effectValue < 0 ||
        item.petEffects.satiety < 0 ||
        item.petEffects.care < 0 ||
        item.petEffects.mood < 0) {
      throw FormatException('Invalid shop item ${item.id}.');
    }
    if (item.unlockType != 'available') {
      throw FormatException('Unsupported unlock type for ${item.id}.');
    }
    if (item.persistent && item.usagePolicy == ItemUsagePolicy.unlimited ||
        !item.persistent && item.usagePolicy != ItemUsagePolicy.unlimited) {
      throw FormatException('Invalid usage policy for ${item.id}.');
    }
    if (item.displaySection == ShopDisplaySection.accessories) {
      if (item.equipSlot == null ||
          item.usagePolicy != ItemUsagePolicy.none ||
          !item.petEffects.isEmpty ||
          !item.persistent) {
        throw FormatException('Invalid accessory ${item.id}.');
      }
    } else if (item.equipSlot != null ||
        item.petEffects.isEmpty ||
        item.usagePolicy == ItemUsagePolicy.none) {
      throw FormatException('Invalid usable item ${item.id}.');
    }
  }
}
