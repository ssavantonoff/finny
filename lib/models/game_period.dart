enum GamePeriodStatus {
  planning,
  active,
  readyToFinish,
  completed;

  static GamePeriodStatus fromStorage(String value) => values.firstWhere(
    (status) => status.name == value,
    orElse: () => throw FormatException('Unknown period status: $value'),
  );
}

class GamePeriod {
  const GamePeriod({
    this.id,
    required this.profileId,
    required this.periodNumber,
    required this.startWalletBalance,
    required this.baseIncome,
    required this.extraIncome,
    required this.plannedNeed,
    required this.plannedWant,
    required this.plannedSavings,
    required this.plannedFree,
    required this.actualNeed,
    required this.actualWant,
    required this.actualSavings,
    this.endWalletBalance,
    required this.growthPointsEarned,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  final int? id;
  final int profileId;
  final int periodNumber;
  final int startWalletBalance;
  final int baseIncome;
  final int extraIncome;
  final int plannedNeed;
  final int plannedWant;
  final int plannedSavings;
  final int plannedFree;
  final int actualNeed;
  final int actualWant;
  final int actualSavings;
  final int? endWalletBalance;
  final int growthPointsEarned;
  final GamePeriodStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  int get availableToPlan => startWalletBalance + baseIncome + extraIncome;
  int get plannedTotal =>
      plannedNeed + plannedWant + plannedSavings + plannedFree;

  GamePeriod copyWith({
    int? id,
    int? plannedNeed,
    int? plannedWant,
    int? plannedSavings,
    int? plannedFree,
    int? actualNeed,
    int? actualWant,
    int? actualSavings,
    int? endWalletBalance,
    int? growthPointsEarned,
    GamePeriodStatus? status,
    DateTime? completedAt,
  }) {
    return GamePeriod(
      id: id ?? this.id,
      profileId: profileId,
      periodNumber: periodNumber,
      startWalletBalance: startWalletBalance,
      baseIncome: baseIncome,
      extraIncome: extraIncome,
      plannedNeed: plannedNeed ?? this.plannedNeed,
      plannedWant: plannedWant ?? this.plannedWant,
      plannedSavings: plannedSavings ?? this.plannedSavings,
      plannedFree: plannedFree ?? this.plannedFree,
      actualNeed: actualNeed ?? this.actualNeed,
      actualWant: actualWant ?? this.actualWant,
      actualSavings: actualSavings ?? this.actualSavings,
      endWalletBalance: endWalletBalance ?? this.endWalletBalance,
      growthPointsEarned: growthPointsEarned ?? this.growthPointsEarned,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'profile_id': profileId,
    'period_number': periodNumber,
    'start_wallet_balance': startWalletBalance,
    'base_income': baseIncome,
    'extra_income': extraIncome,
    'planned_need': plannedNeed,
    'planned_want': plannedWant,
    'planned_savings': plannedSavings,
    'planned_free': plannedFree,
    'actual_need': actualNeed,
    'actual_want': actualWant,
    'actual_savings': actualSavings,
    'end_wallet_balance': endWalletBalance,
    'growth_points_earned': growthPointsEarned,
    'status': status.name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'completed_at': completedAt?.toUtc().toIso8601String(),
  };

  factory GamePeriod.fromMap(Map<String, Object?> map) => GamePeriod(
    id: map['id'] as int,
    profileId: map['profile_id'] as int,
    periodNumber: map['period_number'] as int,
    startWalletBalance: map['start_wallet_balance'] as int,
    baseIncome: map['base_income'] as int,
    extraIncome: map['extra_income'] as int,
    plannedNeed: map['planned_need'] as int,
    plannedWant: map['planned_want'] as int,
    plannedSavings: map['planned_savings'] as int,
    plannedFree: map['planned_free'] as int,
    actualNeed: map['actual_need'] as int,
    actualWant: map['actual_want'] as int,
    actualSavings: map['actual_savings'] as int,
    endWalletBalance: map['end_wallet_balance'] as int?,
    growthPointsEarned: map['growth_points_earned'] as int,
    status: GamePeriodStatus.fromStorage(map['status'] as String),
    createdAt: DateTime.parse(map['created_at'] as String),
    completedAt: map['completed_at'] == null
        ? null
        : DateTime.parse(map['completed_at'] as String),
  );
}
