import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_state_rules.dart';

enum VirtualDayPhase { morning, daytime, evening }

class VirtualDayTransition {
  const VirtualDayTransition({required this.progress, required this.pet});

  final int progress;
  final Pet pet;
}

abstract final class VirtualDayRules {
  static const minProgress = 0;
  static const maxProgress = 100;
  static const daytimeThreshold = 35;
  static const eveningThreshold = 70;
  static const bedtimeThreshold = 76;

  static const maxSatietyDecay = 60;
  static const maxCareDecay = 20;
  static const maxMoodDecay = 12;

  static const planConfirmationCost = 10;
  static const feedingCost = 8;
  static const feedingTimeLimit = 4;
  static const toothbrushCost = 6;
  static const careCost = 5;
  static const careTimeLimit = 2;
  static const requiredTaskCost = 30;
  static const savingsDecisionCost = 8;
  static const pettingCost = 4;

  static int clampProgress(int value) => value.clamp(minProgress, maxProgress);

  static VirtualDayPhase phaseAt(int progress) {
    final value = clampProgress(progress);
    if (value < daytimeThreshold) return VirtualDayPhase.morning;
    if (value < eveningThreshold) return VirtualDayPhase.daytime;
    return VirtualDayPhase.evening;
  }

  static bool morningToothbrushAvailable(int progress) =>
      clampProgress(progress) < daytimeThreshold;

  static bool eveningToothbrushAvailable(int progress) =>
      clampProgress(progress) >= eveningThreshold;

  static bool bedtimeReached(int progress) =>
      clampProgress(progress) >= bedtimeThreshold;

  static int targetDecay(int progress, int maximum) =>
      maximum * clampProgress(progress) ~/ maxProgress;

  static int satietyDecayAt(int progress) =>
      targetDecay(progress, maxSatietyDecay);

  static int careDecayAt(int progress) => targetDecay(progress, maxCareDecay);

  static int moodDecayAt(int progress) => targetDecay(progress, maxMoodDecay);

  static int decayDelta({
    required int oldProgress,
    required int newProgress,
    required int maximum,
  }) => targetDecay(newProgress, maximum) - targetDecay(oldProgress, maximum);

  static VirtualDayTransition applyAction({
    required Pet pet,
    required int oldProgress,
    required int timeCost,
    int satietyEffect = 0,
    int careEffect = 0,
    int moodEffect = 0,
  }) {
    if (timeCost < 0 || satietyEffect < 0 || careEffect < 0 || moodEffect < 0) {
      throw ArgumentError(
        'Virtual day costs and effects must be non-negative.',
      );
    }
    final oldValue = clampProgress(oldProgress);
    final newValue = clampProgress(oldValue + timeCost);
    final afterDecay = pet.copyWith(
      satiety: PetStateRules.clampStat(
        pet.satiety -
            decayDelta(
              oldProgress: oldValue,
              newProgress: newValue,
              maximum: maxSatietyDecay,
            ),
      ),
      care: PetStateRules.clampStat(
        pet.care -
            decayDelta(
              oldProgress: oldValue,
              newProgress: newValue,
              maximum: maxCareDecay,
            ),
      ),
      mood: PetStateRules.clampStat(
        pet.mood -
            decayDelta(
              oldProgress: oldValue,
              newProgress: newValue,
              maximum: maxMoodDecay,
            ),
      ),
    );
    return VirtualDayTransition(
      progress: newValue,
      pet: afterDecay.copyWith(
        satiety: PetStateRules.clampStat(afterDecay.satiety + satietyEffect),
        care: PetStateRules.clampStat(afterDecay.care + careEffect),
        mood: PetStateRules.clampStat(afterDecay.mood + moodEffect),
      ),
    );
  }
}
