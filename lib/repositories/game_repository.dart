import 'dart:collection';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/completed_goal.dart';
import 'package:finny/models/day_lifecycle.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/pet_state_rules.dart';
import 'package:finny/models/purchase_exception.dart';
import 'package:finny/models/savings_exception.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/models/task_progress.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/models/virtual_day_rules.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class GameRepository {
  Future<void> createInitialState(GameState state);
  Future<GameState> ensureInitialState(int profileId);
  Future<GameState?> getGameState(int profileId);
  Future<void> savePet(Pet pet);
  Future<Pet?> getPet(int profileId);
  Future<int> getPetDailyUsageCount({
    required int profileId,
    required int periodId,
    required String actionId,
    required PetActionSlot slot,
  });
  Future<GamePeriod?> getPeriod(int profileId, int periodNumber);
  Future<GamePeriod?> getPeriodById(int profileId, int periodId);
  Future<GamePeriod?> getCurrentPeriod(int profileId);
  Future<List<GamePeriod>> getPeriods(int profileId);
  Future<GamePeriod> startPeriod({
    required int profileId,
    required String definitionId,
    required int periodNumber,
    required int baseIncome,
    required List<String> requiredCheckpoints,
    required DateTime createdAt,
  });
  Future<GamePeriod> saveBudget({
    required int profileId,
    required int periodId,
    required int plannedNeed,
    required int plannedWant,
    required int plannedSavings,
  });
  Future<GamePeriod> confirmBudget({
    required int profileId,
    required int periodId,
  });
  Future<GamePeriod> resolveCheckpoint({
    required int profileId,
    required int periodId,
    required String checkpointId,
  });
  Future<TaskProgress?> getTaskProgress(int profileId, String taskId);
  Future<GameState> applyWalletChange(GameTransaction transaction);
  Future<GameState> applyIdempotentWalletChange(GameTransaction transaction);
  Future<List<CompletedGoal>> getCompletedGoals(int profileId);
  Future<GameState> selectSavingsGoal({
    required int profileId,
    required SavingsGoal goal,
  });
  Future<GameState> changeSavingsGoal({
    required int profileId,
    required SavingsGoal currentGoal,
    required SavingsGoal newGoal,
  });
  Future<GameState> depositSavings({
    required int profileId,
    required int periodId,
    required SavingsGoal goal,
    required int amount,
    required String operationId,
  });
  Future<GamePeriod> skipSavingsDecision({
    required int profileId,
    required int periodId,
  });
  Future<GamePeriod> resolveSavingsDecisionForCompletedGoals({
    required int profileId,
    required int periodId,
    required Set<String> canonicalGoalIds,
  });
  Future<GameState> claimSavingsGoal({
    required int profileId,
    required SavingsGoal goal,
    required String operationId,
  });
  Future<int> getInventoryQuantity(int profileId, String itemId);
  Future<List<GameTransaction>> getTransactions(int profileId, {int? periodId});
  Future<void> clearDemoRuntimeData(int profileId);
}

abstract interface class TaskCompletionPort {
  Future<TaskSubmissionResult> submitFinancialTaskAnswer({
    required int profileId,
    required int periodId,
    required FinancialTask task,
    required String answerId,
  });
}

abstract interface class PurchasePort {
  Future<GameState> purchase({
    required int profileId,
    required int periodId,
    required ShopItem item,
    required String operationId,
  });
}

abstract interface class SpecialPurchasePort {
  Future<GameState> purchaseStory({
    required int profileId,
    required int periodId,
    required StoryPurchase story,
    required String operationId,
  });
  Future<GameState> decidePromotion({
    required int profileId,
    required int periodId,
    required ShopPromotion promotion,
    required ShopItem item,
    required String operationId,
    required bool purchase,
  });
}

abstract interface class PetActionPort {
  Future<Pet> useItem({
    required int profileId,
    required int periodId,
    required ShopItem item,
    required String operationId,
    required PetActionSlot slot,
  });

  Future<Pet> performFreePetInteraction({
    required int profileId,
    required int periodId,
    required FreePetInteraction interaction,
    required String operationId,
  });
}

abstract interface class DayLifecyclePort {
  Future<BedtimeDecision> evaluateBedtime({
    required int profileId,
    required int periodId,
    required List<ShopItem> canonicalItems,
  });

  Future<DayCompletionResult> sleep({
    required int profileId,
    required int periodId,
    required bool allowFallback,
    required List<ShopItem> canonicalItems,
  });
}

