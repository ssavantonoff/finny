import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('v9 to v10 creates the campaign story event table', () async {
    final directory = await Directory.systemTemp.createTemp('finny_v10_');
    final path = '${directory.path}/finny.sqlite';
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final initial = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    final initialDb = await initial.database;
    final profileId = await initialDb.insert('profiles', {
      'game_name': 'Сохранённый игрок',
      'profile_type': 'NORMAL',
      'onboarding_completed': 1,
      'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    });
    await initialDb.insert('game_states', {
      'profile_id': profileId,
      'wallet_balance': 240,
      'current_period': 3,
      'saved_amount': 60,
      'goal_change_used': 0,
      'updated_at': DateTime.utc(2026, 1, 3).toIso8601String(),
    });
    await initialDb.execute('DROP TABLE campaign_story_events');
    await initialDb.setVersion(9);
    await initial.close();

    final migrated = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    addTearDown(migrated.close);
    final migratedDb = await migrated.database;

    expect(await migratedDb.getVersion(), AppDatabase.schemaVersion);
    final tables = await migratedDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'campaign_story_events'",
    );
    expect(tables, hasLength(1));
    expect(
      (await migratedDb.query(
        'game_states',
        where: 'profile_id = ?',
        whereArgs: [profileId],
      )).single['wallet_balance'],
      240,
    );
  });
}
