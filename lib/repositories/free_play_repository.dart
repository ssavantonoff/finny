import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/ball_reward.dart';
import 'package:finny/models/campaign_lifecycle.dart';
import 'package:finny/models/content_entry.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/pet_state_rules.dart';
import 'package:finny/models/purchase_exception.dart';
import 'package:finny/models/savings_exception.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/campaign_lifecycle_repository.dart';
import 'package:sqflite/sqflite.dart';

class FreePlayItemResult {
  const FreePlayItemResult(this.pet, {this.notice});
  final Pet pet;
  final String? notice;
}

class FreePlayRepository {
  FreePlayRepository(this._database);
  final AppDatabase _database;

  Future<Map<ShopEquipSlot, String>> equipped(int profileId) async {
    final db = await _database.database;
    final rows = await db.query(
      'free_play_equipped_accessories',
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    return {
      for (final row in rows)
        ShopEquipSlot.fromJson(row['slot'] as String): row['item_id'] as String,
    };
  }

  Future<void> equip({
    required int profileId,
    required ShopItem item,
    required List<PeriodDefinition> definitions,
  }) async {
    final slot = item.equipSlot;
    if (!item.persistent ||
        item.displaySection != ShopDisplaySection.accessories ||
        slot == null) {
      throw StateError('This item cannot be equipped.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      await _requireFreePlay(txn, profileId, definitions);
      final owned = await txn.query(
        'inventory',
        columns: ['quantity'],
        where: 'profile_id = ? AND item_id = ?',
        whereArgs: [profileId, item.id],
      );
      if (owned.isEmpty) throw PetItemNotOwnedException(item.id);
      await txn.rawInsert(
        '''
        INSERT INTO free_play_equipped_accessories (profile_id, slot, item_id)
        VALUES (?, ?, ?)
        ON CONFLICT(profile_id, slot) DO UPDATE SET item_id = excluded.item_id
      ''',
        [profileId, slot.name, item.id],
      );
    });
  }

  Future<void> unequip({
    required int profileId,
    required ShopEquipSlot slot,
    required List<PeriodDefinition> definitions,
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await _requireFreePlay(txn, profileId, definitions);
      await txn.delete(
        'free_play_equipped_accessories',
        where: 'profile_id = ? AND slot = ?',
        whereArgs: [profileId, slot.name],
      );
    });
  }

  Future<void> _requireFreePlay(
    DatabaseExecutor txn,
    int profileId,
    List<PeriodDefinition> definitions,
  ) async {
    final lifecycle = await CampaignLifecycleRepository.readInTransaction(
      txn,
      profileId,
      definitions,
    );
    if (lifecycle.mode != CampaignMode.freePlay) {
      throw StateError('Free Play has not started.');
    }
  }

