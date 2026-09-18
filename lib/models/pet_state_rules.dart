import 'package:finny/models/pet.dart';

abstract final class PetStateRules {
  static const initialValue = 40;
  static const greenThreshold = 70;
  static const maxValue = 100;
  static const fullDailyDecay = Duration(minutes: 6);
  static const maxSatietyDecay = 15;
  static const maxCareDecay = 10;
  static const maxMoodDecay = 12;

  static int decayAt(Duration elapsed, int dailyMaximum) {
    if (elapsed <= Duration.zero) return 0;
    final elapsedMilliseconds = elapsed.inMilliseconds.clamp(
      0,
      fullDailyDecay.inMilliseconds,
    );
    return elapsedMilliseconds * dailyMaximum ~/ fullDailyDecay.inMilliseconds;
  }

  static int clampStat(int value) => value.clamp(0, maxValue);

  static int nextMorningValue(int eveningValue) {
    final evening = clampStat(eveningValue);
    if (evening < greenThreshold) return 35;
    return (35 + (evening - greenThreshold) ~/ 2).clamp(35, initialValue);
  }

  static Pet nextMorningPet(Pet eveningPet) => eveningPet.copyWith(
    satiety: nextMorningValue(eveningPet.satiety),
    care: nextMorningValue(eveningPet.care),
    mood: nextMorningValue(eveningPet.mood),
  );
}
