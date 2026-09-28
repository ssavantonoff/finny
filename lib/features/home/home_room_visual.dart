import 'package:finny/features/savings/savings_goal_visual.dart';
import 'package:finny/models/completed_goal.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter/painting.dart';

/// Production artwork and normalized placement, shared by Home and its summary.
abstract final class HomeRoomVisual {
  static const accessories = [
    HomeAccessoryVisual(
      itemId: 'accessory_bow',
      slot: ShopEquipSlot.head,
      asset: 'assets/images/things/headphones_wearable.png',
      behindPet: false,
      anchors: [
        Rect.fromLTWH(0.00, 0.02, 1.00, 0.44),
        Rect.fromLTWH(0.01, 0.03, 0.98, 0.42),
        Rect.fromLTWH(0.02, 0.03, 0.96, 0.40),
      ],
    ),
    HomeAccessoryVisual(
      itemId: 'accessory_collar',
      slot: ShopEquipSlot.neck,
      asset: 'assets/images/things/glasses_wearable.png',
      behindPet: false,
      anchors: [
        Rect.fromLTWH(0.25, 0.48, 0.50, 0.20),
        Rect.fromLTWH(0.24, 0.44, 0.52, 0.20),
        Rect.fromLTWH(0.23, 0.43, 0.54, 0.20),
      ],
    ),
    HomeAccessoryVisual(
      itemId: 'accessory_hat',
      slot: ShopEquipSlot.head,
      asset: 'assets/images/things/wings.png',
      behindPet: true,
      anchors: [
        Rect.fromLTWH(-0.10, 0.22, 1.20, 0.76),
        Rect.fromLTWH(-0.10, 0.33, 1.20, 0.65),
        Rect.fromLTWH(-0.10, 0.37, 1.20, 0.60),
      ],
    ),
  ];

  static const rewards = [
    HomeRewardVisual(
      goalId: 'goal_night_light',
      rewardAssetId: 'reward_night_light',
      placement: Rect.fromLTWH(0.12, -0.22, 0.20, 0.36),
    ),
    HomeRewardVisual(
      goalId: 'goal_scooter',
      rewardAssetId: 'reward_scooter',
      placement: Rect.fromLTWH(0.00, 0.58, 0.34, 0.40),
    ),
    HomeRewardVisual(
      goalId: 'goal_play_house',
      rewardAssetId: 'reward_play_house',
      placement: Rect.fromLTWH(0.65, 0.10, 0.35, 0.72),
    ),
  ];

  static List<HomeAccessoryVisual> accessoriesFor(
    Map<ShopEquipSlot, String> equipped,
  ) => [
    for (final visual in accessories)
      if (equipped[visual.slot] == visual.itemId) visual,
  ];

  static List<HomeRewardVisual> rewardsFor(
    List<CompletedGoal> completed, {
    required int profileId,
  }) => [
    for (final visual in rewards)
      if (completed.any(
        (goal) =>
            goal.profileId == profileId &&
            goal.goalId == visual.goalId &&
            goal.rewardAssetId == visual.rewardAssetId,
      ))
        visual,
  ];

  static double petAspectRatio(int stage) => switch (stage.clamp(1, 3)) {
    1 => 1295 / 1215,
    2 => 1199 / 1312,
    _ => 1154 / 1363,
  };
}

class HomeAccessoryVisual {
  const HomeAccessoryVisual({
    required this.itemId,
    required this.slot,
    required this.asset,
    required this.behindPet,
    required this.anchors,
  });

  final String itemId;
  final ShopEquipSlot slot;
  final String asset;
  final bool behindPet;
  final List<Rect> anchors;

  Rect anchorFor(int stage) => anchors[stage.clamp(1, 3) - 1];
}

class HomeRewardVisual {
  const HomeRewardVisual({
    required this.goalId,
    required this.rewardAssetId,
    required this.placement,
  });

  final String goalId;
  final String rewardAssetId;
  final Rect placement;

  String get asset => SavingsGoalVisual.assetFor(goalId)!;
}