  Future<GameState> _state(DatabaseExecutor txn, int profileId) async {
    final rows = await txn.query(
      'game_states',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Game state is missing.');
    return GameState.fromMap(rows.single);
  }

  Future<Pet> _pet(DatabaseExecutor txn, int profileId) async {
    final rows = await txn.query(
      'pets',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Pet is missing.');
    return Pet.fromMap(rows.single);
  }

  Future<GameTransaction?> _operation(
    DatabaseExecutor txn,
    int profileId,
    String operationId,
  ) async {
    final rows = await txn.query(
      'transactions',
      where: 'profile_id = ? AND deduplication_key = ?',
      whereArgs: [profileId, 'operation:$operationId'],
      limit: 1,
    );
    return rows.isEmpty ? null : GameTransaction.fromMap(rows.single);
  }

  void _checkOperation(String operationId) {
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(operationId, 'operationId');
    }
  }

  void _sameTransaction(GameTransaction previous, GameTransaction requested) {
    if (previous.periodId != null ||
        previous.type != requested.type ||
        previous.amount != requested.amount ||
        previous.source != requested.source ||
        previous.description != requested.description) {
      throw StateError('The operationId belongs to another command.');
    }
  }

  Future<GameState> grantMinigameReward({
    required int profileId,
    required int amount,
    required String runId,
    required List<PeriodDefinition> definitions,
  }) async {
    _checkOperation(runId);
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    final now = DateTime.now().toUtc();
    final command = GameTransaction(
      profileId: profileId,
      type: GameTransactionType.otherIncome,
      amount: amount,
      source: 'free_play_minigame:finny_catch',
      description: 'Мини-игра «Лови монеты»',
      createdAt: now,
      deduplicationKey: 'operation:$runId',
    );
    final db = await _database.database;
    return db.transaction((txn) async {
      await _requireFreePlay(txn, profileId, definitions);
      final previous = await _operation(txn, profileId, runId);
      if (previous != null) {
        _sameTransaction(previous, command);
        return _state(txn, profileId);
      }
      final state = await _state(txn, profileId);
      final updated = state.copyWith(
        walletBalance: state.walletBalance + amount,
        updatedAt: now,
      );
      await txn.insert('transactions', command.toMap());
      await txn.update(
        'game_states',
        updated.toMap(),
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      return updated;
    });
  }

  Future<GameState> purchase({
    required int profileId,
    required ShopItem item,
    required String operationId,
    required List<PeriodDefinition> definitions,
  }) async {
    _checkOperation(operationId);
    final now = DateTime.now().toUtc();
    final command = GameTransaction(
      profileId: profileId,
      type: item.category == ShopItemCategory.need
          ? GameTransactionType.needExpense
          : GameTransactionType.wantExpense,
      amount: -item.price,
      source: 'free_play_purchase:${item.id}',
      description: 'Покупка: ${item.name}',
      createdAt: now,
      deduplicationKey: 'operation:$operationId',
    );
    final db = await _database.database;
    return db.transaction((txn) async {
      await _requireFreePlay(txn, profileId, definitions);
      final previous = await _operation(txn, profileId, operationId);
      if (previous != null) {
        _sameTransaction(previous, command);
        return _state(txn, profileId);
      }
      final owned = await txn.query(
        'inventory',
        columns: ['quantity'],
        where: 'profile_id = ? AND item_id = ?',
        whereArgs: [profileId, item.id],
      );
      if (item.persistent && owned.isNotEmpty) {
        throw PersistentItemAlreadyOwnedException(itemId: item.id);
      }
      final state = await _state(txn, profileId);
      if (state.walletBalance < item.price) {
        throw InsufficientFundsException(
          itemPrice: item.price,
          availableBalance: state.walletBalance,
        );
      }
      await txn.insert('transactions', command.toMap());
      final updated = state.copyWith(
        walletBalance: state.walletBalance - item.price,
        updatedAt: now,
      );
      await txn.update(
        'game_states',
        updated.toMap(),
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      await txn.rawInsert(
        '''
        INSERT INTO inventory (profile_id, item_id, quantity, acquired_at)
        VALUES (?, ?, 1, ?)
        ON CONFLICT(profile_id, item_id) DO UPDATE SET
          quantity = quantity + 1, acquired_at = excluded.acquired_at
      ''',
        [profileId, item.id, now.toIso8601String()],
      );
      return updated;
    });
  }

  Future<GameState> deposit({
    required int profileId,
    required SavingsGoal goal,
    required int amount,
    required String operationId,
    required List<PeriodDefinition> definitions,
  }) async {
    _checkOperation(operationId);
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    final now = DateTime.now().toUtc();
    final command = GameTransaction(
      profileId: profileId,
      type: GameTransactionType.savingsDeposit,
      amount: -amount,
      source: 'free_play_savings_deposit:${goal.id}',
      description: 'Пополнение накоплений',
      createdAt: now,
      deduplicationKey: 'operation:$operationId',
    );
    final db = await _database.database;
    return db.transaction((txn) async {
      await _requireFreePlay(txn, profileId, definitions);
      final previous = await _operation(txn, profileId, operationId);
      if (previous != null) {
        if (previous.periodId != null ||
            previous.type != command.type ||
            previous.amount != command.amount ||
            previous.source != command.source) {
          throw SavingsOperationConflictException(operationId: operationId);
        }
        return _state(txn, profileId);
      }
      final state = await _state(txn, profileId);
      if (state.activeGoalId == null) {
        throw const SavingsGoalRequiredException();
      }
      if (state.activeGoalId != goal.id) {
        throw SavingsGoalMismatchException(
          expectedGoalId: goal.id,
          actualGoalId: state.activeGoalId,
        );
      }
      if (state.savedAmount >= goal.price) {
        throw SavingsGoalReachedException(goal.id);
      }
      if (amount > state.walletBalance) {
        throw SavingsInsufficientWalletFundsException(
          requestedAmount: amount,
          availableBalance: state.walletBalance,
        );
      }
      final remaining = goal.price - state.savedAmount;
      if (amount > remaining) {
        throw SavingsDepositExceedsGoalException(
          requestedAmount: amount,
          remainingAmount: remaining,
        );
      }
      await txn.insert('transactions', command.toMap());
      final updated = state.copyWith(
        walletBalance: state.walletBalance - amount,
        savedAmount: state.savedAmount + amount,
        updatedAt: now,
      );
      await txn.update(
        'game_states',
        updated.toMap(),
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      return updated;
    });
  }

  Future<GameState> changeGoal({
    required int profileId,
    required SavingsGoal currentGoal,
    required SavingsGoal newGoal,
    required List<PeriodDefinition> definitions,
  }) async {
    final db = await _database.database;
    return db.transaction((txn) async {
      await _requireFreePlay(txn, profileId, definitions);
      final state = await _state(txn, profileId);
      if (state.activeGoalId == null) {
        throw const SavingsGoalRequiredException();
      }
      if (state.activeGoalId != currentGoal.id) {
        throw SavingsGoalMismatchException(
          expectedGoalId: currentGoal.id,
          actualGoalId: state.activeGoalId,
        );
      }
      if (state.savedAmount >= currentGoal.price) {
        throw SavingsGoalReachedException(currentGoal.id);
      }
      if (newGoal.id == currentGoal.id) {
        throw SavingsGoalAlreadyActiveException(activeGoalId: currentGoal.id);
      }
      final completed = await txn.query(
        'completed_goals',
        columns: ['goal_id'],
        where: 'profile_id = ? AND goal_id = ?',
        whereArgs: [profileId, newGoal.id],
      );
      if (completed.isNotEmpty) {
        throw SavingsGoalAlreadyCompletedException(newGoal.id);
      }
      final updated = state.copyWith(
        activeGoalId: newGoal.id,
        goalChangeUsed: false,
        updatedAt: DateTime.now().toUtc(),
      );
      await txn.update(
        'game_states',
        updated.toMap(),
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      return updated;
    });
  }

  Future<FreePlayItemResult> petAction({
    required int profileId,
    required String actionId,
    required PetStatEffects effects,
    required String operationId,
    required List<PeriodDefinition> definitions,
    ShopItem? item,
  }) async {
    if (actionId == 'item:toy_ball' || item?.id == 'toy_ball') {
      throw PetItemNotUsableException('toy_ball');
    }
    _checkOperation(operationId);
    if (effects.isEmpty ||
        effects.satiety < 0 ||
        effects.care < 0 ||
        effects.mood < 0 ||
        actionId.trim().isEmpty) {
      throw ArgumentError('A positive pet action is required.');
    }
    final db = await _database.database;
    return db.transaction((txn) async {
      await _requireFreePlay(txn, profileId, definitions);
      final previous = await txn.query(
        'free_play_pet_operations',
        where: 'profile_id = ? AND operation_id = ?',
        whereArgs: [profileId, operationId],
      );
      if (previous.isNotEmpty) {
        if (previous.single['action_id'] != actionId) {
          throw PetOperationConflictException(operationId);
        }
        return FreePlayItemResult(await _pet(txn, profileId));
      }
      final campaignPrevious = await txn.query(
        'pet_action_operations',
        columns: ['operation_id'],
        where: 'profile_id = ? AND operation_id = ?',
        whereArgs: [profileId, operationId],
      );
      if (campaignPrevious.isNotEmpty) {
        throw PetOperationConflictException(operationId);
      }
      final pet = await _pet(txn, profileId);
      if (item != null) {
        if (item.usagePolicy == ItemUsagePolicy.none) {
          throw PetItemNotUsableException(item.id);
        }
        final rows = await txn.query(
          'inventory',
          columns: ['quantity'],
          where: 'profile_id = ? AND item_id = ?',
          whereArgs: [profileId, item.id],
        );
        if (rows.isEmpty) throw PetItemNotOwnedException(item.id);
        final useful =
            effects.satiety > 0 && pet.satiety < 100 ||
            effects.care > 0 && pet.care < 100 ||
            effects.mood > 0 && pet.mood < 100;
        if (!item.persistent && !useful) {
          return FreePlayItemResult(
            pet,
            notice: item.displaySection == ShopDisplaySection.food
                ? 'Финни уже сыт!'
                : 'Финни уже ухожен!',
          );
        }
        if (!item.persistent) {
          final quantity = rows.single['quantity'] as int;
          if (quantity == 1) {
            await txn.delete(
              'inventory',
              where: 'profile_id = ? AND item_id = ?',
              whereArgs: [profileId, item.id],
            );
          } else {
            await txn.update(
              'inventory',
              {'quantity': quantity - 1},
              where: 'profile_id = ? AND item_id = ?',
              whereArgs: [profileId, item.id],
            );
          }
        }
      }
      final updated = pet.copyWith(
        satiety: PetStateRules.clampStat(pet.satiety + effects.satiety),
        care: PetStateRules.clampStat(pet.care + effects.care),
        mood: PetStateRules.clampStat(pet.mood + effects.mood),
      );
      await txn.update(
        'pets',
        updated.toMap(),
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      await txn.insert('free_play_pet_operations', {
        'profile_id': profileId,
        'operation_id': operationId,
        'action_id': actionId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return FreePlayItemResult(updated);
    });
  }

  Future<BallRewardResult> completeBall({
    required int profileId,
    required ShopItem item,
    required String operationId,
    required List<PeriodDefinition> definitions,
    required bool Function() activeProfileMatches,
  }) async {
    _checkOperation(operationId);
    if (item.id != 'toy_ball' ||
        !item.persistent ||
        item.usagePolicy != ItemUsagePolicy.oncePerPeriod ||
        item.petEffects.mood <= 0 ||
        item.petEffects.care != 0 ||
        item.petEffects.satiety != 0) {
      throw StateError('Invalid canonical Ball action.');
    }
    final db = await _database.database;
    return db.transaction((txn) async {
      void requireActiveProfile() {
        if (!activeProfileMatches()) {
          throw StateError(
            'The active profile changed during the Ball session.',
          );
        }
      }

      requireActiveProfile();
      await _requireFreePlay(txn, profileId, definitions);
      final owned = await txn.query(
        'inventory',
        columns: ['quantity'],
        where: 'profile_id = ? AND item_id = ?',
        whereArgs: [profileId, item.id],
        limit: 1,
      );
      if (owned.isEmpty || (owned.single['quantity'] as int) <= 0) {
        throw PetItemNotOwnedException(item.id);
      }
      final previous = await txn.query(
        'free_play_pet_operations',
        columns: ['action_id'],
        where: 'profile_id = ? AND operation_id = ?',
        whereArgs: [profileId, operationId],
        limit: 1,
      );
      if (previous.isNotEmpty) {
        if (previous.single['action_id'] != 'item:toy_ball') {
          throw PetOperationConflictException(operationId);
        }
        requireActiveProfile();
        return BallRewardResult(
          status: BallRewardStatus.confirmedPreviously,
          canonicalMoodEffect: item.petEffects.mood,
          actualMoodDelta: 0,
          pet: await _pet(txn, profileId),
        );
      }
      final campaignPrevious = await txn.query(
        'pet_action_operations',
        columns: ['operation_id'],
        where: 'profile_id = ? AND operation_id = ?',
        whereArgs: [profileId, operationId],
        limit: 1,
      );
      if (campaignPrevious.isNotEmpty) {
        throw PetOperationConflictException(operationId);
      }
      final alreadyRewarded = await txn.query(
        'free_play_pet_operations',
        columns: ['operation_id'],
        where: 'profile_id = ? AND action_id = ?',
        whereArgs: [profileId, 'item:toy_ball'],
        limit: 1,
      );
      final pet = await _pet(txn, profileId);
      if (alreadyRewarded.isNotEmpty) {
        requireActiveProfile();
        return BallRewardResult(
          status: BallRewardStatus.alreadyRewarded,
          canonicalMoodEffect: item.petEffects.mood,
          actualMoodDelta: 0,
          pet: pet,
        );
      }
      requireActiveProfile();
      final updated = pet.copyWith(
        mood: PetStateRules.clampStat(pet.mood + item.petEffects.mood),
      );
      await txn.update(
        'pets',
        updated.toMap()..remove('profile_id'),
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      await txn.insert('free_play_pet_operations', {
        'profile_id': profileId,
        'operation_id': operationId,
        'action_id': 'item:toy_ball',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      requireActiveProfile();
      final delta = updated.mood - pet.mood;
      return BallRewardResult(
        status: delta == 0 ? BallRewardStatus.capped : BallRewardStatus.applied,
        canonicalMoodEffect: item.petEffects.mood,
        actualMoodDelta: delta,
        pet: updated,
      );
    });
  }
}
