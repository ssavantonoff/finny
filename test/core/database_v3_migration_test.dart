import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('schema v2 migrates to v3 without losing runtime data', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('finny_v3_');
    final path = '${directory.path}/finny.sqlite';
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE profiles (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              game_name TEXT NOT NULL,
              profile_type TEXT NOT NULL,
              onboarding_completed INTEGER NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE game_states (
              profile_id INTEGER PRIMARY KEY,
              wallet_balance INTEGER NOT NULL,
              current_period INTEGER NOT NULL,
              active_goal_id TEXT,
              saved_amount INTEGER NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE game_periods (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              profile_id INTEGER NOT NULL,
              definition_id TEXT NOT NULL,
              period_number INTEGER NOT NULL,
              start_wallet_balance INTEGER NOT NULL,
              base_income INTEGER NOT NULL,
              extra_income INTEGER NOT NULL,
              planned_need INTEGER NOT NULL,
              planned_want INTEGER NOT NULL,
              planned_savings INTEGER NOT NULL,
              planned_free INTEGER NOT NULL,
              actual_need INTEGER NOT NULL,
              actual_want INTEGER NOT NULL,
              actual_savings INTEGER NOT NULL,
              required_checkpoints TEXT NOT NULL,
              resolved_checkpoints TEXT NOT NULL,
              end_wallet_balance INTEGER,
              growth_points_earned INTEGER NOT NULL,
              status TEXT NOT NULL,
              created_at TEXT NOT NULL,
              completed_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE transactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              profile_id INTEGER NOT NULL,
              period_id INTEGER,
              type TEXT NOT NULL,
              amount INTEGER NOT NULL,
              source TEXT NOT NULL,
              description TEXT NOT NULL,
              created_at TEXT NOT NULL,
              deduplication_key TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE inventory (
              profile_id INTEGER NOT NULL,
              item_id TEXT NOT NULL,
              quantity INTEGER NOT NULL,
              acquired_at TEXT NOT NULL,
              PRIMARY KEY (profile_id, item_id)
            )
          ''');
        },
      ),
    );
    final created = DateTime.utc(2026, 1, 1).toIso8601String();
    await legacy.insert('profiles', {
      'id': 1,
      'game_name': 'Legacy',
      'profile_type': 'NORMAL',
      'onboarding_completed': 1,
      'created_at': created,
    });
    await legacy.insert('game_states', {
      'profile_id': 1,
      'wallet_balance': 321,
      'current_period': 1,
      'active_goal_id': 'goal_scooter',
      'saved_amount': 123,
      'updated_at': created,
    });
    await legacy.insert('game_periods', {
      'id': 4,
      'profile_id': 1,
      'definition_id': 'period_1_needs_vs_wants',
      'period_number': 1,
      'start_wallet_balance': 0,
      'base_income': 500,
      'extra_income': 0,
      'planned_need': 100,
      'planned_want': 100,
      'planned_savings': 100,
      'planned_free': 200,
      'actual_need': 20,
      'actual_want': 30,
      'actual_savings': 40,
      'required_checkpoints': '["savings_decision"]',
      'resolved_checkpoints': '[]',
      'end_wallet_balance': null,
      'growth_points_earned': 0,
      'status': 'active',
      'created_at': created,
      'completed_at': null,
    });
    await legacy.insert('transactions', {
      'id': 8,
      'profile_id': 1,
      'period_id': 4,
      'type': 'savings_deposit',
      'amount': -40,
      'source': 'legacy',
      'description': 'Legacy',
      'created_at': created,
      'deduplication_key': 'legacy-1',
    });
    await legacy.insert('inventory', {
      'profile_id': 1,
      'item_id': 'legacy_item',
      'quantity': 1,
      'acquired_at': created,
    });
    await legacy.close();

    final migrated = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    final games = SqliteGameRepository(migrated);
    final state = await games.getGameState(1);
    final period = await games.getPeriodById(1, 4);
    final db = await migrated.database;
    expect(await db.getVersion(), 3);
    expect(state?.walletBalance, 321);
    expect(state?.savedAmount, 123);
    expect(state?.activeGoalId, 'goal_scooter');
    expect(state?.goalChangeUsed, isFalse);
    expect(period?.actualSavings, 40);
    expect(await games.getTransactions(1), hasLength(1));
    expect(await games.getInventoryQuantity(1, 'legacy_item'), 1);
    expect(await games.getCompletedGoals(1), isEmpty);
    await migrated.close();

    final reopened = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    addTearDown(reopened.close);
    expect((await reopened.database).getVersion(), completion(3));
    expect(
      (await SqliteGameRepository(reopened).getGameState(1))?.savedAmount,
      123,
    );
  });
}
