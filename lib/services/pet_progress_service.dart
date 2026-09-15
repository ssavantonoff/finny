import 'package:finny/models/pet.dart';
import 'package:finny/repositories/game_repository.dart';

class PetProgressService {
  PetProgressService(this._gameRepository);

  final GameRepository _gameRepository;

  Future<Pet> addGrowthPoints({
    required int profileId,
    required int points,
  }) async {
    if (points <= 0) {
      throw ArgumentError.value(points, 'points', 'Must be positive.');
    }
    final pet = await _gameRepository.getPet(profileId);
    if (pet == null) throw StateError('Pet for profile $profileId is missing.');
    final totalPoints = pet.growthPoints + points;
    final updated = pet.copyWith(
      growthPoints: totalPoints,
      developmentStage: totalPoints ~/ 100,
    );
    await _gameRepository.savePet(updated);
    return updated;
  }
}
