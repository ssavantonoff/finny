class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.rewardAssetId,
  });

  final String id;
  final String name;
  final int price;
  final String description;
  final String rewardAssetId;

  factory SavingsGoal.fromJson(Map<String, Object?> json) => SavingsGoal(
    id: json['id'] as String,
    name: json['name'] as String,
    price: json['price'] as int,
    description: json['description'] as String,
    rewardAssetId: json['rewardAssetId'] as String,
  );
}
