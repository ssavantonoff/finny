import 'package:finny/models/game_state.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';

class PurchaseService {
  PurchaseService(this._gameRepository, this._contentRepository);

  final GameRepository _gameRepository;
  final ContentRepository _contentRepository;

  Future<GameState> purchase({
    required int profileId,
    required int periodId,
    required ShopItem item,
    required String operationId,
  }) async {
    if (item.price <= 0) {
      throw ArgumentError.value(item.price, 'item.price', 'Must be positive.');
    }
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'Must not be empty.',
      );
    }
    final items = await _contentRepository.loadShopItems();
    final matchingItems = items.where((candidate) => candidate.id == item.id);
    if (matchingItems.length != 1) {
      throw StateError(
        'Shop item ${item.id} is missing or duplicated in content.',
      );
    }
    final canonicalItem = matchingItems.single;
    if (canonicalItem.price != item.price ||
        canonicalItem.category != item.category) {
      throw StateError('Shop item financial data does not match content.');
    }
    return _gameRepository.purchase(
      profileId: profileId,
      periodId: periodId,
      item: canonicalItem,
      operationId: operationId,
    );
  }
}
