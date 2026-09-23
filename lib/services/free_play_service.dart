import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/savings_exception.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/free_play_repository.dart';
import 'package:finny/repositories/game_repository.dart';

class FreePlayService {
  FreePlayService(this._repository, this._content, this._games);

  final FreePlayRepository _repository;
  final ContentRepository _content;
  final GameRepository _games;

  Future<Map<ShopEquipSlot, String>> equipped(int profileId) =>
      _repository.equipped(profileId);

  Future<void> equip({required int profileId, required String itemId}) async {
    final items = await _content.loadShopItems();
    final matches = items.where((item) => item.id == itemId);
    if (matches.length != 1) throw StateError('Unknown shop item $itemId.');
    await _repository.equip(
      profileId: profileId,
      item: matches.single,
      definitions: await _content.loadPeriods(),
    );
  }

  Future<void> unequip({
    required int profileId,
    required ShopEquipSlot slot,
  }) async => _repository.unequip(
    profileId: profileId,
    slot: slot,
    definitions: await _content.loadPeriods(),
  );

  Future<GameState> purchase({
    required int profileId,
    required String itemId,
    required String operationId,
  }) async {
    final items = await _content.loadShopItems();
    final matches = items.where((item) => item.id == itemId);
    if (matches.length != 1) throw StateError('Unknown shop item $itemId.');
    return _repository.purchase(
      profileId: profileId,
      item: matches.single,
      operationId: operationId,
      definitions: await _content.loadPeriods(),
    );
  }

  Future<GameState> deposit({
    required int profileId,
    required int amount,
    required String operationId,
    String? goalId,
  }) async {
    final state = await _games.getGameState(profileId);
    if (state == null) throw StateError('Game state is missing.');
    final goals = await _content.loadGoals();
    SavingsGoal goal;
    final existing = (await _games.getTransactions(profileId))
        .where(
          (transaction) =>
              transaction.deduplicationKey == 'operation:$operationId',
        )
        .firstOrNull;
    if (goalId != null) {
      final matches = goals.where((candidate) => candidate.id == goalId);
      if (matches.length != 1) throw SavingsGoalNotFoundException(goalId);
      goal = matches.single;
    } else if (existing?.source.startsWith('free_play_savings_deposit:') ??
        false) {
      final id = existing!.source.substring(
        'free_play_savings_deposit:'.length,
      );
      goal = goals.singleWhere((g) => g.id == id);
    } else if (state.activeGoalId != null) {
      goal = goals.singleWhere((g) => g.id == state.activeGoalId);
    } else if (existing != null) {
      goal = goals.first;
    } else {
      throw const SavingsGoalRequiredException();
    }
    return _repository.deposit(
      profileId: profileId,
      goal: goal,
      amount: amount,
      operationId: operationId,
      definitions: await _content.loadPeriods(),
    );
  }

  Future<GameState> changeGoal({
    required int profileId,
    required String goalId,
  }) async {
    final state = await _games.getGameState(profileId);
    if (state?.activeGoalId == null) throw const SavingsGoalRequiredException();
    final goals = await _content.loadGoals();
    SavingsGoal find(String id) {
      final matches = goals.where((goal) => goal.id == id);
      if (matches.length != 1) throw SavingsGoalNotFoundException(id);
      return matches.single;
    }

    return _repository.changeGoal(
      profileId: profileId,
      currentGoal: find(state!.activeGoalId!),
      newGoal: find(goalId),
      definitions: await _content.loadPeriods(),
    );
  }

  Future<FreePlayItemResult> useItem({
    required int profileId,
    required String itemId,
    required String operationId,
  }) async {
    final items = await _content.loadShopItems();
    final matches = items.where((item) => item.id == itemId);
    if (matches.length != 1) throw StateError('Unknown shop item $itemId.');
    final item = matches.single;
    if (item.usagePolicy == ItemUsagePolicy.none || item.petEffects.isEmpty) {
      throw PetItemNotUsableException(item.id);
    }
    return _repository.petAction(
      profileId: profileId,
      actionId: 'item:${item.id}',
      effects: item.petEffects,
      operationId: operationId,
      item: item,
      definitions: await _content.loadPeriods(),
    );
  }

  Future<FreePlayItemResult> pet({
    required int profileId,
    required String operationId,
  }) async => _repository.petAction(
    profileId: profileId,
    actionId: FreePetInteraction.pet.actionId,
    effects: FreePetInteraction.pet.effects,
    operationId: operationId,
    definitions: await _content.loadPeriods(),
  );
}
