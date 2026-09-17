sealed class SavingsException implements Exception {
  const SavingsException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

class SavingsGoalRequiredException extends SavingsException {
  const SavingsGoalRequiredException()
    : super('An active savings goal is required.');
}

class SavingsGoalNotFoundException extends SavingsException {
  SavingsGoalNotFoundException(this.goalId)
    : super('Savings goal $goalId was not found.');
  final String goalId;
}

class SavingsGoalAlreadyActiveException extends SavingsException {
  SavingsGoalAlreadyActiveException({required this.activeGoalId})
    : super('Savings goal $activeGoalId is already active.');
  final String activeGoalId;
}

class SavingsGoalAlreadyCompletedException extends SavingsException {
  SavingsGoalAlreadyCompletedException(this.goalId)
    : super('Savings goal $goalId is already completed.');
  final String goalId;
}

class SavingsGoalChangeAlreadyUsedException extends SavingsException {
  const SavingsGoalChangeAlreadyUsedException()
    : super('The savings goal change was already used.');
}

class SavingsGoalReachedException extends SavingsException {
  SavingsGoalReachedException(this.goalId)
    : super('Savings goal $goalId is already reached.');
  final String goalId;
}

class SavingsGoalNotReachedException extends SavingsException {
  SavingsGoalNotReachedException({
    required this.goalId,
    required this.goalPrice,
    required this.savedAmount,
  }) : missingAmount = goalPrice - savedAmount,
       super('Savings goal $goalId is not reached.');
  final String goalId;
  final int goalPrice;
  final int savedAmount;
  final int missingAmount;
}

class SavingsGoalMismatchException extends SavingsException {
  SavingsGoalMismatchException({
    required this.expectedGoalId,
    required this.actualGoalId,
  }) : super('Expected savings goal $expectedGoalId, found $actualGoalId.');
  final String expectedGoalId;
  final String? actualGoalId;
}

class SavingsInsufficientWalletFundsException extends SavingsException {
  SavingsInsufficientWalletFundsException({
    required this.requestedAmount,
    required this.availableBalance,
  }) : super('Insufficient wallet funds.');
  final int requestedAmount;
  final int availableBalance;
}

class SavingsDepositExceedsGoalException extends SavingsException {
  SavingsDepositExceedsGoalException({
    required this.requestedAmount,
    required this.remainingAmount,
  }) : super('Savings deposit exceeds the remaining goal amount.');
  final int requestedAmount;
  final int remainingAmount;
}

class SavingsPeriodNotAvailableException extends SavingsException {
  const SavingsPeriodNotAvailableException()
    : super('Savings mutation is not available for this period.');
}

class SavingsDecisionAlreadyMadeException extends SavingsException {
  const SavingsDecisionAlreadyMadeException()
    : super('The savings decision was already made.');
}

class SavingsOperationConflictException extends SavingsException {
  SavingsOperationConflictException({required this.operationId})
    : super('Operation $operationId was used by another command.');
  final String operationId;
}

class SavingsRewardAlreadyOwnedException extends SavingsException {
  SavingsRewardAlreadyOwnedException(this.rewardAssetId)
    : super('Savings reward $rewardAssetId is already owned.');
  final String rewardAssetId;
}

class SavingsAllGoalsNotCompletedException extends SavingsException {
  const SavingsAllGoalsNotCompletedException()
    : super('Not all savings goals are completed.');
}
