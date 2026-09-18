import 'package:finny/models/game_state.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';

class SpecialPurchaseService {
  SpecialPurchaseService(this._port, this._content);

  final SpecialPurchasePort _port;
  final ContentRepository _content;

  Future<
    ({
      List<StoryPurchase> stories,
      List<ShopPromotion> promotions,
      List<ShopItem> items,
    })
  >
  _loadCanonical() async {
    final stories = await _content.loadStoryPurchases();
    final promotions = await _content.loadPromotions();
    final items = await _content.loadShopItems();
    validateSpecialContent(stories, promotions, items);
    return (stories: stories, promotions: promotions, items: items);
  }

  Future<GameState> purchaseStory({
    required int profileId,
    required int periodId,
    required String storyPurchaseId,
    required String operationId,
  }) async {
    final canonical = await _loadCanonical();
    final matches = canonical.stories.where(
      (story) => story.id == storyPurchaseId,
    );
    if (matches.length != 1) throw StateError('Unknown story purchase.');
    return _port.purchaseStory(
      profileId: profileId,
      periodId: periodId,
      story: matches.single,
      operationId: operationId,
    );
  }

  Future<GameState> buyPromotion({
    required int profileId,
    required int periodId,
    required String promotionId,
    required String operationId,
  }) => _decide(
    profileId: profileId,
    periodId: periodId,
    promotionId: promotionId,
    operationId: operationId,
    purchase: true,
  );

  Future<GameState> skipPromotion({
    required int profileId,
    required int periodId,
    required String promotionId,
    required String operationId,
  }) => _decide(
    profileId: profileId,
    periodId: periodId,
    promotionId: promotionId,
    operationId: operationId,
    purchase: false,
  );

  Future<GameState> _decide({
    required int profileId,
    required int periodId,
    required String promotionId,
    required String operationId,
    required bool purchase,
  }) async {
    final canonical = await _loadCanonical();
    final matches = canonical.promotions.where(
      (promotion) => promotion.id == promotionId,
    );
    if (matches.length != 1) throw StateError('Unknown promotion.');
    final promotion = matches.single;
    final matchingItems = canonical.items.where(
      (item) => item.id == promotion.itemId,
    );
    if (matchingItems.length != 1) {
      throw StateError('Promotion item is missing.');
    }
    return _port.decidePromotion(
      profileId: profileId,
      periodId: periodId,
      promotion: promotion,
      item: matchingItems.single,
      operationId: operationId,
      purchase: purchase,
    );
  }
}
