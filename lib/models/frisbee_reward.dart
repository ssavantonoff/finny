import 'package:finny/models/pet.dart';

enum FrisbeeGameMode { campaign, freePlay }

class FrisbeeGameAccess {
  const FrisbeeGameAccess({
    required this.profileId,
    required this.mode,
    required this.canonicalMoodEffect,
    this.periodId,
  });

  final int profileId;
  final FrisbeeGameMode mode;
  final int canonicalMoodEffect;
  final int? periodId;
}

enum FrisbeeRewardStatus {
  applied,
  capped,
  alreadyRewarded,
  confirmedPreviously,
}

class FrisbeeRewardResult {
  const FrisbeeRewardResult({
    required this.status,
    required this.canonicalMoodEffect,
    required this.actualMoodDelta,
    required this.pet,
  });

  final FrisbeeRewardStatus status;
  final int canonicalMoodEffect;
  final int actualMoodDelta;
  final Pet pet;
}
