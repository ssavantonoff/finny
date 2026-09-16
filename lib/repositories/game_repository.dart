import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/transaction.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class GameRepository {
  Future<void> createInitialState(GameState state);
  Future<GameState> ensureInitialState(int profileId);
  Future<GameState?> getGameState(int profileId);
  Future<void> savePet(Pet pet);
  Future<Pet?> getPet(int profileId);
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
  Future<GameState> depositSavings({
    required int profileId,
    required int periodId,
    required int amount,
    required String operationId,
  });
  Future<GameState> moveSavings({
    required int profileId,
    required int? periodId,
    required int amount,
    required String source,
    required String description,
  });
  Future<int> getInventoryQuantity(int profileId, String itemId);
  Future<List<GameTransaction>> getTransactions(int profileId, {int? periodId});
  Future<void> clearDemoRuntimeData(int profileId);
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
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final period = await _requirePeriod(txn, profileId, periodId);
      if (period.status != GamePeriodStatus.active &&
          period.status != GamePeriodStatus.readyToFinish) {
        throw StateError(
          'Checkpoints can only be resolved during an active period.',
        );
      }
      if (!period.requiredCheckpoints.contains(checkpointId)) {
        throw StateError(
          'Checkpoint $checkpointId is not required for this period.',
        );
      }
      if (period.resolvedCheckpoints.contains(checkpointId)) {
        return period;
      }
      if (period.status == GamePeriodStatus.readyToFinish) {
        throw StateError(
          'A ready period cannot accept new checkpoint changes.',
        );
      }

      final resolved = [
        for (final required in period.requiredCheckpoints)
          if (required == checkpointId ||
              period.resolvedCheckpoints.contains(required))
            required,
      ];
      final allResolved = resolved.length == period.requiredCheckpoints.length;
      final updated = period.copyWith(
        resolvedCheckpoints: List.unmodifiable(resolved),
        status: allResolved
            ? GamePeriodStatus.readyToFinish
            : GamePeriodStatus.active,
      );
      await _writePeriod(txn, updated);
      return updated;
    });
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
      _requireFinancialActionsAllowed(period);
      final existing = await _readTransactionByKey(
        txn,
        transaction.profileId,
        key,
      );
      if (existing != null) {
        _requireSameCommand(existing, transaction);
        return _requireState(txn, transaction.profileId);
      }
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
      _requireFinancialActionsAllowed(period);
      final existing = await _readTransactionByKey(
        txn,
        profileId,
        transaction.deduplicationKey!,
      );
      if (existing != null) {
        _requireSameCommand(existing, transaction);
        return _requireState(txn, profileId);
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
  Future<GameState> depositSavings({
    required int profileId,
    required int periodId,
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
      source: 'savings_deposit',
      description: 'Пополнение накоплений',
      createdAt: DateTime.now().toUtc(),
      deduplicationKey: 'operation:$operationId',
    );
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final period = await _requirePeriod(txn, profileId, periodId);
      _requireFinancialActionsAllowed(period);
      final existing = await _readTransactionByKey(
        txn,
        profileId,
        transaction.deduplicationKey!,
      );
      if (existing != null) {
        _requireSameCommand(existing, transaction);
        return _requireState(txn, profileId);
      }
      final state = await _requireState(txn, profileId);
      final nextWallet = state.walletBalance - amount;
      if (nextWallet < 0) {
        throw StateError('Wallet balance cannot become negative.');
      }
      await txn.insert('transactions', transaction.toMap());
      final updated = state.copyWith(
        walletBalance: nextWallet,
        savedAmount: state.savedAmount + amount,
        updatedAt: transaction.createdAt,
      );
      await _writeState(txn, updated);
      return updated;
    });
  }

  @override
  Future<GameState> moveSavings({
    required int profileId,
    required int? periodId,
    required int amount,
    required String source,
    required String description,
  }) async {
    if (amount == 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be non-zero.');
    }
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final state = await _requireState(txn, profileId);
      final nextWallet = state.walletBalance - amount;
      final nextSavings = state.savedAmount + amount;
      if (nextWallet < 0 || nextSavings < 0) {
        throw StateError('Wallet and savings balances cannot become negative.');
      }
      final transaction = GameTransaction(
        profileId: profileId,
        periodId: periodId,
        type: amount > 0
            ? GameTransactionType.savingsDeposit
            : GameTransactionType.savingsWithdrawal,
        amount: -amount,
        source: source,
        description: description,
        createdAt: DateTime.now().toUtc(),
      );
      await txn.insert('transactions', transaction.toMap());
      final updated = state.copyWith(
        walletBalance: nextWallet,
        savedAmount: nextSavings,
        updatedAt: transaction.createdAt,
      );
      await _writeState(txn, updated);
      return updated;
    });
  }

  @override
  Future<int> getInventoryQuantity(int profileId, String itemId) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'inventory',
      columns: ['quantity'],
      where: 'profile_id = ? AND item_id = ?',
      whereArgs: [profileId, itemId],
      limit: 1,
    );
    return rows.isEmpty ? 0 : rows.single['quantity'] as int;
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
        'inventory',
        'transactions',
        'game_periods',
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
    return updated;
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
}
