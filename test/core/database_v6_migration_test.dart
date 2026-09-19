import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'v5 adds durable pet operation proofs without resetting runtime',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('finny_v6_');
      final path = '${directory.path}/finny.sqlite';
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE profiles (
              id INTEGER PRIMARY KEY,
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
              care INTEGER NOT NULL,
              mood INTEGER NOT NULL
            )
          ''');
            await db.execute('''
            CREATE TABLE game_periods (
              id INTEGER PRIMARY KEY,
              profile_id INTEGER NOT NULL,
              status TEXT NOT NULL,
              UNIQUE (profile_id, id)
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
            await db.execute('''
            CREATE TABLE pet_daily_usage (
              profile_id INTEGER NOT NULL,
              period_id INTEGER NOT NULL,
              action_id TEXT NOT NULL,
              usage_slot TEXT NOT NULL,
              usage_count INTEGER NOT NULL,
              updated_at TEXT NOT NULL,
              PRIMARY KEY (profile_id, period_id, action_id, usage_slot)
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
        'name': 'Finny',
        'color_id': 'blue',
        'pattern_id': 'plain',
        'development_stage': 1,
        'growth_points': 20,
        'satiety': 63,
        'care': 64,
        'mood': 65,
      });
      await legacy.insert('game_periods', {
        'id': 7,
        'profile_id': 1,
        'status': 'active',
      });
      await legacy.insert('inventory', {
        'profile_id': 1,
        'item_id': 'food_apple',
        'quantity': 3,
        'acquired_at': created,
      });
      await legacy.insert('pet_daily_usage', {
        'profile_id': 1,
        'period_id': 7,
        'action_id': 'item:toy_ball',
        'usage_slot': 'default',
        'usage_count': 1,
        'updated_at': created,
      });
      await legacy.close();

      final migrated = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(migrated.close);
      final db = await migrated.database;

      expect(await db.getVersion(), AppDatabase.schemaVersion);
      expect((await db.query('pets')).single['care'], 64);
      expect(
        (await db.query(
          'inventory',
          where: 'item_id = ?',
          whereArgs: ['food_apple'],
        )).single['quantity'],
        3,
      );
      expect(
        (await db.query(
          'inventory',
          where: 'item_id = ?',
          whereArgs: ['care_toothbrush'],
        )).single['quantity'],
        1,
      );
      expect((await db.query('pet_daily_usage')).single['usage_count'], 1);
      expect(
        await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'pet_action_operations'",
        ),
        hasLength(1),
      );
      await db.insert('pet_action_operations', {
        'profile_id': 1,
        'operation_id': 'existing-operation',
        'period_id': 7,
        'action_id': 'item:food_apple',
        'usage_slot': 'default',
        'created_at': created,
      });
      expect(await db.query('pet_action_operations'), hasLength(1));
    },
  );
}
