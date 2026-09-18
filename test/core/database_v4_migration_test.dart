import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/task_progress.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/task_progress_schema.dart';
import '../helpers/test_database.dart';

void main() {
  test('fresh v4 has canonical task_progress schema', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final profile = await SqliteProfileRepository(database).create(
      Profile(
        gameName: 'Fresh',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 9, 18),
      ),
    );
    await expectTaskProgressV4Schema(database, profileId: profile.id!);
  });

  test('v3 without task_progress upgrades to v4 without losing data', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('finny_v4_');
    final path = '${directory.path}/finny.sqlite';
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
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
        },
      ),
    );
    final created = DateTime.utc(2026, 1, 1).toIso8601String();
    await legacy.insert('profiles', {
      'id': 1,
      'game_name': 'Existing player',
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
      'goal_change_used': 0,
      'updated_at': created,
    });
    await legacy.insert('game_periods', {
      'id': 7,
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
      'required_checkpoints': '["financial_task"]',
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
      'period_id': 7,
      'type': 'savings_deposit',
      'amount': -40,
      'source': 'legacy',
      'description': 'Legacy',
      'created_at': created,
      'deduplication_key': 'legacy-1',
    });
    await legacy.close();

    final migrated = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    addTearDown(migrated.close);
    await expectTaskProgressV4Schema(migrated, profileId: 1);
    final db = await migrated.database;
    final games = SqliteGameRepository(migrated);
    expect((await db.query('profiles')).single['game_name'], 'Existing player');
    expect((await games.getGameState(1))?.walletBalance, 321);
    expect((await games.getGameState(1))?.savedAmount, 123);
    expect((await games.getGameState(1))?.activeGoalId, 'goal_scooter');
    expect((await games.getPeriodById(1, 7))?.actualSavings, 40);
    expect((await games.getTransactions(1)).single.amount, -40);
  });

  test(
    'v3 with task_progress preserves existing rows during upgrade',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'finny_v4_existing_',
      );
      final path = '${directory.path}/finny.sqlite';
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final existing = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final profile = await SqliteProfileRepository(existing).create(
        Profile(
          gameName: 'Existing v3 player',
          profileType: ProfileType.normal,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final db = await existing.database;
      await db.insert(
        'task_progress',
        TaskProgress(
          profileId: profile.id!,
          taskId: 'persisted_task',
          status: TaskProgressStatus.completed,
          rewardClaimed: true,
          scenarioState: const {'answerId': 'need_lunch'},
          updatedAt: DateTime.utc(2026, 1, 2),
        ).toMap(),
      );
      // This disposable fixture mirrors a v3 installation that already had
      // task_progress. Only its SQLite user_version is changed for the test.
      await db.setVersion(3);
      await existing.close();

      final migrated = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(migrated.close);
      await expectTaskProgressV4Schema(migrated, profileId: profile.id!);
      final preserved = await SqliteGameRepository(migrated)
          .getTaskProgress(profile.id!, 'persisted_task');
      expect(preserved?.rewardClaimed, isTrue);
      expect(preserved?.scenarioState, {'answerId': 'need_lunch'});
    },
  );
}
