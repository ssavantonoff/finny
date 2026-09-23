import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'fresh v13 enforces finale acknowledgement and cascades with profile',
    () async {
      final db = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(db.close);
      final sqlite = await db.database;
      expect(await sqlite.getVersion(), 13);
      final profileId = await sqlite.insert('profiles', {
        'game_name': 'Игрок',
        'profile_type': 'NORMAL',
        'onboarding_completed': 1,
        'created_at': '2026-01-01',
      });
      await expectLater(
        sqlite.insert('campaign_completion', {
          'profile_id': profileId,
          'free_play_started_at': '2026-01-02',
        }),
        throwsA(isA<DatabaseException>()),
      );
      await sqlite.insert('campaign_completion', {
        'profile_id': profileId,
        'finale_acknowledged_at': '2026-01-02',
      });
      await sqlite.delete('profiles', where: 'id = ?', whereArgs: [profileId]);
      expect(await sqlite.query('campaign_completion'), isEmpty);
    },
  );

  test(
    'v12 upgrade only adds post-campaign tables and preserves historical rows',
    () async {
      final directory = await Directory.systemTemp.createTemp('finny_v13_');
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final path = '${directory.path}/game.sqlite';
      final original = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final db = await original.database;
      final profileId = await db.insert('profiles', {
        'game_name': 'Старое сохранение',
        'profile_type': 'NORMAL',
        'onboarding_completed': 1,
        'created_at': '2026-01-01',
      });
      final periodId = await db.insert('game_periods', {
        'profile_id': profileId,
        'definition_id': 'period_5_independent',
        'period_number': 5,
        'start_wallet_balance': 100,
        'status': 'completed',
        'created_at': '2026-01-01',
        'completed_at': '2026-01-02',
      });
      await db.insert('transactions', {
        'profile_id': profileId,
        'period_id': periodId,
        'type': 'task_reward',
        'amount': 50,
        'source': 'legacy_reward',
        'description': 'Награда',
        'created_at': '2026-01-02',
      });
      await db.insert('task_progress', {
        'profile_id': profileId,
        'task_id': 'task_final_choice_05',
        'status': 'completed',
        'reward_claimed': 1,
        'scenario_state': '{}',
        'updated_at': '2026-01-02',
      });
      await db.insert('completed_goals', {
        'profile_id': profileId,
        'goal_id': 'goal_1',
        'reward_asset_id': 'reward_1',
        'price_paid': 100,
        'completed_at': '2026-01-02',
        'claim_operation_id': 'legacy-claim',
      });
      final before = [
        await db.query('game_periods'),
        await db.query('transactions'),
        await db.query('task_progress'),
        await db.query('completed_goals'),
      ];
      await original.close();
      final raw = await databaseFactoryFfi.openDatabase(path);
      await raw.execute('DROP TABLE campaign_completion');
      await raw.execute('DROP TABLE free_play_pet_operations');
      await raw.execute('DROP TABLE free_play_equipped_accessories');
      await raw.execute('PRAGMA user_version = 12');
      await raw.close();
      final upgraded = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(upgraded.close);
      final next = await upgraded.database;
      expect(await next.getVersion(), 13);
      expect(await next.query('campaign_completion'), isEmpty);
      expect(await next.query('free_play_pet_operations'), isEmpty);
      expect(await next.query('free_play_equipped_accessories'), isEmpty);
      expect(await next.query('game_periods'), before[0]);
      expect(await next.query('transactions'), before[1]);
      expect(await next.query('task_progress'), before[2]);
      expect(await next.query('completed_goals'), before[3]);
    },
  );
}
