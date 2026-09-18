class Pet {
  const Pet({
    required this.profileId,
    required this.name,
    required this.colorId,
    required this.patternId,
    required this.developmentStage,
    required this.growthPoints,
    required this.satiety,
    required this.care,
    required this.mood,
  });

  final int profileId;
  final String name;
  final String colorId;
  final String patternId;
  final int developmentStage;
  final int growthPoints;
  final int satiety;
  final int care;
  final int mood;

  Pet copyWith({
    String? name,
    String? colorId,
    String? patternId,
    int? developmentStage,
    int? growthPoints,
    int? satiety,
    int? care,
    int? mood,
  }) {
    return Pet(
      profileId: profileId,
      name: name ?? this.name,
      colorId: colorId ?? this.colorId,
      patternId: patternId ?? this.patternId,
      developmentStage: developmentStage ?? this.developmentStage,
      growthPoints: growthPoints ?? this.growthPoints,
      satiety: satiety ?? this.satiety,
      care: care ?? this.care,
      mood: mood ?? this.mood,
    );
  }

  Map<String, Object?> toMap() => {
    'profile_id': profileId,
    'name': name,
    'color_id': colorId,
    'pattern_id': patternId,
    'development_stage': developmentStage,
    'growth_points': growthPoints,
    'satiety': satiety,
    'care': care,
    'mood': mood,
  };

  factory Pet.fromMap(Map<String, Object?> map) => Pet(
    profileId: map['profile_id'] as int,
    name: map['name'] as String,
    colorId: map['color_id'] as String,
    patternId: map['pattern_id'] as String,
    developmentStage: map['development_stage'] as int,
    growthPoints: map['growth_points'] as int,
    satiety: map['satiety'] as int,
    care: map['care'] as int,
    mood: map['mood'] as int,
  );
}
