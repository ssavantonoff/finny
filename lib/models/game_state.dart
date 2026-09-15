class GameState {
  const GameState({
    required this.profileId,
    required this.walletBalance,
    required this.currentPeriod,
    this.activeGoalId,
    required this.savedAmount,
    required this.updatedAt,
  });

  final int profileId;
  final int walletBalance;
  final int currentPeriod;
  final String? activeGoalId;
  final int savedAmount;
  final DateTime updatedAt;

  GameState copyWith({
    int? walletBalance,
    int? currentPeriod,
    String? activeGoalId,
    bool clearActiveGoal = false,
    int? savedAmount,
    DateTime? updatedAt,
  }) {
    return GameState(
      profileId: profileId,
      walletBalance: walletBalance ?? this.walletBalance,
      currentPeriod: currentPeriod ?? this.currentPeriod,
      activeGoalId: clearActiveGoal ? null : activeGoalId ?? this.activeGoalId,
      savedAmount: savedAmount ?? this.savedAmount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
    'profile_id': profileId,
    'wallet_balance': walletBalance,
    'current_period': currentPeriod,
    'active_goal_id': activeGoalId,
    'saved_amount': savedAmount,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory GameState.fromMap(Map<String, Object?> map) => GameState(
    profileId: map['profile_id'] as int,
    walletBalance: map['wallet_balance'] as int,
    currentPeriod: map['current_period'] as int,
    activeGoalId: map['active_goal_id'] as String?,
    savedAmount: map['saved_amount'] as int,
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );
}
