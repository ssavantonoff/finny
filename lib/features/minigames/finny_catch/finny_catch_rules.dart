import 'dart:math' as math;

abstract final class FinnyCatchRules {
  static const roundDuration = Duration(seconds: 30);
  static const countdownDuration = Duration(seconds: 2);
  static const laneCount = 5;
  static const coinScore = 1;
  static const sparkleScore = 3;
  static const cloudPenalty = 2;
  static const baseReward = 10;
  static const maxReward = 40;
  static const minCatchArrivalGap = Duration(milliseconds: 750);
  static const catchStartProgress = 0.82;

  static int rewardForScore(int score) =>
      math.min(maxReward, baseReward + math.max(0, score));
}
