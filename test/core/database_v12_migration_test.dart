import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'v11 to v12 adds sale state without changing legacy Day 5 rows',
    () async {
      final directory = await Directory.systemTemp.createTemp('finny_v12_');
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
        'created_at': DateTime.utc(2026).toIso8601String(),
      });
      await db.insert('task_progress', {
        'profile_id': profileId,
        'task_id': 'task_final_choice_05',
        'status': 'completed',
        'reward_claimed': 1,
        'scenario_state': '{"answerId":"balanced"}',
        'updated_at': DateTime.utc(2026).toIso8601String(),
      });
      await original.close();
      final raw = await databaseFactoryFfi.openDatabase(path);
      await raw.execute('DROP TABLE day5_sale_assignments');
      await raw.execute('PRAGMA user_version = 11');
      await raw.close();

      final upgraded = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(upgraded.close);
      final next = await upgraded.database;
      expect(
        (await next.rawQuery('PRAGMA user_version')).single['user_version'],
        AppDatabase.schemaVersion,
      );
      expect(await next.query('day5_sale_assignments'), isEmpty);
      final progress = await next.query(
        'task_progress',
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      expect(progress.single['task_id'], 'task_final_choice_05');
      expect(progress.single['scenario_state'], '{"answerId":"balanced"}');
    },
  );
}
