import 'package:finny/features/minigames/car/car_session.dart';
import 'package:finny/models/campaign_lifecycle.dart';
import 'package:finny/models/car_reward.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/campaign_lifecycle_repository.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/free_play_repository.dart';
import 'package:finny/repositories/game_repository.dart';

/// Applies the canonical toy effect only after six resolved Car sections.
/// Playing again remains possible after the systemic effect is exhausted.
class CarRewardService {
  CarRewardService(
    this._content,
    this._games,
    this._lifecycle,
    this._campaignReward,
    this._freePlay,
    this._activeProfileId,
  );

  final ContentRepository _content;
  final GameRepository _games;
  final CampaignLifecycleRepository _lifecycle;
  final CarRewardPort _campaignReward;
  final FreePlayRepository _freePlay;
  final int? Function() _activeProfileId;

  static const itemId = 'toy_plush';

  void _requireActiveProfile(int profileId) {
    if (profileId <= 0 || _activeProfileId() != profileId) {
      throw StateError('The active profile changed during the Car session.');
    }
  }

  Future<ShopItem> _canonicalCar() async {
    final matches = (await _content.loadShopItems()).where(
      (item) => item.id == itemId,
    );
    if (matches.length != 1) {
      throw StateError('Canonical Car item is missing or duplicated.');
    }
    final item = matches.single;
    if (!item.persistent ||
        item.usagePolicy != ItemUsagePolicy.oncePerPeriod ||
        item.displaySection != ShopDisplaySection.toys ||
        item.petEffects.mood <= 0 ||
        item.petEffects.care != 0 ||
        item.petEffects.satiety != 0) {
      throw StateError('Canonical Car item has unexpected semantics.');
    }
    return item;
  }

  Future<CarGameAccess> checkAccess({required int profileId}) async {
    _requireActiveProfile(profileId);
    final item = await _canonicalCar();
    final definitions = await _content.loadPeriods();
    final lifecycle = await _lifecycle.load(profileId, definitions);
    if (await _games.getInventoryQuantity(profileId, itemId) <= 0) {
      throw PetItemNotOwnedException(itemId);
    }
    _requireActiveProfile(profileId);
    if (lifecycle.mode == CampaignMode.freePlay) {
      return CarGameAccess(
        profileId: profileId,
        mode: CarGameMode.freePlay,
        canonicalMoodEffect: item.petEffects.mood,
      );
    }
    if (lifecycle.mode != CampaignMode.campaign) {
      throw StateError('Car is unavailable in this campaign stage.');
    }
    final period = await _games.getCurrentPeriod(profileId);
    _requireActiveProfile(profileId);
    if (period?.id == null ||
        period!.status != GamePeriodStatus.active &&
            period.status != GamePeriodStatus.readyToFinish) {
      throw StateError('Car requires an active campaign period.');
    }
    return CarGameAccess(
      profileId: profileId,
      mode: CarGameMode.campaign,
      periodId: period.id,
      canonicalMoodEffect: item.petEffects.mood,
    );
  }

  /// A completed session keeps the same operation identity across retries.
  Future<CarRewardResult> completeSession({
    required CarGameAccess access,
    required CarSession session,
  }) async {
    final completion = session.completion;
    if (completion == null ||
        !session.canSubmitReward ||
        completion.totalSections != 6 ||
        completion.sessionId.trim().isEmpty) {
      throw StateError('A completed Car session is required for reward.');
    }
    final operationId = 'toy-car:${access.profileId}:${completion.sessionId}';
    _requireActiveProfile(access.profileId);
    final item = await _canonicalCar();
    Future<CarRewardResult?> confirmEarlierCampaignAward() {
      if (access.mode != CarGameMode.campaign || access.periodId == null) {
        return Future<CarRewardResult?>.value();
      }
      return _campaignReward.confirmCarOperation(
        profileId: access.profileId,
        periodId: access.periodId!,
        item: item,
        operationId: operationId,
        activeProfileMatches: () => _activeProfileId() == access.profileId,
      );
    }

    late final CarGameAccess current;
    try {
      current = await checkAccess(profileId: access.profileId);
    } on StateError {
      // A committed action can be confirmed after its Campaign period ends.
      final earlier = await confirmEarlierCampaignAward();
      if (earlier != null) return earlier;
      rethrow;
    }
    if (current.mode != access.mode || current.periodId != access.periodId) {
      final earlier = await confirmEarlierCampaignAward();
      if (earlier != null) return earlier;
      throw StateError('The Car session lifecycle changed.');
    }
    _requireActiveProfile(access.profileId);
    if (current.mode == CarGameMode.campaign) {
      return _campaignReward.completeCar(
        profileId: access.profileId,
        periodId: current.periodId!,
        item: item,
        operationId: operationId,
        activeProfileMatches: () => _activeProfileId() == access.profileId,
      );
    }
    return _freePlay.completeCar(
      profileId: access.profileId,
      item: item,
      operationId: operationId,
      definitions: await _content.loadPeriods(),
      activeProfileMatches: () => _activeProfileId() == access.profileId,
    );
  }
}
