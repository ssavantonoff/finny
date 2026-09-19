import 'package:finny/models/pet.dart';

abstract final class PetStateRules {
  static const initialValue = 40;
  static const dayOneInitialSatiety = 55;
  static const dayOneInitialCare = 80;
  static const dayOneInitialMood = 80;
  static const greenThreshold = 70;
  static const maxValue = 100;
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
