import 'package:finny/models/pet.dart';

/// The single asset mapping for the player's appearance at every growth stage.
abstract final class FinnyVisual {
  static const colors = ['purple', 'blue', 'mint'];
  static const patterns = ['plain', 'spots', 'stripes'];

  static String assetFor({
    required int developmentStage,
    required String colorId,
    required String patternId,
  }) {
    final stage = developmentStage.clamp(1, 3);
    final color = colors.contains(colorId) ? colorId : 'purple';
    final pattern = patterns.contains(patternId) ? patternId : 'plain';
    return 'assets/images/finny/stage$stage/${color}_$pattern.png';
  }

  static String assetForPet(Pet pet) => assetFor(
    developmentStage: pet.developmentStage,
    colorId: pet.colorId,
    patternId: pet.patternId,
  );

  static String description({
    required int developmentStage,
    required String colorId,
    required String patternId,
    String name = 'Финни',
  }) {
    final stage = developmentStage.clamp(1, 3);
    final color = switch (colorId) {
      'blue' => 'синий',
      'mint' => 'мятный',
      _ => 'фиолетовый',
    };
    final pattern = switch (patternId) {
      'spots' => 'пятнышки',
      'stripes' => 'полоски',
      _ => 'без узора',
    };
    return '$name, $color, $pattern, стадия $stage';
  }

  static String descriptionForPet(Pet pet) => description(
    developmentStage: pet.developmentStage,
    colorId: pet.colorId,
    patternId: pet.patternId,
    name: pet.name,
  );
}
