import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

void main() {
  sqfliteFfiInit();

  test(
    'fresh v7 has canonical special-action proof table and constraints',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final db = await database.database;
      expect(await db.getVersion(), 7);
      final schema = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'period_special_actions'",
      );
      expect(schema, hasLength(1));
      expect(
        schema.single['sql'],
        contains('PRIMARY KEY (profile_id, period_id, action_id)'),
      );
      expect(
        schema.single['sql'],
        contains('UNIQUE (profile_id, operation_id)'),
      );
    },
  );

  test(
    'v6 to v7 adds proof table without changing existing runtime data',
    () async {
      final directory = await Directory.systemTemp.createTemp('finny_v7_');
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
          walletBalance: 300,
          currentPeriod: 0,
          savedAmount: 25,
          updatedAt: DateTime.utc(2026),
        ),
      );
      await games.savePet(
        Pet(
          profileId: profile.id!,
          name: 'Финни',
          colorId: 'blue',
          patternId: 'plain',
          developmentStage: 1,
          growthPoints: 20,
          satiety: 63,
          care: 64,
          mood: 65,
        ),
      );
      final period = await games.startPeriod(
        profileId: profile.id!,
        definitionId: 'period_3',
        periodNumber: 3,
        baseIncome: 500,
        requiredCheckpoints: const ['changed_circumstance'],
        createdAt: DateTime.utc(2026),
      );
      await games.confirmBudget(profileId: profile.id!, periodId: period.id!);
      const item = ShopItem(
        id: 'food_apple',
        name: 'Яблоко',
        category: ShopItemCategory.need,
        price: 40,
        persistent: false,
        effectType: 'satiety',
        effectValue: 20,
        unlockType: 'available',
        usagePolicy: ItemUsagePolicy.unlimited,
      );
      await PurchaseService(
        SqlitePurchasePort(initial),
        TestContentRepository(
          testPeriodDefinitions(count: 5),
          shopItems: const [item],
        ),
      ).purchase(
        profileId: profile.id!,
        periodId: period.id!,
        itemId: item.id,
        operationId: 'before-upgrade',
      );
      final db = await initial.database;
      final now = DateTime.utc(2026).toIso8601String();
      await db.insert('task_progress', {
        'profile_id': profile.id!,
        'task_id': 'task_3',
        'status': 'completed',
        'reward_claimed': 1,
        'scenario_state': '{}',
        'updated_at': now,
      });
      await db.insert('pet_daily_usage', {
        'profile_id': profile.id!,
        'period_id': period.id!,
        'action_id': 'item:food_apple',
        'usage_slot': 'default',
        'usage_count': 1,
        'updated_at': now,
      });
      await db.insert('pet_action_operations', {
        'profile_id': profile.id!,
        'operation_id': 'before-upgrade-action',
        'period_id': period.id!,
        'action_id': 'item:food_apple',
        'usage_slot': 'default',
        'created_at': now,
      });
      final tables = [
        'profiles',
        'game_states',
        'pets',
        'game_periods',
        'transactions',
        'inventory',
        'task_progress',
        'pet_daily_usage',
        'pet_action_operations',
      ];
      final before = <String, List<Map<String, Object?>>>{
        for (final table in tables) table: await db.query(table),
      };
      await db.execute('DROP TABLE period_special_actions');
      await db.setVersion(6);
      await initial.close();

      final migrated = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(migrated.close);
      final upgraded = await migrated.database;
      expect(await upgraded.getVersion(), 7);
      expect(
        await upgraded.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'period_special_actions'",
        ),
        hasLength(1),
      );
      for (final table in tables) {
        expect(await upgraded.query(table), before[table], reason: table);
      }
    },
  );
}
