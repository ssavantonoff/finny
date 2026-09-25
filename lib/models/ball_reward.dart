import 'package:finny/models/pet.dart';

enum BallGameMode { campaign, freePlay }

class BallGameAccess {
  const BallGameAccess({
    required this.profileId,
    required this.mode,
    required this.canonicalMoodEffect,
    this.periodId,
  });

  final int profileId;
  final BallGameMode mode;
  final int canonicalMoodEffect;
  final int? periodId;
}

enum BallRewardStatus { applied, capped, alreadyRewarded, confirmedPreviously }

class BallRewardResult {
  const BallRewardResult({
    required this.status,
    required this.canonicalMoodEffect,
    required this.actualMoodDelta,
    required this.pet,
  });

  final BallRewardStatus status;
  final int canonicalMoodEffect;
  final int actualMoodDelta;
  final Pet pet;
}
