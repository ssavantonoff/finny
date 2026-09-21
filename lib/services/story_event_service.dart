import 'package:finny/models/pet_action.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:finny/models/story_event.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';

class StoryEventService {
  StoryEventService(this._port, this._content);

  static const storyId = 'day3_bowl_replacement';

  final StoryEventPort _port;
  final ContentRepository _content;

  Future<StoryEventSnapshot?> loadDay3Bowl({required int profileId}) async {
    final canonical = await _canonical();
    return _port.loadDay3Bowl(
      profileId: profileId,
      qualifyingActionIds: _qualifyingActionIds(canonical.items),
    );
  }

  Future<StoryEventSnapshot?> armOrLoadDay3Bowl({
    required int profileId,
  }) async {
    final canonical = await _canonical();
    return _port.armDay3Bowl(
      profileId: profileId,
      qualifyingActionIds: _qualifyingActionIds(canonical.items),
    );
  }

  Future<StoryEventSnapshot> postponeDay3Bowl({
    required int profileId,
    required int currentPeriodId,
    required String operationId,
  }) async {
    final canonical = await _canonical();
    return _port.postponeDay3Bowl(
      profileId: profileId,
      currentPeriodId: currentPeriodId,
      operationId: operationId,
      qualifyingActionIds: _qualifyingActionIds(canonical.items),
    );
  }

  Future<StoryEventSnapshot> purchaseDay3Bowl({
    required int profileId,
    required int currentPeriodId,
    required String operationId,
    required bool useSavings,
  }) async {
    final canonical = await _canonical();
    return _port.purchaseDay3Bowl(
      profileId: profileId,
      currentPeriodId: currentPeriodId,
      operationId: operationId,
      useSavings: useSavings,
      qualifyingActionIds: _qualifyingActionIds(canonical.items),
    );
  }

  Future<({StoryPurchase story, List<ShopItem> items})> _canonical() async {
    final stories = await _content.loadStoryPurchases();
    final promotions = await _content.loadPromotions();
    final items = await _content.loadShopItems();
    validateSpecialContent(stories, promotions, items);
    final matches = stories.where((story) => story.id == storyId).toList();
    if (matches.length != 1) {
      throw StateError('Canonical Day 3 bowl story is missing.');
    }
    final story = matches.single;
    if (story.period != 3 ||
        story.price != 120 ||
        story.category != ShopItemCategory.need ||
        story.checkpoint != 'changed_circumstance') {
      throw StateError('Canonical Day 3 bowl story is invalid.');
    }
    return (story: story, items: items);
  }

  Set<String> _qualifyingActionIds(List<ShopItem> items) => {
    FreePetInteraction.pet.actionId,
    for (final item in items)
      if (item.displaySection == ShopDisplaySection.food ||
          item.displaySection == ShopDisplaySection.care ||
          item.displaySection == ShopDisplaySection.toys)
        'item:${item.id}',
  };
}
