import 'package:finny/models/pet.dart';

enum CarGameMode { campaign, freePlay }

class CarGameAccess {
  const CarGameAccess({
    required this.profileId,
    required this.mode,
    required this.canonicalMoodEffect,
    this.periodId,
  });

  final int profileId;
  final CarGameMode mode;
  final int canonicalMoodEffect;
  final int? periodId;
}

enum CarRewardStatus { applied, capped, alreadyRewarded, confirmedPreviously }

class CarRewardResult {
  const CarRewardResult({
    required this.status,
    required this.canonicalMoodEffect,
    required this.actualMoodDelta,
    required this.pet,
  });

  final CarRewardStatus status;
  final int canonicalMoodEffect;
  final int actualMoodDelta;
  final Pet pet;
}
