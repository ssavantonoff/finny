import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/transaction.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class GameRepository {
  Future<void> createInitialState(GameState state);
  Future<GameState?> getGameState(int profileId);
  Future<void> setCurrentPeriod(int profileId, int periodNumber);
  Future<void> savePet(Pet pet);
  Future<Pet?> getPet(int profileId);
  Future<GamePeriod> createPeriod(GamePeriod period);
  Future<GamePeriod?> getPeriod(int profileId, int periodNumber);
  Future<void> savePeriod(GamePeriod period);
  Future<GameState> applyWalletChange(GameTransaction transaction);
  Future<GameState> moveSavings({
    required int profileId,
    required int? periodId,
    required int amount,
    required String source,
    required String description,
  });
  Future<List<GameTransaction>> getTransactions(int profileId);
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
  Future<GameState?> getGameState(int profileId) async {
    final db = await _appDatabase.database;
    return _readState(db, profileId);
  }

  @override
  Future<void> setCurrentPeriod(int profileId, int periodNumber) async {
    if (periodNumber < 0) {
      throw ArgumentError.value(
        periodNumber,
        'periodNumber',
        'Must not be negative.',
      );
    }
    final db = await _appDatabase.database;
    final count = await db.update(
      'game_states',
      {
        'current_period': periodNumber,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'profile_id = ?',
      whereArgs: [profileId],
    );
    if (count != 1) {
      throw StateError('Game state for profile $profileId is missing.');
    }
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
  Future<GamePeriod> createPeriod(GamePeriod period) async {
    if (period.id != null) {
      throw ArgumentError('A new game period must not already have an id.');
    }
    final db = await _appDatabase.database;
    final id = await db.insert('game_periods', period.toMap());
    return period.copyWith(id: id);
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
  Future<void> savePeriod(GamePeriod period) async {
    final id = period.id;
    if (id == null) {
      throw ArgumentError('Cannot update a period without an id.');
    }
    final db = await _appDatabase.database;
    final count = await db.update(
      'game_periods',
      period.toMap()..remove('id'),
      where: 'id = ? AND profile_id = ?',
      whereArgs: [id, period.profileId],
    );
    if (count != 1) throw StateError('Game period $id does not exist.');
  }

  @override
  Future<GameState> applyWalletChange(GameTransaction transaction) async {
    if (transaction.id != null) {
      throw ArgumentError('A new transaction must not already have an id.');
    }
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final state = await _requireState(txn, transaction.profileId);
      final nextBalance = state.walletBalance + transaction.amount;
      if (nextBalance < 0) {
        throw StateError('Wallet balance cannot become negative.');
      }
      try {
        await txn.insert('transactions', transaction.toMap());
      } on DatabaseException catch (error) {
        if (error.isUniqueConstraintError()) {
          throw StateError('This transaction has already been recorded.');
        }
        rethrow;
      }
      final updated = state.copyWith(
        walletBalance: nextBalance,
        updatedAt: DateTime.now().toUtc(),
      );
      await txn.update(
        'game_states',
        updated.toMap()..remove('profile_id'),
        where: 'profile_id = ?',
        whereArgs: [transaction.profileId],
      );
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
        type: amount > 0 ? 'savings_deposit' : 'savings_withdrawal',
        amount: -amount,
        source: source,
        description: description,
        createdAt: DateTime.now().toUtc(),
      );
      await txn.insert('transactions', transaction.toMap());
      final updated = state.copyWith(
        walletBalance: nextWallet,
        savedAmount: nextSavings,
        updatedAt: DateTime.now().toUtc(),
      );
      await txn.update(
        'game_states',
        updated.toMap()..remove('profile_id'),
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      return updated;
    });
  }

  @override
  Future<List<GameTransaction>> getTransactions(int profileId) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'transactions',
      where: 'profile_id = ?',
      whereArgs: [profileId],
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
}
