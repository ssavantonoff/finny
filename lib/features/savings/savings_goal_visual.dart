/// Approved artwork for the canonical savings goal IDs.
abstract final class SavingsGoalVisual {
  static const _assets = <String, String>{
    'goal_night_light': 'assets/images/goals/night_light.png',
    'goal_scooter': 'assets/images/goals/scooter.png',
    'goal_play_house': 'assets/images/goals/play_house.png',
  };

  static String? assetFor(String goalId) => _assets[goalId];
}
