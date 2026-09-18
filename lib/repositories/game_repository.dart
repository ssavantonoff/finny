import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/completed_goal.dart';
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
import 'package:finny/models/transaction.dart';
import 'package:finny/models/task_progress.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class GameRepository {
  Future<void> createInitialState(GameState state);
  Future<GameState> ensureInitialState(int profileId);
  Future<GameState?> getGameState(int profileId);
  Future<void> savePet(Pet pet);
  Future<Pet?> getPet(int profileId);
  Future<Pet> applyActiveElapsedTime({
    required int profileId,
    required int periodId,
    required Duration elapsed,
  });
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
  Future<GamePeriod> completePeriod({
    required int profileId,
    required int periodId,
  });
  Future<GameState> applyWalletChange(GameTransaction transaction);
  Future<GameState> applyIdempotentWalletChange(GameTransaction transaction);
  Future<GameState> purchase({
    required int profileId,
    required int periodId,
    required ShopItem item,
    required String operationId,
  });
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

class SqliteGameRepository implements GameRepository {
  SqliteGameRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<void> createInitialState(GameState state) async {
    final db = await _appDatabase.database;
    await db.insert('game_states', state.toMap());
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
  Future<Pet> applyActiveElapsedTime({
    required int profileId,
    required int periodId,
    required Duration elapsed,
  }) async {
    if (elapsed.isNegative) {
      throw ArgumentError.value(elapsed, 'elapsed', 'Must not be negative.');
    }
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final period = await _requirePeriod(txn, profileId, periodId);
      if (period.status != GamePeriodStatus.active &&
          period.status != GamePeriodStatus.readyToFinish) {
        throw StateError(
          'Pet decay requires an active or ready-to-finish period.',
        );
      }
      final pet = await _requirePet(txn, profileId);
      final uncappedElapsed =
          period.activeElapsedMilliseconds + elapsed.inMilliseconds;
      final activeElapsedMilliseconds =
          uncappedElapsed > PetStateRules.fullDailyDecay.inMilliseconds
          ? PetStateRules.fullDailyDecay.inMilliseconds
          : uncappedElapsed;
      final activeElapsed = Duration(milliseconds: activeElapsedMilliseconds);
      final targetSatietyDecay = PetStateRules.decayAt(
        activeElapsed,
        PetStateRules.maxSatietyDecay,
      );
      final targetCareDecay = PetStateRules.decayAt(
        activeElapsed,
        PetStateRules.maxCareDecay,
      );
      final targetMoodDecay = PetStateRules.decayAt(
        activeElapsed,
        PetStateRules.maxMoodDecay,
      );
      final updatedPet = pet.copyWith(
        satiety: PetStateRules.clampStat(
          pet.satiety - (targetSatietyDecay - period.satietyDecayApplied),
        ),
        care: PetStateRules.clampStat(
          pet.care - (targetCareDecay - period.careDecayApplied),
        ),
        mood: PetStateRules.clampStat(
          pet.mood - (targetMoodDecay - period.moodDecayApplied),
        ),
      );
      final updatedPeriod = period.copyWith(
        activeElapsedMilliseconds: activeElapsedMilliseconds,
        satietyDecayApplied: targetSatietyDecay,
        careDecayApplied: targetCareDecay,
        moodDecayApplied: targetMoodDecay,
      );
      await _writePet(txn, updatedPet);
      await _writePeriod(txn, updatedPeriod);
      return updatedPet;
    });
  }

  @override
  Future<Pet> useItem({
    required int profileId,
    required int periodId,
    required ShopItem item,
    required String operationId,
    required PetActionSlot slot,
  }) {
    final actionId = 'item:${item.id}';
    return _applyPetAction(
      profileId: profileId,
      periodId: periodId,
      actionId: actionId,
      operationId: operationId,
      slot: slot,
      effects: item.petEffects,
      item: item,
    );
  }

  @override
  Future<Pet> performFreePetInteraction({
    required int profileId,
    required int periodId,
    required FreePetInteraction interaction,
    required String operationId,
  }) => _applyPetAction(
    profileId: profileId,
    periodId: periodId,
    actionId: interaction.actionId,
    operationId: operationId,
    slot: PetActionSlot.defaultSlot,
    effects: interaction.effects,
  );

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

      final updatedPet = pet.copyWith(
        satiety: PetStateRules.clampStat(pet.satiety + effects.satiety),
        care: PetStateRules.clampStat(pet.care + effects.care),
        mood: PetStateRules.clampStat(pet.mood + effects.mood),
      );

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
      await txn.rawInsert(
        '''
        INSERT INTO pet_daily_usage (
          profile_id, period_id, action_id, usage_slot, usage_count, updated_at
        ) VALUES (?, ?, ?, ?, 1, ?)
        ON CONFLICT(profile_id, period_id, action_id, usage_slot) DO UPDATE SET
          usage_count = usage_count + 1,
          updated_at = excluded.updated_at
        ''',
        [profileId, periodId, actionId, slot.storageValue, now],
      );
      await _writePet(txn, updatedPet);
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
      if (period.status != GamePeriodStatus.planning) {
        throw StateError('Only a planning period budget can be confirmed.');
      }
      final confirmed = period.copyWith(status: GamePeriodStatus.active);
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
    if (checkpointId == 'financial_task') {
      throw StateError(
        'Financial tasks must be completed through TaskService.',
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
  Future<GamePeriod> completePeriod({
    required int profileId,
    required int periodId,
  }) async {
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final period = await _requirePeriod(txn, profileId, periodId);
      if (period.status != GamePeriodStatus.readyToFinish) {
        throw StateError('Period must be ready before it can be completed.');
      }
      final state = await _requireState(txn, profileId);
      final completed = period.copyWith(
        endWalletBalance: state.walletBalance,
        status: GamePeriodStatus.completed,
        completedAt: DateTime.now().toUtc(),
      );
      await _writePeriod(txn, completed);
      return completed;
    });
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
  Future<GameState> purchase({
    required int profileId,
    required int periodId,
    required ShopItem item,
    required String operationId,
  }) async {
    _validateOperationId(operationId);
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
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final period = await _requirePeriod(txn, profileId, periodId);
      final existing = await _readTransactionByKey(
        txn,
        profileId,
        transaction.deduplicationKey!,
      );
      if (existing != null) {
        _requireSameCommand(existing, transaction);
        return _requireState(txn, profileId);
      }
      _requireFinancialActionsAllowed(period);

      if (item.persistent) {
        final ownedQuantity = await _readInventoryQuantity(
          txn,
          profileId,
          item.id,
        );
        if (ownedQuantity > 0) {
          throw PersistentItemAlreadyOwnedException(itemId: item.id);
        }
      }

      final state = await _requireState(txn, profileId);
      if (state.walletBalance < item.price) {
        throw InsufficientFundsException(
          itemPrice: item.price,
          availableBalance: state.walletBalance,
        );
      }

      final updated = await _applyWalletTransaction(txn, transaction);
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
      final resolved = _withSavingsDecisionResolved(period);
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
      final updated = _withSavingsDecisionResolved(period);
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
      final updated = _withSavingsDecisionResolved(period);
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
    final rows = await db.query(
      'pets',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Pet for profile $profileId is missing.');
    }
    return Pet.fromMap(rows.single);
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
        PetActionSlot.morning => period.status == GamePeriodStatus.active,
        PetActionSlot.evening =>
          period.status == GamePeriodStatus.readyToFinish,
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
      if (!period.requiredCheckpoints.contains('financial_task')) {
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
      if (progress != null || rewardRows.isNotEmpty || checkpointResolved) {
        if (progress == null ||
            progress.status != TaskProgressStatus.completed ||
            !progress.rewardClaimed ||
            progress.scenarioState['answerId'] !=
                task.choiceScenario.correctOptionId ||
            !checkpointResolved ||
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
      if (period.status != GamePeriodStatus.active) {
        throw StateError('New task completion requires an active period.');
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
      final resolved = await _core._resolveCheckpointInTransaction(
        txn,
        afterReward,
        'financial_task',
      );
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
