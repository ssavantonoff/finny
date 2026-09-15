enum ProfileType {
  normal,
  demo;

  String get storageValue => name.toUpperCase();

  static ProfileType fromStorage(String value) => switch (value) {
    'NORMAL' => ProfileType.normal,
    'DEMO' => ProfileType.demo,
    _ => throw FormatException('Unknown profile type: $value'),
  };
}

class Profile {
  const Profile({
    this.id,
    required this.gameName,
    required this.profileType,
    required this.onboardingCompleted,
    required this.createdAt,
  });

  final int? id;
  final String gameName;
  final ProfileType profileType;
  final bool onboardingCompleted;
  final DateTime createdAt;

  Profile copyWith({
    int? id,
    String? gameName,
    ProfileType? profileType,
    bool? onboardingCompleted,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      gameName: gameName ?? this.gameName,
      profileType: profileType ?? this.profileType,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'game_name': gameName,
    'profile_type': profileType.storageValue,
    'onboarding_completed': onboardingCompleted ? 1 : 0,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory Profile.fromMap(Map<String, Object?> map) => Profile(
    id: map['id'] as int,
    gameName: map['game_name'] as String,
    profileType: ProfileType.fromStorage(map['profile_type'] as String),
    onboardingCompleted: (map['onboarding_completed'] as int) == 1,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
