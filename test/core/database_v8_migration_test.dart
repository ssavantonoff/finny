import 'dart:convert';
import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'v7 to v8 preserves runtime data and normalizes lifecycle state',
    () async {
      final directory = await Directory.systemTemp.createTemp('finny_v8_');
      final path = '${directory.path}/finny.sqlite';
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final initial = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final profiles = SqliteProfileRepository(initial);
      final games = SqliteGameRepository(initial);
      final profile = await profiles.create(
        Profile(
          gameName: 'Existing player',
          profileType: ProfileType.normal,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026),
        ),
      );
      await games.createInitialState(
        GameState(
          profileId: profile.id!,
          walletBalance: 321,
          currentPeriod: 1,
          activeGoalId: 'goal_scooter',
          savedAmount: 77,
          updatedAt: DateTime.utc(2026),
        ),
      );
      await games.savePet(
        Pet(
          profileId: profile.id!,
          name: 'Финни',
          colorId: 'blue',
          patternId: 'spots',
          developmentStage: 0,
          growthPoints: 45,
          satiety: 61,
          care: 62,
          mood: 63,
        ),
      );
      var period = await games.startPeriod(
        profileId: profile.id!,
        definitionId: 'period_1',
        periodNumber: 1,
        baseIncome: 0,
        requiredCheckpoints: const [
          'financial_task',
          'mandatory_need',
          'savings_decision',
        ],
        createdAt: DateTime.utc(2026),
      );
      period = await games.confirmBudget(
        profileId: profile.id!,
        periodId: period.id!,
      );
      final db = await initial.database;
      await db.update(
        'game_periods',
        {
          'resolved_checkpoints': jsonEncode([
            'financial_task',
            'mandatory_need',
            'savings_decision',
          ]),
        },
        where: 'id = ?',
        whereArgs: [period.id],
      );
      final planningMap = Map<String, Object?>.from(period.toMap())
        ..remove('id')
        ..['definition_id'] = 'period_2'
        ..['period_number'] = 2
        ..['status'] = GamePeriodStatus.planning.name
        ..['required_checkpoints'] = jsonEncode(['mandatory_need'])
        ..['resolved_checkpoints'] = jsonEncode(['mandatory_need']);
      final planningId = await db.insert('game_periods', planningMap);
      final completedMap = Map<String, Object?>.from(period.toMap())
        ..remove('id')
        ..['definition_id'] = 'period_3'
        ..['period_number'] = 3
        ..['status'] = GamePeriodStatus.completed.name
        ..['required_checkpoints'] = jsonEncode(['mandatory_need'])
        ..['resolved_checkpoints'] = jsonEncode(['mandatory_need'])
        ..['end_wallet_balance'] = 321
        ..['completed_at'] = DateTime.utc(2026).toIso8601String();
      final completedId = await db.insert('game_periods', completedMap);
      await db.insert('inventory', {
        'profile_id': profile.id,
        'item_id': 'food_apple',
        'quantity': 3,
        'acquired_at': DateTime.utc(2026).toIso8601String(),
      });
      await db.insert('task_progress', {
        'profile_id': profile.id,
        'task_id': 'task_period_1',
        'status': 'completed',
        'reward_claimed': 1,
        'scenario_state': jsonEncode({'answerId': 'apple'}),
        'updated_at': DateTime.utc(2026).toIso8601String(),
      });
      await db.insert('period_special_actions', {
        'profile_id': profile.id,
        'period_id': period.id,
        'action_id': 'legacy-special',
        'outcome': 'skipped',
        'operation_id': 'legacy-operation',
        'created_at': DateTime.utc(2026).toIso8601String(),
      });
      await db.setVersion(7);
      await initial.close();

      final migrated = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(migrated.close);
      final migratedGames = SqliteGameRepository(migrated);
      final migratedDb = await migrated.database;
      final state = await migratedGames.getGameState(profile.id!);
      final migratedPeriod = await migratedGames.getPeriodById(
        profile.id!,
        period.id!,
      );
      final pet = await migratedGames.getPet(profile.id!);

      expect(await migratedDb.getVersion(), AppDatabase.schemaVersion);
      expect(state?.walletBalance, 321);
      expect(state?.savedAmount, 77);
      expect(state?.activeGoalId, 'goal_scooter');
      expect(migratedPeriod?.requiredCheckpoints, [
        'financial_task',
        'savings_decision',
      ]);
      expect(migratedPeriod?.resolvedCheckpoints, [
        'financial_task',
        'savings_decision',
      ]);
      expect(migratedPeriod?.status, GamePeriodStatus.readyToFinish);
      expect(
        (await migratedGames.getPeriodById(profile.id!, planningId))?.status,
        GamePeriodStatus.planning,
      );
      expect(
        (await migratedGames.getPeriodById(profile.id!, completedId))?.status,
        GamePeriodStatus.completed,
      );
      expect(pet?.developmentStage, 1);
      expect(pet?.growthPoints, 45);
      expect(pet?.satiety, 55);
      expect(
        await migratedGames.getInventoryQuantity(profile.id!, 'food_apple'),
        3,
      );
      expect(await migratedDb.query('task_progress'), hasLength(1));
      expect(await migratedDb.query('period_special_actions'), hasLength(1));
    },
  );
}
