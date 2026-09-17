class CompletedGoal {
  const CompletedGoal({
    required this.profileId,
    required this.goalId,
    required this.rewardAssetId,
    required this.pricePaid,
    required this.completedAt,
    required this.claimOperationId,
  });

  final int profileId;
  final String goalId;
  final String rewardAssetId;
  final int pricePaid;
  final DateTime completedAt;
  final String claimOperationId;

  Map<String, Object?> toMap() => {
    'profile_id': profileId,
    'goal_id': goalId,
    'reward_asset_id': rewardAssetId,
    'price_paid': pricePaid,
    'completed_at': completedAt.toUtc().toIso8601String(),
    'claim_operation_id': claimOperationId,
  };

  factory CompletedGoal.fromMap(Map<String, Object?> map) => CompletedGoal(
    profileId: map['profile_id'] as int,
    goalId: map['goal_id'] as String,
    rewardAssetId: map['reward_asset_id'] as String,
    pricePaid: map['price_paid'] as int,
    completedAt: DateTime.parse(map['completed_at'] as String),
    claimOperationId: map['claim_operation_id'] as String,
  );
}
