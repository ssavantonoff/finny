import 'package:finny/models/shop_item.dart';

enum PetActionSlot {
  defaultSlot('default'),
  morning('morning'),
  evening('evening');

  const PetActionSlot(this.storageValue);

  final String storageValue;
}

enum FreePetInteraction {
  pet(actionId: 'free:pet', effects: PetStatEffects(mood: 20)),
  play(actionId: 'free:play', effects: PetStatEffects(mood: 25));

  const FreePetInteraction({required this.actionId, required this.effects});

  final String actionId;
  final PetStatEffects effects;
}

sealed class PetActionException implements Exception {
  const PetActionException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class PetItemNotOwnedException extends PetActionException {
  PetItemNotOwnedException(this.itemId) : super('Item $itemId is not owned.');

  final String itemId;
}

class PetItemNotUsableException extends PetActionException {
  PetItemNotUsableException(this.itemId)
    : super('Item $itemId cannot be used on Finny.');

  final String itemId;
}

class PetActionAlreadyUsedException extends PetActionException {
  PetActionAlreadyUsedException({required this.actionId, required this.slot})
    : super('Action $actionId was already used in slot ${slot.name}.');

  final String actionId;
  final PetActionSlot slot;
}

class PetActionSlotUnavailableException extends PetActionException {
  PetActionSlotUnavailableException({
    required this.actionId,
    required this.slot,
  }) : super('Slot ${slot.name} is not available for $actionId.');

  final String actionId;
  final PetActionSlot slot;
}

class PetOperationConflictException extends PetActionException {
  PetOperationConflictException(this.operationId)
    : super('Operation $operationId was already used for another action.');

  final String operationId;
}
