import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';
import '../helpers/task_progress_schema.dart';

void main() {
  test('schema v1 migrates to current without losing period state', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('finny_migration_');
    final path = '${directory.path}/finny.sqlite';
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
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
            CREATE TABLE game_periods (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              profile_id INTEGER NOT NULL,
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
              deduplication_key TEXT,
              UNIQUE (profile_id, deduplication_key)
            )
          ''');
        },
      ),
    );
    await legacy.insert('profiles', {
      'id': 1,
      'game_name': 'Legacy',
      'profile_type': 'NORMAL',
      'onboarding_completed': 1,
      'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    });
    await legacy.insert('game_states', {
      'profile_id': 1,
      'wallet_balance': 430,
      'current_period': 1,
      'active_goal_id': null,
      'saved_amount': 70,
      'updated_at': DateTime.utc(2026, 1, 2).toIso8601String(),
    });
    await legacy.insert('pets', {
      'profile_id': 1,
      'name': 'Legacy Finny',
      'color_id': 'blue',
      'pattern_id': 'plain',
      'development_stage': 0,
      'growth_points': 0,
      'satiety': 64,
      'mood': 73,
    });
    await legacy.insert('game_periods', {
      'id': 1,
      'profile_id': 1,
      'period_number': 1,
      'start_wallet_balance': 0,
      'base_income': 500,
      'extra_income': 0,
      'planned_need': 200,
      'planned_want': 100,
      'planned_savings': 50,
      'planned_free': 150,
      'actual_need': 0,
      'actual_want': 0,
      'actual_savings': 0,
      'end_wallet_balance': null,
      'growth_points_earned': 0,
      'status': 'active',
      'created_at': DateTime.utc(2026, 1, 2).toIso8601String(),
      'completed_at': null,
    });
    await legacy.close();

    final migratedDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    addTearDown(migratedDatabase.close);
    final games = SqliteGameRepository(migratedDatabase);

    final state = await games.getGameState(1);
    final period = await games.getPeriodById(1, 1);
    final db = await migratedDatabase.database;
    final version = await db.getVersion();

    expect(version, AppDatabase.schemaVersion);
    expect(state?.walletBalance, 430);
    expect(state?.savedAmount, 70);
    expect(period?.status, GamePeriodStatus.active);
    expect(period?.definitionId, 'period_1_needs_vs_wants');
    expect(period?.plannedNeed, 200);
    expect(period?.plannedWant, 100);
    expect(period?.plannedSavings, 50);
    expect(period?.plannedFree, 150);
    expect(period?.requiredCheckpoints, ['financial_task', 'savings_decision']);
    expect(period?.resolvedCheckpoints, isEmpty);
    await expectTaskProgressV4Schema(migratedDatabase, profileId: 1);

    var resumed = period!;
    for (final checkpoint in resumed.requiredCheckpoints) {
      if (checkpoint == 'financial_task') {
        final result =
            await TaskService(
              games,
              SqliteTaskCompletionPort(migratedDatabase),
              TestContentRepository(testPeriodDefinitions(count: 1)),
            ).submitAnswer(
              profileId: 1,
              periodId: resumed.id!,
              taskId: 'task_period_1',
              answerId: 'apple',
            );
        resumed = (result as TaskAnswerCompleted).period;
      } else {
        resumed = await resolveCheckpointForTest(
          migratedDatabase,
          profileId: 1,
          periodId: resumed.id!,
          checkpointId: checkpoint,
        );
      }
    }
    expect(resumed.status, GamePeriodStatus.readyToFinish);
  });
}
