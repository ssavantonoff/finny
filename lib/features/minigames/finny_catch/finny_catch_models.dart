import 'finny_catch_rules.dart';

enum FinnyCatchPhase { prepare, countdown, playing, paused, result }

enum FinnyCatchObjectType { coin, sparkle, cloud }

class FinnyCatchObject {
  const FinnyCatchObject({
    required this.id,
    required this.type,
    required this.lane,
    required this.spawnAt,
    required this.fallDuration,
  });

  final int id;
  final FinnyCatchObjectType type;
  final int lane;
  final Duration spawnAt;
  final Duration fallDuration;

  Duration get arrivalAt => spawnAt + fallDuration;
  double get x => (lane + 0.5) / FinnyCatchRules.laneCount;

  double progressAt(Duration elapsed) =>
      (elapsed - spawnAt).inMicroseconds / fallDuration.inMicroseconds;
}

class FinnyCatchObjectView {
  const FinnyCatchObjectView(this.object, this.progress);
  final FinnyCatchObject object;
  final double progress;
}

class FinnyCatchState {
  const FinnyCatchState({
    required this.phase,
    required this.score,
    required this.remainingSeconds,
    required this.finnyX,
    required this.objects,
    required this.difficultyPhase,
    required this.runId,
    this.countdownText,
    this.rewardAmount,
    this.rewardGranted = false,
    this.savingReward = false,
    this.rewardError,
  });

  final FinnyCatchPhase phase;
  final int score;
  final int remainingSeconds;
  final double finnyX;
  final List<FinnyCatchObjectView> objects;
  final int difficultyPhase;
  final String runId;
  final String? countdownText;
  final int? rewardAmount;
  final bool rewardGranted;
  final bool savingReward;
  final String? rewardError;
}
