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
    'v8 to v9 preserves runtime data and initializes virtual days',
    () async {
      final directory = await Directory.systemTemp.createTemp('finny_v9_');
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
      final normal = await profiles.create(
        Profile(
          gameName: 'Existing player',
          profileType: ProfileType.normal,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026),
        ),
      );
      final demo = await profiles.create(
        Profile(
          gameName: 'Demo',
          profileType: ProfileType.demo,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026),
        ),
      );
      await games.createInitialState(
        GameState(
          profileId: normal.id!,
          walletBalance: 321,
          currentPeriod: 4,
          activeGoalId: 'goal_scooter',
          savedAmount: 77,
          updatedAt: DateTime.utc(2026),
        ),
      );
      await games.createInitialState(
        GameState(
          profileId: demo.id!,
          walletBalance: 99,
          currentPeriod: 0,
          savedAmount: 11,
          updatedAt: DateTime.utc(2026),
        ),
      );
      await games.savePet(
        Pet(
          profileId: normal.id!,
          name: 'Финни',
          colorId: 'blue',
          patternId: 'spots',
          developmentStage: 2,
          growthPoints: 45,
          satiety: 61,
          care: 62,
          mood: 63,
        ),
      );

      final db = await initial.database;
      final now = DateTime.utc(2026).toIso8601String();
      Future<int> insertPeriod({
        required int number,
        required GamePeriodStatus status,
        int elapsed = 0,
        int? endingWallet,
      }) => db.insert('game_periods', {
        'profile_id': normal.id,
        'definition_id': 'period_$number',
        'period_number': number,
        'start_wallet_balance': 100 + number,
        'base_income': 500,
        'extra_income': number,
        'planned_need': 100,
        'planned_want': 50,
        'planned_savings': 25,
        'planned_free': 325,
        'actual_need': 10,
        'actual_want': 20,
        'actual_savings': 30,
        'required_checkpoints': '[]',
        'resolved_checkpoints': '[]',
        'end_wallet_balance': endingWallet,
        'growth_points_earned': number,
        'day_progress': 17,
        'active_elapsed_milliseconds': elapsed,
        'satiety_decay_applied': 3,
        'care_decay_applied': 2,
        'mood_decay_applied': 1,
        'status': status.name,
        'created_at': now,
        'completed_at': status == GamePeriodStatus.completed ? now : null,
      });

      final planningId = await insertPeriod(
        number: 1,
        status: GamePeriodStatus.planning,
      );
      final activeId = await insertPeriod(
        number: 2,
        status: GamePeriodStatus.active,
        elapsed: 180000,
      );
      final readyId = await insertPeriod(
        number: 3,
        status: GamePeriodStatus.readyToFinish,
      );
      final completedId = await insertPeriod(
        number: 4,
        status: GamePeriodStatus.completed,
        endingWallet: 222,
      );
      await db.delete(
        'inventory',
        where: 'profile_id = ? AND item_id = ?',
        whereArgs: [normal.id, 'care_toothbrush'],
      );
      await db.insert('inventory', {
        'profile_id': normal.id,
        'item_id': 'food_apple',
        'quantity': 3,
        'acquired_at': now,
      });
      expect(await games.getInventoryQuantity(demo.id!, 'care_toothbrush'), 1);

      await db.execute('ALTER TABLE game_periods DROP COLUMN day_progress');
      await db.setVersion(8);
      await initial.close();

      final migrated = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(migrated.close);
      final migratedGames = SqliteGameRepository(migrated);
      final migratedDb = await migrated.database;

      expect(await migratedDb.getVersion(), AppDatabase.schemaVersion);
      final state = await migratedGames.getGameState(normal.id!);
      expect(
        (
          state?.walletBalance,
          state?.savedAmount,
          state?.activeGoalId,
          state?.currentPeriod,
        ),
        (321, 77, 'goal_scooter', 4),
      );
      final pet = await migratedGames.getPet(normal.id!);
      expect(
        (pet?.satiety, pet?.care, pet?.mood, pet?.developmentStage),
        (61, 62, 63, 2),
      );
      expect(
        (await migratedGames.getPeriodById(
          normal.id!,
          planningId,
        ))?.dayProgress,
        0,
      );
      expect(
        (await migratedGames.getPeriodById(normal.id!, activeId))?.dayProgress,
        34,
      );
      expect(
        (await migratedGames.getPeriodById(normal.id!, readyId))?.dayProgress,
        76,
      );
      final completed = await migratedGames.getPeriodById(
        normal.id!,
        completedId,
      );
      expect(completed?.dayProgress, 100);
      expect(completed?.endWalletBalance, 222);
      expect(completed?.actualSavings, 30);
      expect(
        await migratedGames.getInventoryQuantity(normal.id!, 'food_apple'),
        3,
      );
      expect(
        await migratedGames.getInventoryQuantity(normal.id!, 'care_toothbrush'),
        1,
      );
      expect(
        await migratedGames.getInventoryQuantity(demo.id!, 'care_toothbrush'),
        1,
      );
      final toothbrushRows = await migratedDb.query(
        'inventory',
        where: 'item_id = ?',
        whereArgs: ['care_toothbrush'],
      );
      expect(toothbrushRows, hasLength(2));
    },
  );
}
