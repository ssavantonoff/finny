import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_state_rules.dart';
import 'package:finny/repositories/game_repository.dart';

class PetStateService {
  PetStateService(this._gameRepository);

  final GameRepository _gameRepository;

  Future<Pet> applyActiveElapsedTime({
    required int profileId,
    required int periodId,
    required Duration elapsed,
  }) => _gameRepository.applyActiveElapsedTime(
    profileId: profileId,
    periodId: periodId,
    elapsed: elapsed,
  );

  Pet calculateNextMorning(Pet eveningPet) =>
      PetStateRules.nextMorningPet(eveningPet);
}
