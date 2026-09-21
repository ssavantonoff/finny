enum StoryEventStatus {
  armed,
  postponed,
  purchased;

  static StoryEventStatus fromStorage(String value) => values.firstWhere(
    (status) => status.name == value,
    orElse: () => throw FormatException('Unknown story event status: $value'),
  );
}

class StoryEventSnapshot {
  const StoryEventSnapshot({
    required this.profileId,
    required this.storyId,
    required this.originPeriodId,
    required this.originPeriodNumber,
    required this.threshold,
    required this.qualifyingInteractionCount,
    required this.status,
    required this.currentPeriodId,
    required this.currentPeriodNumber,
    required this.walletBalance,
    required this.savedAmount,
    required this.price,
    required this.savingsUsed,
    required this.wasPostponed,
    this.purchasePeriodNumber,
    this.decisionOperationId,
    this.decisionKind,
  });

  final int profileId;
  final String storyId;
  final int originPeriodId;
  final int originPeriodNumber;
  final int threshold;
  final int qualifyingInteractionCount;
  final StoryEventStatus status;
  final int currentPeriodId;
  final int currentPeriodNumber;
  final int walletBalance;
  final int savedAmount;
  final int price;
  final int savingsUsed;
  final bool wasPostponed;
  final int? purchasePeriodNumber;
  final String? decisionOperationId;
  final String? decisionKind;

  bool get isPurchased => status == StoryEventStatus.purchased;

  bool get isDue =>
      !isPurchased &&
      (status == StoryEventStatus.postponed ||
          qualifyingInteractionCount >= threshold);

  bool get isOutstanding => status == StoryEventStatus.postponed;

  int get walletDeficit => (price - walletBalance).clamp(0, price);

  bool get canUseSavings => walletBalance + savedAmount >= price;

  StoryEventSnapshot copyWith({
    int? walletBalance,
    int? savedAmount,
    StoryEventStatus? status,
    int? qualifyingInteractionCount,
    String? decisionOperationId,
    String? decisionKind,
    int? savingsUsed,
  }) => StoryEventSnapshot(
    profileId: profileId,
    storyId: storyId,
    originPeriodId: originPeriodId,
    originPeriodNumber: originPeriodNumber,
    threshold: threshold,
    qualifyingInteractionCount:
        qualifyingInteractionCount ?? this.qualifyingInteractionCount,
    status: status ?? this.status,
    currentPeriodId: currentPeriodId,
    currentPeriodNumber: currentPeriodNumber,
    walletBalance: walletBalance ?? this.walletBalance,
    savedAmount: savedAmount ?? this.savedAmount,
    price: price,
    savingsUsed: savingsUsed ?? this.savingsUsed,
    wasPostponed: wasPostponed,
    purchasePeriodNumber: purchasePeriodNumber,
    decisionOperationId: decisionOperationId ?? this.decisionOperationId,
    decisionKind: decisionKind ?? this.decisionKind,
  );
}

class StoryEventConflictException implements Exception {
  const StoryEventConflictException(this.operationId);

  final String operationId;

  @override
  String toString() => 'StoryEventConflictException: $operationId';
}

class StoryEventInsufficientFundsException implements Exception {
  const StoryEventInsufficientFundsException({
    required this.price,
    required this.walletBalance,
    required this.savedAmount,
  });

  final int price;
  final int walletBalance;
  final int savedAmount;

  int get deficit => (price - walletBalance).clamp(0, price);

  @override
  String toString() => 'StoryEventInsufficientFundsException(price: $price)';
}
