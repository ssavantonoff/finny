import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';

class ItemUseService {
  ItemUseService(this._petActionPort, this._contentRepository);

  final PetActionPort _petActionPort;
  final ContentRepository _contentRepository;

  Future<Pet> useItem({
    required int profileId,
    required int periodId,
    required String itemId,
    required String operationId,
    PetActionSlot slot = PetActionSlot.defaultSlot,
  }) async {
    final items = await _contentRepository.loadShopItems();
    final matches = items.where((item) => item.id == itemId);
    if (matches.length != 1) {
      throw StateError(
        'Shop item $itemId is missing or duplicated in canonical content.',
      );
    }
    final item = matches.single;
    if (item.displaySection == ShopDisplaySection.toys) {
      throw PetItemNotUsableException(item.id);
    }
    if (item.usagePolicy == ItemUsagePolicy.none || item.petEffects.isEmpty) {
      throw PetItemNotUsableException(item.id);
    }
    if (item.persistent && item.usagePolicy == ItemUsagePolicy.unlimited ||
        !item.persistent && item.usagePolicy != ItemUsagePolicy.unlimited) {
      throw StateError('Shop item ${item.id} has an invalid usage policy.');
    }
    return _petActionPort.useItem(
      profileId: profileId,
      periodId: periodId,
      item: item,
      operationId: operationId,
      slot: slot,
    );
  }

  Future<Pet> performFreeInteraction({
    required int profileId,
    required int periodId,
    required FreePetInteraction interaction,
    required String operationId,
  }) => _petActionPort.performFreePetInteraction(
    profileId: profileId,
    periodId: periodId,
    interaction: interaction,
    operationId: operationId,
  );
}
