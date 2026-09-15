class GameTransaction {
  const GameTransaction({
    this.id,
    required this.profileId,
    this.periodId,
    required this.type,
    required this.amount,
    required this.source,
    required this.description,
    required this.createdAt,
    this.deduplicationKey,
  });

  final int? id;
  final int profileId;
  final int? periodId;
  final String type;
  final int amount;
  final String source;
  final String description;
  final DateTime createdAt;
  final String? deduplicationKey;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'profile_id': profileId,
    'period_id': periodId,
    'type': type,
    'amount': amount,
    'source': source,
    'description': description,
    'created_at': createdAt.toUtc().toIso8601String(),
    'deduplication_key': deduplicationKey,
  };

  factory GameTransaction.fromMap(Map<String, Object?> map) => GameTransaction(
    id: map['id'] as int,
    profileId: map['profile_id'] as int,
    periodId: map['period_id'] as int?,
    type: map['type'] as String,
    amount: map['amount'] as int,
    source: map['source'] as String,
    description: map['description'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
    deduplicationKey: map['deduplication_key'] as String?,
  );
}