class SqliteGameRepository implements GameRepository {
  SqliteGameRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<void> createInitialState(GameState state) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.insert('game_states', state.toMap());
      await _ensureStarterToothbrush(txn, state.profileId);
    });
  }

  @override
  Future<GameState> ensureInitialState(int profileId) async {
    if (profileId <= 0) {
      throw ArgumentError.value(profileId, 'profileId', 'Must be positive.');
    }
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final initialState = GameState(
        profileId: profileId,
        walletBalance: 0,
        currentPeriod: 0,
        savedAmount: 0,
        goalChangeUsed: false,
        updatedAt: DateTime.now().toUtc(),
      );
      await txn.insert(
        'game_states',
        initialState.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await _ensureStarterToothbrush(txn, profileId);
      return _requireState(txn, profileId);
    });
  }

  @override
  Future<GameState?> getGameState(int profileId) async {
    final db = await _appDatabase.database;
    return _readState(db, profileId);
  }

  @override
  Future<void> savePet(Pet pet) async {
    _validatePet(pet);
    final db = await _appDatabase.database;
    await db.insert(
      'pets',
      pet.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Pet?> getPet(int profileId) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'pets',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    return rows.isEmpty ? null : Pet.fromMap(rows.single);
  }

  @override
  Future<int> getPetDailyUsageCount({
    required int profileId,
    required int periodId,
    required String actionId,
    required PetActionSlot slot,
  }) async {
    final db = await _appDatabase.database;
    await _requirePeriod(db, profileId, periodId);
    return _readPetDailyUsageCount(
      db,
      profileId: profileId,
      periodId: periodId,
      actionId: actionId,
      slot: slot,
    );
  }

  Future<Pet> _applyPetAction({
    required int profileId,
    required int periodId,
    required String actionId,
    required String operationId,
    required PetActionSlot slot,
    required PetStatEffects effects,
    ShopItem? item,
  }) async {
    _validateOperationId(operationId);
    if (profileId <= 0 || periodId <= 0 || actionId.trim().isEmpty) {
      throw ArgumentError('Pet action identity is invalid.');
    }
    if (effects.isEmpty ||
        effects.satiety < 0 ||
        effects.care < 0 ||
        effects.mood < 0) {
      throw ArgumentError('Pet action effects must be positive.');
    }
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final existing = await _readPetActionOperation(
        txn,
        profileId: profileId,
        operationId: operationId,
      );
      if (existing != null) {
        if (existing['period_id'] != periodId ||
            existing['action_id'] != actionId ||
            existing['usage_slot'] != slot.storageValue) {
          throw PetOperationConflictException(operationId);
        }
        return _requirePet(txn, profileId);
      }

      final period = await _requirePeriod(txn, profileId, periodId);
      _requirePetActionsAllowed(period);
      final pet = await _requirePet(txn, profileId);

      final usagePolicy = item?.usagePolicy ?? ItemUsagePolicy.oncePerPeriod;
      _requireValidPetActionSlot(
        period: period,
        actionId: actionId,
        policy: usagePolicy,
        slot: slot,
      );

      final usageCount = await _readPetDailyUsageCount(
        txn,
        profileId: profileId,
        periodId: periodId,
        actionId: actionId,
        slot: slot,
      );
      if (usagePolicy != ItemUsagePolicy.unlimited && usageCount > 0) {
        throw PetActionAlreadyUsedException(actionId: actionId, slot: slot);
      }

      int? ownedQuantity;
      if (item != null) {
        ownedQuantity = await _readInventoryQuantity(txn, profileId, item.id);
        if (ownedQuantity <= 0) throw PetItemNotOwnedException(item.id);
      }

      var timeCost = item == null ? VirtualDayRules.pettingCost : 0;
      String? timeUsageActionId;
      if (item?.usagePolicy == ItemUsagePolicy.toothbrush) {
        timeCost = VirtualDayRules.toothbrushCost;
      } else if (item?.displaySection == ShopDisplaySection.food) {
        timeUsageActionId = 'time:feeding';
        final count = await _readPetDailyUsageCount(
          txn,
          profileId: profileId,
          periodId: periodId,
          actionId: timeUsageActionId,
          slot: PetActionSlot.defaultSlot,
        );
        if (count < VirtualDayRules.feedingTimeLimit) {
          timeCost = VirtualDayRules.feedingCost;
        }
      } else if (item?.displaySection == ShopDisplaySection.care) {
        timeUsageActionId = 'time:care';
        final count = await _readPetDailyUsageCount(
          txn,
          profileId: profileId,
          periodId: periodId,
          actionId: timeUsageActionId,
          slot: PetActionSlot.defaultSlot,
        );
        if (count < VirtualDayRules.careTimeLimit) {
          timeCost = VirtualDayRules.careCost;
        }
      }

      final transition = await _applyVirtualDayAction(
        txn,
        period: period,
        timeCost: timeCost,
        effects: effects,
        pet: pet,
      );
      final updatedPet = transition.pet!;

      if (item != null && !item.persistent) {
        if (ownedQuantity == 1) {
          await txn.delete(
            'inventory',
            where: 'profile_id = ? AND item_id = ?',
            whereArgs: [profileId, item.id],
          );
        } else {
          await txn.update(
            'inventory',
            {'quantity': ownedQuantity! - 1},
            where: 'profile_id = ? AND item_id = ?',
            whereArgs: [profileId, item.id],
          );
        }
      }

      final now = DateTime.now().toUtc().toIso8601String();
      await _incrementPetDailyUsage(
        txn,
        profileId: profileId,
        periodId: periodId,
        actionId: actionId,
        slot: slot,
        updatedAt: now,
      );
      if (timeUsageActionId != null) {
        await _incrementPetDailyUsage(
          txn,
          profileId: profileId,
          periodId: periodId,
          actionId: timeUsageActionId,
          slot: PetActionSlot.defaultSlot,
          updatedAt: now,
        );
      }
      await txn.insert('pet_action_operations', {
        'profile_id': profileId,
        'operation_id': operationId,
        'period_id': periodId,
        'action_id': actionId,
        'usage_slot': slot.storageValue,
        'created_at': now,
      });
      return updatedPet;
    });
  }

  @override
  Future<GamePeriod?> getPeriod(int profileId, int periodNumber) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'game_periods',
      where: 'profile_id = ? AND period_number = ?',
      whereArgs: [profileId, periodNumber],
      limit: 1,
    );
    return rows.isEmpty ? null : GamePeriod.fromMap(rows.single);
  }

  @override
  Future<GamePeriod?> getPeriodById(int profileId, int periodId) async {
    final db = await _appDatabase.database;
    return _readPeriodById(db, profileId, periodId);
  }

  @override
  Future<GamePeriod?> getCurrentPeriod(int profileId) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'game_periods',
      where: 'profile_id = ? AND status != ?',
      whereArgs: [profileId, GamePeriodStatus.completed.name],
      orderBy: 'period_number DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : GamePeriod.fromMap(rows.single);
  }

  @override
  Future<List<GamePeriod>> getPeriods(int profileId) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'game_periods',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'period_number ASC',
    );
    return rows.map(GamePeriod.fromMap).toList(growable: false);
  }

  @override
  Future<GamePeriod> startPeriod({
    required int profileId,
    required String definitionId,
    required int periodNumber,
    required int baseIncome,
    required List<String> requiredCheckpoints,
    required DateTime createdAt,
  }) async {
    if (profileId <= 0 ||
        definitionId.trim().isEmpty ||
        periodNumber <= 0 ||
        baseIncome < 0) {
      throw ArgumentError('Period snapshot values are invalid.');
    }
    final checkpoints = requiredCheckpoints.toSet();
    if (checkpoints.length != requiredCheckpoints.length ||
        checkpoints.any((checkpoint) => checkpoint.trim().isEmpty)) {
      throw ArgumentError('Required checkpoints must be non-empty and unique.');
    }
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final state = await _requireState(txn, profileId);
      final unfinished = await txn.query(
        'game_periods',
        columns: ['id'],
        where: 'profile_id = ? AND status != ?',
        whereArgs: [profileId, GamePeriodStatus.completed.name],
        limit: 1,
      );
      if (unfinished.isNotEmpty) {
        throw StateError(
          'Profile $profileId already has an unfinished period.',
        );
      }
      final existing = await txn.query(
        'game_periods',
        columns: ['id'],
        where: 'profile_id = ? AND (period_number = ? OR definition_id = ?)',
        whereArgs: [profileId, periodNumber, definitionId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw StateError('Period $definitionId already exists.');
      }

      if (periodNumber > 1) {
        final previousRows = await txn.query(
          'game_periods',
          columns: ['status'],
          where: 'profile_id = ? AND period_number = ?',
          whereArgs: [profileId, periodNumber - 1],
          limit: 1,
        );
        if (previousRows.isNotEmpty &&
            previousRows.single['status'] == GamePeriodStatus.completed.name) {
          final petRows = await txn.query(
            'pets',
            where: 'profile_id = ?',
            whereArgs: [profileId],
            limit: 1,
          );
          if (petRows.isNotEmpty) {
            final eveningPet = Pet.fromMap(petRows.single);
            await _writePet(txn, PetStateRules.nextMorningPet(eveningPet));
          }
        }
      }

      final period = GamePeriod(
        profileId: profileId,
        definitionId: definitionId,
        periodNumber: periodNumber,
        startWalletBalance: state.walletBalance,
        baseIncome: baseIncome,
        extraIncome: 0,
        plannedNeed: 0,
        plannedWant: 0,
        plannedSavings: 0,
        plannedFree: state.walletBalance + baseIncome,
        actualNeed: 0,
        actualWant: 0,
        actualSavings: 0,
        requiredCheckpoints: List.unmodifiable(requiredCheckpoints),
        resolvedCheckpoints: const [],
        growthPointsEarned: 0,
        status: GamePeriodStatus.planning,
        createdAt: createdAt,
      );
      final periodId = await txn.insert('game_periods', period.toMap());
      final started = period.copyWith(id: periodId);
      if (period.baseIncome > 0) {
        await txn.insert(
          'transactions',
          GameTransaction(
            profileId: profileId,
            periodId: periodId,
            type: GameTransactionType.periodIncome,
            amount: period.baseIncome,
            source: 'period_income',
            description: 'Доход периода ${period.periodNumber}',
            createdAt: period.createdAt,
            deduplicationKey: 'period_income_$definitionId',
          ).toMap(),
        );
      }
      final updatedState = state.copyWith(
        walletBalance: state.walletBalance + period.baseIncome,
        currentPeriod: periodNumber,
        updatedAt: period.createdAt,
      );
      await _writeState(txn, updatedState);
      return started;
    });
  }

  @override
  Future<GamePeriod> saveBudget({
    required int profileId,
    required int periodId,
    required int plannedNeed,
    required int plannedWant,
    required int plannedSavings,
  }) async {
    if (plannedNeed < 0 || plannedWant < 0 || plannedSavings < 0) {
      throw ArgumentError('Budget values cannot be negative.');
    }
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final period = await _requirePeriod(txn, profileId, periodId);
      if (period.status != GamePeriodStatus.planning) {
        throw StateError('Only a planning period budget can be changed.');
      }
      final allocated = plannedNeed + plannedWant + plannedSavings;
      if (allocated > period.startingBudget) {
        throw StateError('Budget cannot exceed the starting budget.');
      }
      final updated = period.copyWith(
        plannedNeed: plannedNeed,
        plannedWant: plannedWant,
        plannedSavings: plannedSavings,
        plannedFree: period.startingBudget - allocated,
      );
      await _writePeriod(txn, updated);
      return updated;
    });
  }

  @override
  Future<GamePeriod> confirmBudget({
    required int profileId,
    required int periodId,
  }) async {
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final period = await _requirePeriod(txn, profileId, periodId);
      if (period.status == GamePeriodStatus.active ||
          period.status == GamePeriodStatus.readyToFinish) {
        return period;
      }
      if (period.status != GamePeriodStatus.planning) {
        throw StateError('Only a planning period budget can be confirmed.');
      }
      final advanced = await _applyVirtualDayAction(
        txn,
        period: period,
        timeCost: VirtualDayRules.planConfirmationCost,
      );
      final confirmed = advanced.period.copyWith(
        status: GamePeriodStatus.active,
      );
      await _writePeriod(txn, confirmed);
      return confirmed;
    });
  }

  @override
  Future<GamePeriod> resolveCheckpoint({
    required int profileId,
    required int periodId,
    required String checkpointId,
  }) async {
    if (checkpointId == 'financial_task' ||
        checkpointId == 'savings_decision' ||
        checkpointId == 'changed_circumstance' ||
        checkpointId == 'discount_decision') {
      throw StateError(
        'Protected checkpoints require their canonical service.',
      );
    }
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final period = await _requirePeriod(txn, profileId, periodId);
      if (period.status != GamePeriodStatus.active &&
          period.status != GamePeriodStatus.readyToFinish) {
        throw StateError(
          'Checkpoints can only be resolved during an active period.',
        );
      }
      return _resolveCheckpointInTransaction(txn, period, checkpointId);
    });
  }

  Future<GamePeriod> _resolveCheckpointInTransaction(
    DatabaseExecutor txn,
    GamePeriod period,
    String checkpointId,
  ) async {
    if (!period.requiredCheckpoints.contains(checkpointId)) {
      throw StateError(
        'Checkpoint $checkpointId is not required for this period.',
      );
    }
    if (period.resolvedCheckpoints.contains(checkpointId)) return period;
    if (period.status != GamePeriodStatus.active) {
      throw StateError('Only an active period accepts new checkpoints.');
    }
    final resolved = [
      for (final required in period.requiredCheckpoints)
        if (required == checkpointId ||
            period.resolvedCheckpoints.contains(required))
          required,
    ];
    final updated = period.copyWith(
      resolvedCheckpoints: List.unmodifiable(resolved),
      status: resolved.length == period.requiredCheckpoints.length
          ? GamePeriodStatus.readyToFinish
          : GamePeriodStatus.active,
    );
    await _writePeriod(txn, updated);
    return updated;
  }

  @override
  Future<TaskProgress?> getTaskProgress(int profileId, String taskId) async {
    final db = await _appDatabase.database;
    return _readTaskProgress(db, profileId, taskId);
  }

  Future<TaskProgress?> _readTaskProgress(
    DatabaseExecutor db,
    int profileId,
    String taskId,
  ) async {
    final rows = await db.query(
      'task_progress',
      where: 'profile_id = ? AND task_id = ?',
      whereArgs: [profileId, taskId],
      limit: 1,
    );
    return rows.isEmpty ? null : TaskProgress.fromMap(rows.single);
  }

  @override
  Future<GameState> applyWalletChange(GameTransaction transaction) async {
    if (transaction.type == GameTransactionType.taskReward) {
      throw StateError('Task rewards require atomic task completion.');
    }
    _validateNewTransaction(transaction);
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      if (transaction.periodId != null) {
        final period = await _requirePeriod(
          txn,
          transaction.profileId,
          transaction.periodId!,
        );
        _requireFinancialActionsAllowed(period);
      }
      if (transaction.deduplicationKey != null &&
          await _readTransactionByKey(
                txn,
                transaction.profileId,
                transaction.deduplicationKey!,
              ) !=
              null) {
        throw StateError('This transaction has already been recorded.');
      }
      return _applyWalletTransaction(txn, transaction);
    });
  }

  @override
  Future<GameState> applyIdempotentWalletChange(
    GameTransaction transaction,
  ) async {
    if (transaction.type == GameTransactionType.taskReward) {
      throw StateError('Task rewards require atomic task completion.');
    }
    _validateNewTransaction(transaction);
    final key = transaction.deduplicationKey;
    if (key == null || key.trim().isEmpty) {
      throw ArgumentError('An idempotent transaction requires a key.');
    }
    final periodId = transaction.periodId;
    if (periodId == null) {
      throw ArgumentError('A Core transaction requires a periodId.');
    }
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final period = await _requirePeriod(txn, transaction.profileId, periodId);
      final existing = await _readTransactionByKey(
        txn,
        transaction.profileId,
        key,
      );
      if (existing != null) {
        _requireSameCommand(existing, transaction);
        return _requireState(txn, transaction.profileId);
      }
      _requireFinancialActionsAllowed(period);
      return _applyWalletTransaction(txn, transaction);
    });
  }

  @override
  Future<List<CompletedGoal>> getCompletedGoals(int profileId) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'completed_goals',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'completed_at ASC, goal_id ASC',
    );
    return rows.map(CompletedGoal.fromMap).toList(growable: false);
  }

  @override
  Future<GameState> selectSavingsGoal({
    required int profileId,
    required SavingsGoal goal,
  }) async {
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final state = await _requireValidSavingsState(txn, profileId);
      if (await _isGoalCompleted(txn, profileId, goal.id)) {
        throw SavingsGoalAlreadyCompletedException(goal.id);
      }
      if (state.activeGoalId == goal.id && !state.goalChangeUsed) return state;
      if (state.activeGoalId != null) {
        throw SavingsGoalAlreadyActiveException(
          activeGoalId: state.activeGoalId!,
        );
      }
      final updated = state.copyWith(
        activeGoalId: goal.id,
        goalChangeUsed: false,
        updatedAt: DateTime.now().toUtc(),
      );
      await _writeState(txn, updated);
      return updated;
    });
  }

  @override
  Future<GameState> changeSavingsGoal({
    required int profileId,
    required SavingsGoal currentGoal,
    required SavingsGoal newGoal,
  }) async {
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final state = await _requireValidSavingsState(txn, profileId);
      if (state.activeGoalId == newGoal.id && state.goalChangeUsed) {
        return state;
      }
      if (state.activeGoalId == null) {
        throw const SavingsGoalRequiredException();
      }
      if (state.activeGoalId != currentGoal.id) {
        throw SavingsGoalMismatchException(
          expectedGoalId: currentGoal.id,
          actualGoalId: state.activeGoalId,
        );
      }
      if (state.goalChangeUsed) {
        throw const SavingsGoalChangeAlreadyUsedException();
      }
      if (state.savedAmount >= currentGoal.price) {
        throw SavingsGoalReachedException(currentGoal.id);
      }
      if (newGoal.id == currentGoal.id) {
        throw SavingsGoalAlreadyActiveException(activeGoalId: currentGoal.id);
      }
      if (await _isGoalCompleted(txn, profileId, newGoal.id)) {
        throw SavingsGoalAlreadyCompletedException(newGoal.id);
      }
      final updated = state.copyWith(
        activeGoalId: newGoal.id,
        goalChangeUsed: true,
        updatedAt: DateTime.now().toUtc(),
      );
      await _writeState(txn, updated);
      return updated;
    });
  }

  @override
  Future<GameState> depositSavings({
    required int profileId,
    required int periodId,
    required SavingsGoal goal,
    required int amount,
    required String operationId,
  }) async {
    _validateOperationId(operationId);
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be positive.');
    }
    final transaction = GameTransaction(
      profileId: profileId,
      periodId: periodId,
      type: GameTransactionType.savingsDeposit,
      amount: -amount,
      source: 'savings_deposit:${goal.id}',
      description: 'Пополнение накоплений',
      createdAt: DateTime.now().toUtc(),
      deduplicationKey: 'operation:$operationId',
    );
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final period = await _requirePeriod(txn, profileId, periodId);
      final existing = await _readTransactionByKey(
        txn,
        profileId,
        transaction.deduplicationKey!,
      );
      if (existing != null) {
        _requireSameSavingsCommand(existing, transaction, operationId);
        return _requireState(txn, profileId);
      }
      if (period.status != GamePeriodStatus.active &&
          period.status != GamePeriodStatus.readyToFinish) {
        throw const SavingsPeriodNotAvailableException();
      }
      final state = await _requireValidSavingsState(txn, profileId);
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
      await txn.insert('transactions', transaction.toMap());
      final firstDecision = !period.resolvedCheckpoints.contains(
        'savings_decision',
      );
      final advanced = firstDecision
          ? (await _applyVirtualDayAction(
              txn,
              period: period,
              timeCost: VirtualDayRules.savingsDecisionCost,
            )).period
          : period;
      final resolved = _withSavingsDecisionResolved(advanced);
      final updatedPeriod = resolved.copyWith(
        actualSavings: resolved.actualSavings + amount,
      );
      await _writePeriod(txn, updatedPeriod);
      final updated = state.copyWith(
        walletBalance: state.walletBalance - amount,
        savedAmount: state.savedAmount + amount,
        updatedAt: transaction.createdAt,
      );
      await _writeState(txn, updated);
      return updated;
    });
  }

  @override
  Future<GamePeriod> skipSavingsDecision({
    required int profileId,
    required int periodId,
  }) async {
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final period = await _requirePeriod(txn, profileId, periodId);
      final state = await _requireValidSavingsState(txn, profileId);
      if (state.activeGoalId == null) {
        throw const SavingsGoalRequiredException();
      }
      if (period.actualSavings > 0) {
        throw const SavingsDecisionAlreadyMadeException();
      }
      if (period.resolvedCheckpoints.contains('savings_decision')) {
        return period;
      }
      if (period.status != GamePeriodStatus.active) {
        throw const SavingsPeriodNotAvailableException();
      }
      final advanced = await _applyVirtualDayAction(
        txn,
        period: period,
        timeCost: VirtualDayRules.savingsDecisionCost,
      );
      final updated = _withSavingsDecisionResolved(advanced.period);
      await _writePeriod(txn, updated);
      return updated;
    });
  }

  @override
  Future<GamePeriod> resolveSavingsDecisionForCompletedGoals({
    required int profileId,
    required int periodId,
    required Set<String> canonicalGoalIds,
  }) async {
    if (canonicalGoalIds.isEmpty) {
      throw const FormatException('Savings goals must not be empty.');
    }
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final period = await _requirePeriod(txn, profileId, periodId);
      final state = await _requireValidSavingsState(txn, profileId);
      if (state.activeGoalId != null) {
        throw SavingsGoalAlreadyActiveException(
          activeGoalId: state.activeGoalId!,
        );
      }
      final rows = await txn.query(
        'completed_goals',
        columns: ['goal_id'],
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      final completed = rows.map((row) => row['goal_id']! as String).toSet();
      if (!completed.containsAll(canonicalGoalIds)) {
        throw const SavingsAllGoalsNotCompletedException();
      }
      if (period.resolvedCheckpoints.contains('savings_decision')) {
        return period;
      }
      if (period.status != GamePeriodStatus.active) {
        throw const SavingsPeriodNotAvailableException();
      }
      final advanced = await _applyVirtualDayAction(
        txn,
        period: period,
        timeCost: VirtualDayRules.savingsDecisionCost,
      );
      final updated = _withSavingsDecisionResolved(advanced.period);
      await _writePeriod(txn, updated);
      return updated;
    });
  }

  @override
  Future<GameState> claimSavingsGoal({
    required int profileId,
    required SavingsGoal goal,
    required String operationId,
  }) async {
    _validateOperationId(operationId);
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final replayRows = await txn.query(
        'completed_goals',
        where: 'profile_id = ? AND claim_operation_id = ?',
        whereArgs: [profileId, operationId],
        limit: 1,
      );
      if (replayRows.isNotEmpty) {
        final completed = CompletedGoal.fromMap(replayRows.single);
        if (completed.goalId != goal.id ||
            completed.pricePaid != goal.price ||
            completed.rewardAssetId != goal.rewardAssetId) {
          throw SavingsOperationConflictException(operationId: operationId);
        }
        return _requireState(txn, profileId);
      }
      final state = await _requireValidSavingsState(txn, profileId);
      if (await _isGoalCompleted(txn, profileId, goal.id)) {
        throw SavingsGoalAlreadyCompletedException(goal.id);
      }
      if (state.activeGoalId != goal.id) {
        throw SavingsGoalMismatchException(
          expectedGoalId: goal.id,
          actualGoalId: state.activeGoalId,
        );
      }
      if (state.savedAmount < goal.price) {
        throw SavingsGoalNotReachedException(
          goalId: goal.id,
          goalPrice: goal.price,
          savedAmount: state.savedAmount,
        );
      }
      if (await _readInventoryQuantity(txn, profileId, goal.rewardAssetId) >
          0) {
        throw SavingsRewardAlreadyOwnedException(goal.rewardAssetId);
      }
      final now = DateTime.now().toUtc();
      await txn.insert(
        'completed_goals',
        CompletedGoal(
          profileId: profileId,
          goalId: goal.id,
          rewardAssetId: goal.rewardAssetId,
          pricePaid: goal.price,
          completedAt: now,
          claimOperationId: operationId,
        ).toMap(),
      );
      await txn.insert('inventory', {
        'profile_id': profileId,
        'item_id': goal.rewardAssetId,
        'quantity': 1,
        'acquired_at': now.toIso8601String(),
      });
      final updated = state.copyWith(
        clearActiveGoal: true,
        savedAmount: state.savedAmount - goal.price,
        goalChangeUsed: false,
        updatedAt: now,
      );
      await _writeState(txn, updated);
      return updated;
    });
  }

  @override
  Future<int> getInventoryQuantity(int profileId, String itemId) async {
    final db = await _appDatabase.database;
    return _readInventoryQuantity(db, profileId, itemId);
  }

  @override
  Future<List<GameTransaction>> getTransactions(
    int profileId, {
    int? periodId,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'transactions',
      where: periodId == null
          ? 'profile_id = ?'
          : 'profile_id = ? AND period_id = ?',
      whereArgs: periodId == null ? [profileId] : [profileId, periodId],
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(GameTransaction.fromMap).toList(growable: false);
  }

  @override
  Future<void> clearDemoRuntimeData(int profileId) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final profiles = await txn.query(
        'profiles',
        columns: ['profile_type'],
        where: 'id = ?',
        whereArgs: [profileId],
        limit: 1,
      );
      if (profiles.isEmpty) {
        throw StateError('Profile $profileId does not exist.');
      }
      if (profiles.single['profile_type'] != 'DEMO') {
        throw StateError('Only DEMO runtime data can be reset.');
      }
      for (final table in [
        'task_progress',
        'pet_action_operations',
        'pet_daily_usage',
        'inventory',
        'transactions',
        'game_periods',
        'completed_goals',
        'pets',
        'game_states',
      ]) {
        await txn.delete(
          table,
          where: 'profile_id = ?',
          whereArgs: [profileId],
        );
      }
    });
  }

  Future<GameState> _applyWalletTransaction(
    DatabaseExecutor db,
    GameTransaction transaction,
  ) async {
    final state = await _requireState(db, transaction.profileId);
    final nextBalance = state.walletBalance + transaction.amount;
    if (nextBalance < 0) {
      throw StateError('Wallet balance cannot become negative.');
    }
    try {
      await db.insert('transactions', transaction.toMap());
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw StateError('This transaction has already been recorded.');
      }
      rethrow;
    }
    final updated = state.copyWith(
      walletBalance: nextBalance,
      updatedAt: transaction.createdAt,
    );
    await _writeState(db, updated);
    if (transaction.periodId != null) {
      final period = await _requirePeriod(
        db,
        transaction.profileId,
        transaction.periodId!,
      );
      final aggregated = switch (transaction.type) {
        GameTransactionType.needExpense => period.copyWith(
          actualNeed: period.actualNeed - transaction.amount,
        ),
        GameTransactionType.wantExpense => period.copyWith(
          actualWant: period.actualWant - transaction.amount,
        ),
        GameTransactionType.otherIncome || GameTransactionType.taskReward =>
          period.copyWith(extraIncome: period.extraIncome + transaction.amount),
        _ => period,
      };
      if (!identical(aggregated, period)) await _writePeriod(db, aggregated);
    }
    return updated;
  }

  Future<bool> _isGoalCompleted(
    DatabaseExecutor db,
    int profileId,
    String goalId,
  ) async {
    final rows = await db.query(
      'completed_goals',
      columns: ['goal_id'],
      where: 'profile_id = ? AND goal_id = ?',
      whereArgs: [profileId, goalId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<GameState> _requireValidSavingsState(
    DatabaseExecutor db,
    int profileId,
  ) async {
    final state = await _requireState(db, profileId);
    if (state.activeGoalId == null && state.goalChangeUsed) {
      throw StateError('goalChangeUsed cannot be true without an active goal.');
    }
    if (state.savedAmount < 0) {
      throw StateError('savedAmount cannot be negative.');
    }
    return state;
  }

  GamePeriod _withSavingsDecisionResolved(GamePeriod period) {
    if (!period.requiredCheckpoints.contains('savings_decision')) {
      throw StateError('The period does not require a savings decision.');
    }
    if (period.resolvedCheckpoints.contains('savings_decision')) return period;
    final resolved = [
      for (final checkpoint in period.requiredCheckpoints)
        if (checkpoint == 'savings_decision' ||
            period.resolvedCheckpoints.contains(checkpoint))
          checkpoint,
    ];
    return period.copyWith(
      resolvedCheckpoints: List.unmodifiable(resolved),
      status: resolved.length == period.requiredCheckpoints.length
          ? GamePeriodStatus.readyToFinish
          : GamePeriodStatus.active,
    );
  }

  void _requireSameSavingsCommand(
    GameTransaction existing,
    GameTransaction requested,
    String operationId,
  ) {
    try {
      _requireSameCommand(existing, requested);
    } on StateError {
      throw SavingsOperationConflictException(operationId: operationId);
    }
  }

  Future<GameState?> _readState(DatabaseExecutor db, int profileId) async {
    final rows = await db.query(
      'game_states',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    return rows.isEmpty ? null : GameState.fromMap(rows.single);
  }

  Future<Pet> _requirePet(DatabaseExecutor db, int profileId) async {
    final pet = await _readPet(db, profileId);
    if (pet == null) {
      throw StateError('Pet for profile $profileId is missing.');
    }
    return pet;
  }

  Future<Pet?> _readPet(DatabaseExecutor db, int profileId) async {
    final rows = await db.query(
      'pets',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    return rows.isEmpty ? null : Pet.fromMap(rows.single);
  }

  Future<({GamePeriod period, Pet? pet})> _applyVirtualDayAction(
    DatabaseExecutor db, {
    required GamePeriod period,
    required int timeCost,
    PetStatEffects effects = const PetStatEffects(),
    Pet? pet,
  }) async {
    final currentPet = pet ?? await _readPet(db, period.profileId);
    if (currentPet == null) {
      if (!effects.isEmpty) {
        throw StateError('Pet for profile ${period.profileId} is missing.');
      }
      final updatedPeriod = period.copyWith(
        dayProgress: VirtualDayRules.clampProgress(
          period.dayProgress + timeCost,
        ),
      );
      await _writePeriod(db, updatedPeriod);
      return (period: updatedPeriod, pet: null);
    }
    final transition = VirtualDayRules.applyAction(
      pet: currentPet,
      oldProgress: period.dayProgress,
      timeCost: timeCost,
      satietyEffect: effects.satiety,
      careEffect: effects.care,
      moodEffect: effects.mood,
    );
    final updatedPeriod = period.copyWith(dayProgress: transition.progress);
    await _writePet(db, transition.pet);
    await _writePeriod(db, updatedPeriod);
    return (period: updatedPeriod, pet: transition.pet);
  }

  Future<void> _ensureStarterToothbrush(
    DatabaseExecutor db,
    int profileId,
  ) async {
    await db.insert('inventory', {
      'profile_id': profileId,
      'item_id': 'care_toothbrush',
      'quantity': 1,
      'acquired_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _writePet(DatabaseExecutor db, Pet pet) async {
    _validatePet(pet);
    final count = await db.update(
      'pets',
      pet.toMap()..remove('profile_id'),
      where: 'profile_id = ?',
      whereArgs: [pet.profileId],
    );
    if (count != 1) {
      throw StateError('Pet for profile ${pet.profileId} is missing.');
    }
  }

  Future<int> _readInventoryQuantity(
    DatabaseExecutor db,
    int profileId,
    String itemId,
  ) async {
    final rows = await db.query(
      'inventory',
      columns: ['quantity'],
      where: 'profile_id = ? AND item_id = ?',
      whereArgs: [profileId, itemId],
      limit: 1,
    );
    return rows.isEmpty ? 0 : rows.single['quantity'] as int;
  }

  Future<Map<String, Object?>?> _readPetActionOperation(
    DatabaseExecutor db, {
    required int profileId,
    required String operationId,
  }) async {
    final rows = await db.query(
      'pet_action_operations',
      where: 'profile_id = ? AND operation_id = ?',
      whereArgs: [profileId, operationId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<int> _readPetDailyUsageCount(
    DatabaseExecutor db, {
    required int profileId,
    required int periodId,
    required String actionId,
    required PetActionSlot slot,
  }) async {
    final rows = await db.query(
      'pet_daily_usage',
      columns: ['usage_count'],
      where: 'profile_id = ? AND period_id = ? AND action_id = ? AND usage_slot = ?',
      whereArgs: [profileId, periodId, actionId, slot.storageValue],
      limit: 1,
    );
    return rows.isEmpty ? 0 : rows.single['usage_count'] as int;
  }

  Future<void> _incrementPetDailyUsage(
    DatabaseExecutor db, {
    required int profileId,
    required int periodId,
    required String actionId,
    required PetActionSlot slot,
    required String updatedAt,
  }) async {
    await db.rawInsert(
      '''
      INSERT INTO pet_daily_usage (
        profile_id, period_id, action_id, usage_slot, usage_count, updated_at
      ) VALUES (?, ?, ?, ?, 1, ?)
      ON CONFLICT(profile_id, period_id, action_id, usage_slot) DO UPDATE SET
        usage_count = usage_count + 1,
        updated_at = excluded.updated_at
      ''',
      [profileId, periodId, actionId, slot.storageValue, updatedAt],
    );
  }

  Future<GameState> _requireState(DatabaseExecutor db, int profileId) async {
    final state = await _readState(db, profileId);
    if (state == null) {
      throw StateError('Game state for profile $profileId is missing.');
    }
    return state;
  }

  Future<void> _writeState(DatabaseExecutor db, GameState state) async {
    final count = await db.update(
      'game_states',
      state.toMap()..remove('profile_id'),
      where: 'profile_id = ?',
      whereArgs: [state.profileId],
    );
    if (count != 1) {
      throw StateError('Game state for profile ${state.profileId} is missing.');
    }
  }

  Future<GamePeriod?> _readPeriodById(
    DatabaseExecutor db,
    int profileId,
    int periodId,
  ) async {
    final rows = await db.query(
      'game_periods',
      where: 'id = ? AND profile_id = ?',
      whereArgs: [periodId, profileId],
      limit: 1,
    );
    return rows.isEmpty ? null : GamePeriod.fromMap(rows.single);
  }

  Future<GamePeriod> _requirePeriod(
    DatabaseExecutor db,
    int profileId,
    int periodId,
  ) async {
    final period = await _readPeriodById(db, profileId, periodId);
    if (period == null) {
      throw StateError(
        'Period $periodId does not exist for profile $profileId.',
      );
    }
    return period;
  }

  Future<void> _writePeriod(DatabaseExecutor db, GamePeriod period) async {
    final id = period.id;
    if (id == null) {
      throw ArgumentError('Cannot update a period without an id.');
    }
    final count = await db.update(
      'game_periods',
      period.toMap()..remove('id'),
      where: 'id = ? AND profile_id = ?',
      whereArgs: [id, period.profileId],
    );
    if (count != 1) throw StateError('Game period $id does not exist.');
  }

  Future<GameTransaction?> _readTransactionByKey(
    DatabaseExecutor db,
    int profileId,
    String key,
  ) async {
    final rows = await db.query(
      'transactions',
      where: 'profile_id = ? AND deduplication_key = ?',
      whereArgs: [profileId, key],
      limit: 1,
    );
    return rows.isEmpty ? null : GameTransaction.fromMap(rows.single);
  }

  void _requireSameCommand(
    GameTransaction existing,
    GameTransaction requested,
  ) {
    if (existing.periodId != requested.periodId ||
        existing.type != requested.type ||
        existing.amount != requested.amount ||
        existing.source != requested.source ||
        existing.description != requested.description) {
      throw StateError(
        'The operationId is already used by a different financial command.',
      );
    }
  }

  void _requireFinancialActionsAllowed(GamePeriod period) {
    if (period.status != GamePeriodStatus.active &&
        period.status != GamePeriodStatus.readyToFinish) {
      throw StateError(
        'Financial actions require an active or ready-to-finish period.',
      );
    }
  }

  void _requirePetActionsAllowed(GamePeriod period) {
    if (period.status != GamePeriodStatus.active &&
        period.status != GamePeriodStatus.readyToFinish) {
      throw StateError(
        'Pet actions require an active or ready-to-finish period.',
      );
    }
  }

  void _requireValidPetActionSlot({
    required GamePeriod period,
    required String actionId,
    required ItemUsagePolicy policy,
    required PetActionSlot slot,
  }) {
    if (policy == ItemUsagePolicy.none) {
      throw PetItemNotUsableException(actionId.replaceFirst('item:', ''));
    }
    if (policy == ItemUsagePolicy.toothbrush) {
      final available = switch (slot) {
        PetActionSlot.morning => VirtualDayRules.morningToothbrushAvailable(
          period.dayProgress,
        ),
        PetActionSlot.evening => VirtualDayRules.eveningToothbrushAvailable(
          period.dayProgress,
        ),
        PetActionSlot.defaultSlot => false,
      };
      if (!available) {
        throw PetActionSlotUnavailableException(actionId: actionId, slot: slot);
      }
      return;
    }
    if (slot != PetActionSlot.defaultSlot) {
      throw PetActionSlotUnavailableException(actionId: actionId, slot: slot);
    }
  }

  void _validateNewTransaction(GameTransaction transaction) {
    if (transaction.id != null) {
      throw ArgumentError('A new transaction must not already have an id.');
    }
    if (transaction.amount == 0) {
      throw ArgumentError.value(
        transaction.amount,
        'transaction.amount',
        'Must be non-zero.',
      );
    }
  }

  void _validateOperationId(String operationId) {
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'Must not be empty.',
      );
    }
  }

  void _validatePet(Pet pet) {
    if (pet.profileId <= 0 ||
        pet.satiety < 0 ||
        pet.satiety > PetStateRules.maxValue ||
        pet.care < 0 ||
        pet.care > PetStateRules.maxValue ||
        pet.mood < 0 ||
        pet.mood > PetStateRules.maxValue) {
      throw ArgumentError('Pet identity or state is invalid.');
    }
  }
}

class SqlitePetActionPort implements PetActionPort {
  SqlitePetActionPort(AppDatabase database)
    : _core = SqliteGameRepository(database);

  final SqliteGameRepository _core;

  @override
  Future<Pet> useItem({
    required int profileId,
    required int periodId,
    required ShopItem item,
    required String operationId,
    required PetActionSlot slot,
  }) => _core._applyPetAction(
    profileId: profileId,
    periodId: periodId,
    actionId: 'item:${item.id}',
    operationId: operationId,
    slot: slot,
    effects: item.petEffects,
    item: item,
  );

  @override
  Future<Pet> performFreePetInteraction({
    required int profileId,
    required int periodId,
    required FreePetInteraction interaction,
    required String operationId,
  }) => _core._applyPetAction(
    profileId: profileId,
    periodId: periodId,
    actionId: interaction.actionId,
    operationId: operationId,
    slot: PetActionSlot.defaultSlot,
    effects: interaction.effects,
  );
}

class SqliteDayLifecyclePort implements DayLifecyclePort {
  SqliteDayLifecyclePort(AppDatabase database)
    : _database = database,
      _core = SqliteGameRepository(database);

  final AppDatabase _database;
  final SqliteGameRepository _core;

  @override
  Future<BedtimeDecision> evaluateBedtime({
    required int profileId,
    required int periodId,
    required List<ShopItem> canonicalItems,
  }) async {
    final db = await _database.database;
    return _evaluate(
      db,
      profileId: profileId,
      periodId: periodId,
      canonicalItems: canonicalItems,
    );
  }

  @override
  Future<DayCompletionResult> sleep({
    required int profileId,
    required int periodId,
    required bool allowFallback,
    required List<ShopItem> canonicalItems,
  }) async {
    final db = await _database.database;
    return db.transaction((txn) async {
      final decision = await _evaluate(
        txn,
        profileId: profileId,
        periodId: periodId,
        canonicalItems: canonicalItems,
      );
      final permitted =
          decision.type == BedtimeDecisionType.ready ||
          allowFallback && decision.type == BedtimeDecisionType.fallbackAllowed;
      if (!permitted) throw BedtimeNotAllowedException(decision);

      final period = await _core._requirePeriod(txn, profileId, periodId);
      final state = await _core._requireState(txn, profileId);
      final pet = await _core._requirePet(txn, profileId);
      final targetStage = switch (period.periodNumber) {
        >= 5 => 3,
        >= 2 => 2,
        _ => 1,
      };
      final grownPet = pet.copyWith(
        developmentStage: pet.developmentStage < targetStage
            ? targetStage
            : pet.developmentStage,
      );
      final completed = period.copyWith(
        endWalletBalance: state.walletBalance,
        status: GamePeriodStatus.completed,
        completedAt: DateTime.now().toUtc(),
      );
      await _core._writePet(txn, grownPet);
      await _core._writePeriod(txn, completed);
      return DayCompletionResult(period: completed, pet: grownPet);
    });
  }

  Future<BedtimeDecision> _evaluate(
    DatabaseExecutor db, {
    required int profileId,
    required int periodId,
    required List<ShopItem> canonicalItems,
  }) async {
    final period = await _core._requirePeriod(db, profileId, periodId);
    if (period.status == GamePeriodStatus.planning ||
        period.status == GamePeriodStatus.completed) {
      throw StateError('Bedtime requires an active period.');
    }
    if (!VirtualDayRules.bedtimeReached(period.dayProgress)) {
      return const BedtimeDecision(type: BedtimeDecisionType.tooEarly);
    }
    final unresolved = period.requiredCheckpoints
        .where((checkpoint) => !period.resolvedCheckpoints.contains(checkpoint))
        .toList(growable: false);
    if (unresolved.isNotEmpty) {
      return BedtimeDecision(
        type: BedtimeDecisionType.blockedByCheckpoints,
        unresolvedCheckpoints: List.unmodifiable(unresolved),
      );
    }

    final pet = await _core._requirePet(db, profileId);
    final statsNeedingCare = <PetStat>{
      if (pet.satiety < PetStateRules.greenThreshold) PetStat.satiety,
      if (pet.care < PetStateRules.greenThreshold) PetStat.care,
      if (pet.mood < PetStateRules.greenThreshold) PetStat.mood,
    };
    if (statsNeedingCare.isEmpty) {
      return const BedtimeDecision(type: BedtimeDecisionType.ready);
    }
    final state = await _core._requireState(db, profileId);
    final possible = await _canReachGreen(
      db,
      profileId: profileId,
      periodId: periodId,
      pet: pet,
      dayProgress: period.dayProgress,
      wallet: state.walletBalance,
      canonicalItems: canonicalItems,
    );
    return BedtimeDecision(
      type: possible
          ? BedtimeDecisionType.carePossible
          : BedtimeDecisionType.fallbackAllowed,
      statsNeedingCare: Set.unmodifiable(statsNeedingCare),
    );
  }

  Future<bool> _canReachGreen(
    DatabaseExecutor db, {
    required int profileId,
    required int periodId,
    required Pet pet,
    required int dayProgress,
    required int wallet,
    required List<ShopItem> canonicalItems,
  }) async {
    final fixedActions = <_CareAction>[];
    final repeatableActions = <_CareAction>[];
    void addFixed(
      PetStatEffects effects,
      _CareActionKind kind, {
      required int price,
    }) {
      fixedActions.add(
        _CareAction(
          effects: effects,
          kind: kind,
          price: price,
          fixedIndex: fixedActions.length,
        ),
      );
    }

    final pettingUsed = await _core._readPetDailyUsageCount(
      db,
      profileId: profileId,
      periodId: periodId,
      actionId: FreePetInteraction.pet.actionId,
      slot: PetActionSlot.defaultSlot,
    );
    if (pettingUsed == 0) {
      addFixed(
        FreePetInteraction.pet.effects,
        _CareActionKind.petting,
        price: 0,
      );
    }

    for (final item in canonicalItems) {
      if (item.usagePolicy == ItemUsagePolicy.none || item.petEffects.isEmpty) {
        continue;
      }
      final kind = switch ((item.displaySection, item.usagePolicy)) {
        (_, ItemUsagePolicy.toothbrush) => _CareActionKind.toothbrush,
        (ShopDisplaySection.food, _) => _CareActionKind.food,
        (ShopDisplaySection.care, _) => _CareActionKind.care,
        _ => _CareActionKind.other,
      };
      final quantity = await _core._readInventoryQuantity(
        db,
        profileId,
        item.id,
      );
      if (item.persistent) {
        final slot = item.usagePolicy == ItemUsagePolicy.toothbrush
            ? PetActionSlot.evening
            : PetActionSlot.defaultSlot;
        final used = await _core._readPetDailyUsageCount(
          db,
          profileId: profileId,
          periodId: periodId,
          actionId: 'item:${item.id}',
          slot: slot,
        );
        if (used == 0) {
          addFixed(item.petEffects, kind, price: quantity > 0 ? 0 : item.price);
        }
      } else {
        final usefulQuantity = _usefulConsumableQuantity(item.petEffects);
        for (
          var count = 0;
          count < quantity.clamp(0, usefulQuantity);
          count++
        ) {
          addFixed(item.petEffects, kind, price: 0);
        }
        repeatableActions.add(
          _CareAction(effects: item.petEffects, kind: kind, price: item.price),
        );
      }
    }
    final foodUses = await _core._readPetDailyUsageCount(
      db,
      profileId: profileId,
      periodId: periodId,
      actionId: 'time:feeding',
      slot: PetActionSlot.defaultSlot,
    );
    final careUses = await _core._readPetDailyUsageCount(
      db,
      profileId: profileId,
      periodId: periodId,
      actionId: 'time:care',
      slot: PetActionSlot.defaultSlot,
    );
    final initial = _CareSearchState(
      satiety: pet.satiety,
      care: pet.care,
      mood: pet.mood,
      progress: dayProgress,
      foodTimeUses: foodUses.clamp(0, VirtualDayRules.feedingTimeLimit),
      careTimeUses: careUses.clamp(0, VirtualDayRules.careTimeLimit),
      usedMask: 0,
    );
    if (initial.isGreen) return true;

    final queue = ListQueue<({_CareSearchState state, int cost})>()
      ..add((state: initial, cost: 0));
    final bestCost = <String, int>{initial.key: 0};
    final actions = [...fixedActions, ...repeatableActions];
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (bestCost[current.state.key] != current.cost) continue;
      for (final action in actions) {
        if (action.fixedIndex case final index?
            when current.state.usedMask & (1 << index) != 0) {
          continue;
        }
        final nextCost = current.cost + action.price;
        if (nextCost > wallet) continue;
        final next = current.state.apply(action, pet);
        if (next.key == current.state.key) continue;
        if (next.isGreen) return true;
        final known = bestCost[next.key];
        if (known != null && known <= nextCost) continue;
        bestCost[next.key] = nextCost;
        queue.add((state: next, cost: nextCost));
      }
    }
    return false;
  }

  int _usefulConsumableQuantity(PetStatEffects effects) {
    var maximum = 1;
    for (final effect in [effects.satiety, effects.care, effects.mood]) {
      if (effect > 0) {
        final uses = (PetStateRules.maxValue + effect - 1) ~/ effect;
        if (uses > maximum) maximum = uses;
      }
    }
    return maximum + 1;
  }
}

enum _CareActionKind { food, toothbrush, care, petting, other }

class _CareAction {
  const _CareAction({
    required this.effects,
    required this.kind,
    required this.price,
    this.fixedIndex,
  });

  final PetStatEffects effects;
  final _CareActionKind kind;
  final int price;
  final int? fixedIndex;
}

class _CareSearchState {
  const _CareSearchState({
    required this.satiety,
    required this.care,
    required this.mood,
    required this.progress,
    required this.foodTimeUses,
    required this.careTimeUses,
    required this.usedMask,
  });

  final int satiety;
  final int care;
  final int mood;
  final int progress;
  final int foodTimeUses;
  final int careTimeUses;
  final int usedMask;

  bool get isGreen =>
      satiety >= PetStateRules.greenThreshold &&
      care >= PetStateRules.greenThreshold &&
      mood >= PetStateRules.greenThreshold;

  String get key =>
      '$satiety:$care:$mood:$progress:$foodTimeUses:$careTimeUses:$usedMask';

  _CareSearchState apply(_CareAction action, Pet template) {
    var timeCost = 0;
    var nextFoodUses = foodTimeUses;
    var nextCareUses = careTimeUses;
    switch (action.kind) {
      case _CareActionKind.food:
        if (foodTimeUses < VirtualDayRules.feedingTimeLimit) {
          timeCost = VirtualDayRules.feedingCost;
          nextFoodUses++;
        }
        break;
      case _CareActionKind.toothbrush:
        timeCost = VirtualDayRules.toothbrushCost;
        break;
      case _CareActionKind.care:
        if (careTimeUses < VirtualDayRules.careTimeLimit) {
          timeCost = VirtualDayRules.careCost;
          nextCareUses++;
        }
        break;
      case _CareActionKind.petting:
        timeCost = VirtualDayRules.pettingCost;
        break;
      case _CareActionKind.other:
        break;
    }
    final transition = VirtualDayRules.applyAction(
      pet: template.copyWith(satiety: satiety, care: care, mood: mood),
      oldProgress: progress,
      timeCost: timeCost,
      satietyEffect: action.effects.satiety,
      careEffect: action.effects.care,
      moodEffect: action.effects.mood,
    );
    return _CareSearchState(
      satiety: transition.pet.satiety,
      care: transition.pet.care,
      mood: transition.pet.mood,
      progress: transition.progress,
      foodTimeUses: nextFoodUses,
      careTimeUses: nextCareUses,
      usedMask: action.fixedIndex == null
          ? usedMask
          : usedMask | (1 << action.fixedIndex!),
    );
  }
}

class SqliteTaskCompletionPort implements TaskCompletionPort {
  SqliteTaskCompletionPort(AppDatabase database)
    : _appDatabase = database,
      _core = SqliteGameRepository(database);

  final AppDatabase _appDatabase;
  final SqliteGameRepository _core;

  @override
  Future<TaskSubmissionResult> submitFinancialTaskAnswer({
    required int profileId,
    required int periodId,
    required FinancialTask task,
    required String answerId,
  }) async {
    task.validate();
    if (profileId <= 0 ||
        periodId <= 0 ||
        !task.choiceScenario.options.any((option) => option.id == answerId)) {
      throw ArgumentError('Invalid financial task submission.');
    }
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final period = await _core._requirePeriod(txn, profileId, periodId);
      if (task.period != period.periodNumber) {
        throw StateError('Task ${task.id} does not belong to this period.');
      }
      if (task.requiredForCheckpoint &&
          !period.requiredCheckpoints.contains('financial_task')) {
        throw StateError('This period does not require a financial task.');
      }

      final rewardKey = 'task_reward_${periodId}_${task.id}';
      final rewardSource = 'task_reward_${task.id}';
      TaskProgress? progress;
      try {
        progress = await _core._readTaskProgress(txn, profileId, task.id);
      } on FormatException catch (error) {
        throw TaskIntegrityException('Invalid task progress: $error');
      }
      final rewardRows = await txn.query(
        'transactions',
        where: 'profile_id = ? AND (source = ? OR deduplication_key = ?)',
        whereArgs: [profileId, rewardSource, rewardKey],
      );
      final checkpointResolved = period.resolvedCheckpoints.contains(
        'financial_task',
      );
      final hasCompletionProof = progress != null || rewardRows.isNotEmpty;
      if (hasCompletionProof ||
          (task.requiredForCheckpoint && checkpointResolved)) {
        if (progress == null ||
            progress.status != TaskProgressStatus.completed ||
            !progress.rewardClaimed ||
            progress.scenarioState['answerId'] !=
                task.choiceScenario.correctOptionId ||
            (task.requiredForCheckpoint && !checkpointResolved) ||
            rewardRows.length != 1) {
          throw const TaskIntegrityException(
            'Task completion is inconsistent.',
          );
        }
        final reward = GameTransaction.fromMap(rewardRows.single);
        if (reward.profileId != profileId ||
            reward.periodId != periodId ||
            reward.type != GameTransactionType.taskReward ||
            reward.amount != task.reward ||
            reward.source != rewardSource ||
            reward.deduplicationKey != rewardKey) {
          throw const TaskIntegrityException('Task reward is inconsistent.');
        }
        return TaskAnswerCompleted(
          explanation: task.choiceScenario.explanation,
          canonicalReward: task.reward,
          rewardAppliedNow: false,
          wasAlreadyCompleted: true,
          gameState: await _core._requireState(txn, profileId),
          period: period,
        );
      }
      final canComplete = task.requiredForCheckpoint
          ? period.status == GamePeriodStatus.active
          : period.status == GamePeriodStatus.active ||
                period.status == GamePeriodStatus.readyToFinish;
      if (!canComplete) {
        throw StateError('New task completion is unavailable for this period.');
      }
      if (answerId != task.choiceScenario.correctOptionId) {
        return TaskAnswerIncorrect(
          explanation: task.choiceScenario.explanation,
        );
      }

      final now = DateTime.now().toUtc();
      final state = await _core._applyWalletTransaction(
        txn,
        GameTransaction(
          profileId: profileId,
          periodId: periodId,
          type: GameTransactionType.taskReward,
          amount: task.reward,
          source: rewardSource,
          description: 'Награда за задание: ${task.title}',
          createdAt: now,
          deduplicationKey: rewardKey,
        ),
      );
      await txn.insert(
        'task_progress',
        TaskProgress(
          profileId: profileId,
          taskId: task.id,
          status: TaskProgressStatus.completed,
          rewardClaimed: true,
          scenarioState: {'answerId': task.choiceScenario.correctOptionId},
          updatedAt: now,
        ).toMap(),
      );
      final afterReward = await _core._requirePeriod(txn, profileId, periodId);
      final afterTime = task.requiredForCheckpoint
          ? (await _core._applyVirtualDayAction(
              txn,
              period: afterReward,
              timeCost: VirtualDayRules.requiredTaskCost,
            )).period
          : afterReward;
      final resolved = task.requiredForCheckpoint
          ? await _core._resolveCheckpointInTransaction(
              txn,
              afterTime,
              'financial_task',
            )
          : afterTime;
      return TaskAnswerCompleted(
        explanation: task.choiceScenario.explanation,
        canonicalReward: task.reward,
        rewardAppliedNow: true,
        wasAlreadyCompleted: false,
        gameState: state,
        period: resolved,
      );
    });
  }
}

class SqlitePurchasePort implements PurchasePort {
  SqlitePurchasePort(AppDatabase database)
    : _database = database,
      _core = SqliteGameRepository(database);

  final AppDatabase _database;
  final SqliteGameRepository _core;

  @override
  Future<GameState> purchase({
    required int profileId,
    required int periodId,
    required ShopItem item,
    required String operationId,
  }) async {
    _core._validateOperationId(operationId);
    if (item.price <= 0) {
      throw ArgumentError.value(item.price, 'item.price', 'Must be positive.');
    }
    final now = DateTime.now().toUtc();
    final transaction = GameTransaction(
      profileId: profileId,
      periodId: periodId,
      type: item.category == ShopItemCategory.need
          ? GameTransactionType.needExpense
          : GameTransactionType.wantExpense,
      amount: -item.price,
      source: 'purchase_${item.id}',
      description: 'Покупка: ${item.name}',
      createdAt: now,
      deduplicationKey: 'operation:$operationId',
    );
    final db = await _database.database;
    return db.transaction((txn) async {
      final period = await _core._requirePeriod(txn, profileId, periodId);
      final existing = await _core._readTransactionByKey(
        txn,
        profileId,
        transaction.deduplicationKey!,
      );
      if (existing != null) {
        _core._requireSameCommand(existing, transaction);
        return _core._requireState(txn, profileId);
      }
      _core._requireFinancialActionsAllowed(period);
      if (item.persistent &&
          await _core._readInventoryQuantity(txn, profileId, item.id) > 0) {
        throw PersistentItemAlreadyOwnedException(itemId: item.id);
      }
      final state = await _core._requireState(txn, profileId);
      if (state.walletBalance < item.price) {
        throw InsufficientFundsException(
          itemPrice: item.price,
          availableBalance: state.walletBalance,
        );
      }
      final updated = await _core._applyWalletTransaction(txn, transaction);
      await txn.rawInsert(
        '''
        INSERT INTO inventory (profile_id, item_id, quantity, acquired_at)
        VALUES (?, ?, 1, ?)
        ON CONFLICT(profile_id, item_id) DO UPDATE SET
          quantity = quantity + 1,
          acquired_at = excluded.acquired_at
      ''',
        [profileId, item.id, now.toIso8601String()],
      );
      return updated;
    });
  }
}

class SqliteSpecialPurchasePort implements SpecialPurchasePort {
  SqliteSpecialPurchasePort(AppDatabase database)
    : _database = database,
      _core = SqliteGameRepository(database);

  final AppDatabase _database;
  final SqliteGameRepository _core;

  Future<Map<String, Object?>?> _proof(
    DatabaseExecutor txn,
    int profileId,
    String where,
    List<Object?> args,
  ) async {
    final rows = await txn.query(
      'period_special_actions',
      where: 'profile_id = ? AND $where',
      whereArgs: [profileId, ...args],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<bool> _replayOrReject(
    DatabaseExecutor txn, {
    required int profileId,
    required int periodId,
    required String actionId,
    required String outcome,
    required String operationId,
    required String checkpoint,
    required GamePeriod period,
    required String transactionSource,
    required int transactionAmount,
    required String transactionType,
  }) async {
    final existingOperation = await _proof(txn, profileId, 'operation_id = ?', [
      operationId,
    ]);
    if (existingOperation != null) {
      if (existingOperation['period_id'] != periodId ||
          existingOperation['action_id'] != actionId ||
          existingOperation['outcome'] != outcome) {
        throw SpecialPurchaseConflictException(operationId);
      }
      if (!period.resolvedCheckpoints.contains(checkpoint)) {
        throw StateError('Special purchase proof has no checkpoint.');
      }
      final transaction = await _core._readTransactionByKey(
        txn,
        profileId,
        'special:$operationId',
      );
      if (outcome == 'skipped') {
        if (transaction != null) {
          throw SpecialPurchaseConflictException(operationId);
        }
      } else if (transaction == null ||
          transaction.periodId != periodId ||
          transaction.source != transactionSource ||
          transaction.amount != transactionAmount ||
          transaction.type != transactionType) {
        throw SpecialPurchaseConflictException(operationId);
      }
      return true;
    }
    if (await _proof(txn, profileId, 'period_id = ? AND action_id = ?', [
          periodId,
          actionId,
        ]) !=
        null) {
      throw SpecialPurchaseAlreadyDecidedException(actionId);
    }
    if (period.resolvedCheckpoints.contains(checkpoint)) {
      throw StateError('Special checkpoint has no durable proof.');
    }
    return false;
  }

  Future<void> _writeProof(
    DatabaseExecutor txn, {
    required int profileId,
    required int periodId,
    required String actionId,
    required String outcome,
    required String operationId,
    required DateTime now,
  }) async {
    await txn.insert('period_special_actions', {
      'profile_id': profileId,
      'period_id': periodId,
      'action_id': actionId,
      'outcome': outcome,
      'operation_id': operationId,
      'created_at': now.toIso8601String(),
    });
  }

  @override
  Future<GameState> purchaseStory({
    required int profileId,
    required int periodId,
    required StoryPurchase story,
    required String operationId,
  }) async {
    _core._validateOperationId(operationId);
    final db = await _database.database;
    return db.transaction((txn) async {
      final period = await _core._requirePeriod(txn, profileId, periodId);
      if (period.periodNumber != story.period ||
          story.id != 'day3_bowl_replacement' ||
          story.period != 3 ||
          story.price != 120 ||
          story.category != ShopItemCategory.need ||
          story.checkpoint != 'changed_circumstance' ||
          !period.requiredCheckpoints.contains(story.checkpoint)) {
        throw StateError('Story purchase does not match this period.');
      }
      final source = 'story_${story.id}';
      if (await _replayOrReject(
        txn,
        profileId: profileId,
        periodId: periodId,
        actionId: story.id,
        outcome: 'purchased',
        operationId: operationId,
        checkpoint: story.checkpoint,
        period: period,
        transactionSource: source,
        transactionAmount: -story.price,
        transactionType: GameTransactionType.needExpense,
      )) {
        return _core._requireState(txn, profileId);
      }
      _core._requireFinancialActionsAllowed(period);
      final state = await _core._requireState(txn, profileId);
      if (state.walletBalance < story.price) {
        throw InsufficientFundsException(
          itemPrice: story.price,
          availableBalance: state.walletBalance,
        );
      }
      final now = DateTime.now().toUtc();
      final updated = await _core._applyWalletTransaction(
        txn,
        GameTransaction(
          profileId: profileId,
          periodId: periodId,
          type: GameTransactionType.needExpense,
          amount: -story.price,
          source: source,
          description: 'Покупка: ${story.name}',
          createdAt: now,
          deduplicationKey: 'special:$operationId',
        ),
      );
      await _writeProof(
        txn,
        profileId: profileId,
        periodId: periodId,
        actionId: story.id,
        outcome: 'purchased',
        operationId: operationId,
        now: now,
      );
      await _core._resolveCheckpointInTransaction(
        txn,
        await _core._requirePeriod(txn, profileId, periodId),
        story.checkpoint,
      );
      return updated;
    });
  }

  @override
  Future<GameState> decidePromotion({
    required int profileId,
    required int periodId,
    required ShopPromotion promotion,
    required ShopItem item,
    required String operationId,
    required bool purchase,
  }) async {
    _core._validateOperationId(operationId);
    final db = await _database.database;
    return db.transaction((txn) async {
      final period = await _core._requirePeriod(txn, profileId, periodId);
      if (period.periodNumber != promotion.period ||
          promotion.id != 'day4_treat_discount' ||
          promotion.period != 4 ||
          promotion.itemId != 'food_treat' ||
          item.id != promotion.itemId ||
          item.price != 60 ||
          item.category != ShopItemCategory.want ||
          promotion.promoPrice != 35 ||
          promotion.maxPromoQuantity != 1 ||
          promotion.checkpoint != 'discount_decision' ||
          !period.requiredCheckpoints.contains(promotion.checkpoint)) {
        throw StateError('Promotion does not match this period.');
      }
      final outcome = purchase ? 'purchased' : 'skipped';
      final source = 'promotion_${promotion.id}';
      if (await _replayOrReject(
        txn,
        profileId: profileId,
        periodId: periodId,
        actionId: promotion.id,
        outcome: outcome,
        operationId: operationId,
        checkpoint: promotion.checkpoint,
        period: period,
        transactionSource: source,
        transactionAmount: -promotion.promoPrice,
        transactionType: GameTransactionType.wantExpense,
      )) {
        return _core._requireState(txn, profileId);
      }
      _core._requireFinancialActionsAllowed(period);
      final state = await _core._requireState(txn, profileId);
      final now = DateTime.now().toUtc();
      var updated = state;
      if (purchase) {
        if (state.walletBalance < promotion.promoPrice) {
          throw InsufficientFundsException(
            itemPrice: promotion.promoPrice,
            availableBalance: state.walletBalance,
          );
        }
        updated = await _core._applyWalletTransaction(
          txn,
          GameTransaction(
            profileId: profileId,
            periodId: periodId,
            type: GameTransactionType.wantExpense,
            amount: -promotion.promoPrice,
            source: source,
            description: 'Акция: ${item.name}',
            createdAt: now,
            deduplicationKey: 'special:$operationId',
          ),
        );
        await txn.rawInsert(
          '''
          INSERT INTO inventory (profile_id, item_id, quantity, acquired_at)
          VALUES (?, ?, 1, ?)
          ON CONFLICT(profile_id, item_id) DO UPDATE SET
            quantity = quantity + 1,
            acquired_at = excluded.acquired_at
        ''',
          [profileId, item.id, now.toIso8601String()],
        );
      }
      await _writeProof(
        txn,
        profileId: profileId,
        periodId: periodId,
        actionId: promotion.id,
        outcome: outcome,
        operationId: operationId,
        now: now,
      );
      await _core._resolveCheckpointInTransaction(
        txn,
        await _core._requirePeriod(txn, profileId, periodId),
        promotion.checkpoint,
      );
      return updated;
    });
  }
}
