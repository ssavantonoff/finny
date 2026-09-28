import 'package:finny/models/completed_goal.dart';
import 'package:finny/models/shop_item.dart';
import 'package:flutter/painting.dart';

/// Canonical room state and wearable artwork shared by Home and its summary.
abstract final class HomeRoomVisual {
  static const accessories = [
    HomeAccessoryVisual(
      itemId: 'accessory_bow',
      slot: ShopEquipSlot.head,
      asset: 'assets/images/things/cap_wearable.png',
      behindPet: false,
      anchors: [
        Rect.fromLTWH(0.19, 0.18, 0.62, 0.40),
        Rect.fromLTWH(0.19, 0.17, 0.62, 0.37),
        Rect.fromLTWH(0.18, 0.16, 0.64, 0.35),
      ],
    ),
    HomeAccessoryVisual(
      itemId: 'accessory_collar',
      slot: ShopEquipSlot.neck,
      asset: 'assets/images/things/bandana_wearable.png',
      behindPet: false,
      anchors: [
        Rect.fromLTWH(0.28, 0.62, 0.44, 0.29),
        Rect.fromLTWH(0.29, 0.64, 0.42, 0.27),
        Rect.fromLTWH(0.30, 0.65, 0.40, 0.25),
      ],
    ),
    HomeAccessoryVisual(
      itemId: 'accessory_hat',
      slot: ShopEquipSlot.back,
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
    ),
    HomeRewardVisual(goalId: 'goal_scooter', rewardAssetId: 'reward_scooter'),
    HomeRewardVisual(
      goalId: 'goal_play_house',
      rewardAssetId: 'reward_play_house',
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

  static String roomAssetFor(
    List<CompletedGoal> completed, {
    required int profileId,
  }) {
    final claimed = rewardsFor(
      completed,
      profileId: profileId,
    ).map((reward) => reward.goalId).toSet();
    return switch ((
      claimed.contains('goal_night_light'),
      claimed.contains('goal_scooter'),
      claimed.contains('goal_play_house'),
    )) {
      (false, false, false) => 'assets/images/home/room_base.png',
      (true, false, false) => 'assets/images/home/room_night_light.png',
      (false, true, false) => 'assets/images/home/room_scooter.png',
      (false, false, true) => 'assets/images/home/room_play_house.png',
      (true, true, false) => 'assets/images/home/room_night_light_scooter.png',
      (true, false, true) =>
        'assets/images/home/room_night_light_play_house.png',
      (false, true, true) => 'assets/images/home/room_scooter_play_house.png',
      (true, true, true) => 'assets/images/home/room_all_rewards.png',
    };
  }

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
  const HomeRewardVisual({required this.goalId, required this.rewardAssetId});

  final String goalId;
  final String rewardAssetId;
}
