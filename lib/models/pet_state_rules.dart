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
    final target = evening < greenThreshold
        ? 35
        : (35 + (evening - greenThreshold) ~/ 2).clamp(35, initialValue);
    return target.clamp(0, evening);
  }

  static Pet nextMorningPet(Pet eveningPet) => eveningPet.copyWith(
    satiety: nextMorningValue(eveningPet.satiety),
    care: nextMorningValue(eveningPet.care),
    mood: nextMorningValue(eveningPet.mood),
  );
}
