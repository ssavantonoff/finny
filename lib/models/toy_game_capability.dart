import 'package:finny/models/shop_item.dart';

/// Toy mood is earned through an integrated mini-game, never generic item use.
/// Add future games here when their reward flow becomes available in Campaign.
abstract final class ToyGameCapability {
  static bool hasCampaignMoodReward(ShopItem item) => switch (item.id) {
    'toy_ball' || 'toy_frisbee' =>
      item.displaySection == ShopDisplaySection.toys &&
          item.persistent &&
          item.usagePolicy == ItemUsagePolicy.oncePerPeriod &&
          item.petEffects.mood > 0 &&
          item.petEffects.satiety == 0 &&
          item.petEffects.care == 0,
    _ => false,
  };
}
