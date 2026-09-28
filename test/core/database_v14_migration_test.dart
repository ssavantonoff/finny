import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/free_play_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'v13 wing moves from head to back and legacy equipment persists',
    () async {
      final directory = await Directory.systemTemp.createTemp('finny_v14_');
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final path = '${directory.path}/game.sqlite';
      final original = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final db = await original.database;
      final wingProfile = await db.insert('profiles', {
        'game_name': 'Крылья',
        'profile_type': 'NORMAL',
        'onboarding_completed': 1,
        'created_at': '2026-01-01',
      });
      final capProfile = await db.insert('profiles', {
        'game_name': 'Кепка',
        'profile_type': 'NORMAL',
        'onboarding_completed': 1,
        'created_at': '2026-01-01',
      });
      for (final (profileId, itemId) in [
        (wingProfile, 'accessory_hat'),
        (wingProfile, 'accessory_collar'),
        (wingProfile, 'accessory_bow'),
        (capProfile, 'accessory_bow'),
      ]) {
        await db.insert('inventory', {
          'profile_id': profileId,
          'item_id': itemId,
          'quantity': 1,
          'acquired_at': '2026-01-01',
        });
      }
      await original.close();

      final legacy = await databaseFactoryFfi.openDatabase(path);
      await legacy.execute('DROP TABLE free_play_equipped_accessories');
      await legacy.execute('''
      CREATE TABLE free_play_equipped_accessories (
        profile_id INTEGER NOT NULL,
        slot TEXT NOT NULL CHECK (slot IN ('head', 'neck')),
        item_id TEXT NOT NULL,
        PRIMARY KEY (profile_id, slot),
        FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
        FOREIGN KEY (profile_id, item_id)
          REFERENCES inventory(profile_id, item_id) ON DELETE CASCADE
      )
    ''');
      for (final (profileId, slot, itemId) in [
        (wingProfile, 'head', 'accessory_hat'),
        (wingProfile, 'neck', 'accessory_collar'),
        (capProfile, 'head', 'accessory_bow'),
      ]) {
        await legacy.insert('free_play_equipped_accessories', {
          'profile_id': profileId,
          'slot': slot,
          'item_id': itemId,
        });
      }
      await legacy.setVersion(13);
      await legacy.close();

      final upgraded = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(upgraded.close);
      final next = await upgraded.database;
      expect(await next.getVersion(), 14);
      final equipped = FreePlayRepository(upgraded);
      expect(await equipped.equipped(wingProfile), {
        ShopEquipSlot.back: 'accessory_hat',
        ShopEquipSlot.neck: 'accessory_collar',
      });
      expect(await equipped.equipped(capProfile), {
        ShopEquipSlot.head: 'accessory_bow',
      });
      await next.insert('free_play_equipped_accessories', {
        'profile_id': wingProfile,
        'slot': 'head',
        'item_id': 'accessory_bow',
      });
      expect(await equipped.equipped(wingProfile), {
        ShopEquipSlot.head: 'accessory_bow',
        ShopEquipSlot.neck: 'accessory_collar',
        ShopEquipSlot.back: 'accessory_hat',
      });
      expect(await next.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
}
