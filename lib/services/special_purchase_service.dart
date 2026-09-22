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

  Future<({ShopPromotion? promotion, bool purchased})> loadPromotionState({
    required int profileId,
    required int periodId,
    required int periodNumber,
  }) async {
    final promotions = await _content.loadPromotions();
    final matches = promotions.where(
      (promotion) => promotion.period == periodNumber,
    );
    if (matches.isEmpty) return (promotion: null, purchased: false);
    if (matches.length != 1) throw StateError('Ambiguous promotion content.');
    final items = await _content.loadShopItems();
    validateSpecialContent(
      await _content.loadStoryPurchases(),
      promotions,
      items,
    );
    final promotion = matches.single;
    final matchingItems = items.where((item) => item.id == promotion.itemId);
    if (matchingItems.length != 1 ||
        !promotion.isCanonicalDay4For(matchingItems.single)) {
      throw StateError('Invalid canonical Day 4 promotion.');
    }
    return (
      promotion: promotion,
      purchased: await _port.hasPurchasedPromotion(
        profileId: profileId,
        periodId: periodId,
        promotionId: promotion.id,
      ),
    );
  }

  Future<GameState> purchasePromotion({
    required int profileId,
    required int periodId,
    required String promotionId,
    required String operationId,
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
    if (!promotion.isCanonicalDay4For(matchingItems.single)) {
      throw StateError('Invalid canonical Day 4 promotion.');
    }
    return _port.purchasePromotion(
      profileId: profileId,
      periodId: periodId,
      promotion: promotion,
      item: matchingItems.single,
      operationId: operationId,
    );
  }
}
