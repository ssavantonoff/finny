import 'package:finny/models/game_state.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/game_repository.dart';

class PurchaseService {
  PurchaseService(this._gameRepository);

  final GameRepository _gameRepository;

  Future<GameState> purchase({
    required int profileId,
    required int? periodId,
    required ShopItem item,
  }) {
    if (item.price <= 0) {
      throw ArgumentError.value(item.price, 'item.price', 'Must be positive.');
    }
    return _gameRepository.applyWalletChange(
      GameTransaction(
        profileId: profileId,
        periodId: periodId,
        type: 'purchase',
        amount: -item.price,
        source: 'purchase_${item.id}',
        description: 'Покупка: ${item.name}',
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
}
