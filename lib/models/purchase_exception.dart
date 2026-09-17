class InsufficientFundsException extends StateError {
  InsufficientFundsException({
    required this.itemPrice,
    required this.availableBalance,
  }) : super(
         'Insufficient funds: price $itemPrice, available $availableBalance.',
       );

  final int itemPrice;
  final int availableBalance;
}

class PersistentItemAlreadyOwnedException extends StateError {
  PersistentItemAlreadyOwnedException({required this.itemId})
    : super('Persistent item $itemId is already owned.');

  final String itemId;
}
