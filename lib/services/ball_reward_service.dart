import 'package:finny/models/ball_reward.dart';
import 'package:finny/features/minigames/ball/ball_session.dart';
import 'package:finny/models/campaign_lifecycle.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/campaign_lifecycle_repository.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/free_play_repository.dart';
import 'package:finny/repositories/game_repository.dart';

/// Applies the systemic effect after the Ball controller confirms eight turns.
/// A replay may always start, even when the systemic effect is exhausted.
class BallRewardService {
  BallRewardService(
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
  final BallRewardPort _campaignReward;
  final FreePlayRepository _freePlay;
  final int? Function() _activeProfileId;

  static const itemId = 'toy_ball';

  void _requireActiveProfile(int profileId) {
    if (profileId <= 0 || _activeProfileId() != profileId) {
      throw StateError('The active profile changed during the Ball session.');
    }
  }

  Future<ShopItem> _canonicalBall() async {
    final matches = (await _content.loadShopItems()).where(
      (item) => item.id == itemId,
    );
    if (matches.length != 1) {
      throw StateError('Canonical Ball item is missing or duplicated.');
    }
    final item = matches.single;
    if (!item.persistent ||
        item.usagePolicy != ItemUsagePolicy.oncePerPeriod ||
        item.displaySection != ShopDisplaySection.toys ||
        item.petEffects.mood <= 0 ||
        item.petEffects.care != 0 ||
        item.petEffects.satiety != 0) {
      throw StateError('Canonical Ball item has unexpected semantics.');
    }
    return item;
  }

  Future<BallGameAccess> checkAccess({required int profileId}) async {
    _requireActiveProfile(profileId);
    final item = await _canonicalBall();
    final definitions = await _content.loadPeriods();
    final lifecycle = await _lifecycle.load(profileId, definitions);
    if (await _games.getInventoryQuantity(profileId, itemId) <= 0) {
      throw PetItemNotOwnedException(itemId);
    }
    _requireActiveProfile(profileId);
    if (lifecycle.mode == CampaignMode.freePlay) {
      return BallGameAccess(
        profileId: profileId,
        mode: BallGameMode.freePlay,
        canonicalMoodEffect: item.petEffects.mood,
      );
    }
    if (lifecycle.mode != CampaignMode.campaign) {
      throw StateError('Ball is unavailable in this campaign stage.');
    }
    final period = await _games.getCurrentPeriod(profileId);
    _requireActiveProfile(profileId);
    if (period?.id == null ||
        period!.status != GamePeriodStatus.active &&
            period.status != GamePeriodStatus.readyToFinish) {
      throw StateError('Ball requires an active campaign period.');
    }
    return BallGameAccess(
      profileId: profileId,
      mode: BallGameMode.campaign,
      periodId: period.id,
      canonicalMoodEffect: item.petEffects.mood,
    );
  }

  /// Only a completed eight-turn session can claim the systemic effect.
  /// Its identity remains stable across an ambiguous database retry.
  Future<BallRewardResult> completeSession({
    required BallGameAccess access,
    required BallSession session,
  }) async {
    final completion = session.completion;
    if (completion == null ||
        !session.canSubmitReward ||
        completion.totalPasses != 8 ||
        completion.sessionId.trim().isEmpty) {
      throw StateError('A completed Ball session is required for reward.');
    }
    final operationId = 'toy-ball:${access.profileId}:${completion.sessionId}';
    _requireActiveProfile(access.profileId);
    final item = await _canonicalBall();
    Future<BallRewardResult?> confirmEarlierCampaignAward() {
      if (access.mode != BallGameMode.campaign || access.periodId == null) {
        return Future<BallRewardResult?>.value();
      }
      return _campaignReward.confirmBallOperation(
        profileId: access.profileId,
        periodId: access.periodId!,
        item: item,
        operationId: operationId,
        activeProfileMatches: () => _activeProfileId() == access.profileId,
      );
    }

    late final BallGameAccess current;
    try {
      current = await checkAccess(profileId: access.profileId);
    } on StateError {
      // A committed Campaign action can be confirmed after its day ends.
      // An absent record still cannot award during an unavailable lifecycle.
      final earlier = await confirmEarlierCampaignAward();
      if (earlier != null) return earlier;
      rethrow;
    }
    if (current.mode != access.mode || current.periodId != access.periodId) {
      final earlier = await confirmEarlierCampaignAward();
      if (earlier != null) return earlier;
      throw StateError('The Ball session lifecycle changed.');
    }
    _requireActiveProfile(access.profileId);
    if (current.mode == BallGameMode.campaign) {
      return _campaignReward.completeBall(
        profileId: access.profileId,
        periodId: current.periodId!,
        item: item,
        operationId: operationId,
        activeProfileMatches: () => _activeProfileId() == access.profileId,
      );
    }
    return _freePlay.completeBall(
      profileId: access.profileId,
      item: item,
      operationId: operationId,
      definitions: await _content.loadPeriods(),
      activeProfileMatches: () => _activeProfileId() == access.profileId,
    );
  }
}
