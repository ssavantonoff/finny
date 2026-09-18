import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('v4 migrates pet state without losing existing runtime data', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('finny_v5_');
    final path = '${directory.path}/finny.sqlite';
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
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
            CREATE TABLE pets (
              profile_id INTEGER PRIMARY KEY,
              name TEXT NOT NULL,
              color_id TEXT NOT NULL,
              pattern_id TEXT NOT NULL,
              development_stage INTEGER NOT NULL,
              growth_points INTEGER NOT NULL,
              satiety INTEGER NOT NULL,
              mood INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE game_states (
              profile_id INTEGER PRIMARY KEY,
              wallet_balance INTEGER NOT NULL,
              current_period INTEGER NOT NULL,
              active_goal_id TEXT,
              saved_amount INTEGER NOT NULL,
              goal_change_used INTEGER NOT NULL,
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
        },
      ),
    );
    final created = DateTime.utc(2026, 9, 18).toIso8601String();
    await legacy.insert('profiles', {
      'id': 1,
      'game_name': 'Existing player',
      'profile_type': 'NORMAL',
      'onboarding_completed': 1,
      'created_at': created,
    });
    await legacy.insert('pets', {
      'profile_id': 1,
      'name': 'Existing Finny',
      'color_id': 'mint',
      'pattern_id': 'spots',
      'development_stage': 1,
      'growth_points': 25,
      'satiety': 63,
      'mood': 74,
    });
    await legacy.insert('game_states', {
      'profile_id': 1,
      'wallet_balance': 321,
      'current_period': 1,
      'active_goal_id': 'goal_scooter',
      'saved_amount': 123,
      'goal_change_used': 1,
      'updated_at': created,
    });
    await legacy.insert('game_periods', {
      'id': 7,
      'profile_id': 1,
      'definition_id': 'period_1_needs_vs_wants',
      'period_number': 1,
      'start_wallet_balance': 10,
      'base_income': 500,
      'extra_income': 50,
      'planned_need': 100,
      'planned_want': 100,
      'planned_savings': 100,
      'planned_free': 210,
      'actual_need': 40,
      'actual_want': 30,
      'actual_savings': 20,
      'required_checkpoints': '["financial_task"]',
      'resolved_checkpoints': '[]',
      'end_wallet_balance': null,
      'growth_points_earned': 0,
      'status': 'active',
      'created_at': created,
      'completed_at': null,
    });
    await legacy.close();

    final migrated = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    final db = await migrated.database;
    final games = SqliteGameRepository(migrated);
    expect(await db.getVersion(), AppDatabase.schemaVersion);
    expect((await games.getPet(1))?.satiety, 63);
    expect((await games.getPet(1))?.care, 40);
    expect((await games.getPet(1))?.mood, 74);
    expect((await games.getPet(1))?.growthPoints, 25);
    expect((await games.getGameState(1))?.walletBalance, 321);
    expect((await games.getGameState(1))?.savedAmount, 123);
    final period = await games.getPeriodById(1, 7);
    expect(period?.plannedFree, 210);
    expect(period?.actualSavings, 20);
    expect(period?.activeElapsedMilliseconds, 0);
    expect(period?.satietyDecayApplied, 0);
    expect(period?.careDecayApplied, 0);
    expect(period?.moodDecayApplied, 0);
    expect(
      await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'pet_daily_usage'",
      ),
      hasLength(1),
    );
    await migrated.close();

    final reopened = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    addTearDown(reopened.close);
    expect((await SqliteGameRepository(reopened).getPet(1))?.care, 40);
    expect(
      (await SqliteGameRepository(
        reopened,
      ).getPeriodById(1, 7))?.activeElapsedMilliseconds,
      0,
    );
  });
}
