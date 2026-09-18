import 'package:finny/models/game_state.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';

class PurchaseService {
  PurchaseService(this._purchasePort, this._contentRepository);

  final PurchasePort _purchasePort;
  final ContentRepository _contentRepository;

  Future<GameState> purchase({
    required int profileId,
    required int periodId,
    required String itemId,
    required String operationId,
  }) async {
    if (itemId.trim().isEmpty) throw ArgumentError.value(itemId, 'itemId');
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'Must not be empty.',
      );
    }
    final items = await _contentRepository.loadShopItems();
    final matchingItems = items.where((candidate) => candidate.id == itemId);
    if (matchingItems.length != 1) {
      throw StateError(
        'Shop item $itemId is missing or duplicated in content.',
      );
    }
    final canonicalItem = matchingItems.single;
    return _purchasePort.purchase(
      profileId: profileId,
      periodId: periodId,
      item: canonicalItem,
      operationId: operationId,
    );
  }
}
