import 'package:finny/models/game_period.dart';
import 'package:finny/models/pet.dart';

enum BedtimeDecisionType {
  blockedByCheckpoints,
  ready,
  carePossible,
  fallbackAllowed,
}

enum PetStat { satiety, care, mood }

class BedtimeDecision {
  const BedtimeDecision({required this.type, this.statsNeedingCare = const {}});

  final BedtimeDecisionType type;
  final Set<PetStat> statsNeedingCare;
}

class DayCompletionResult {
  const DayCompletionResult({required this.period, required this.pet});

  final GamePeriod period;
  final Pet pet;
}

class BedtimeNotAllowedException implements Exception {
  const BedtimeNotAllowedException(this.decision);

  final BedtimeDecision decision;

  @override
  String toString() => 'BedtimeNotAllowedException: ${decision.type.name}';
}
