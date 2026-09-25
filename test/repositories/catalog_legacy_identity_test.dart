import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/free_play_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy inventory and equipped IDs keep their new display identities',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final profile = await SqliteProfileRepository(database).create(
        Profile(
          gameName: 'Игрок',
          profileType: ProfileType.normal,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026),
        ),
      );
      final profileId = profile.id!;
      final games = SqliteGameRepository(database);
      await games.ensureInitialState(profileId);
      final db = await database.database;
      const renamed = {
        'food_treat': 'Звёздное печенье',
        'care_comb': 'Полотенце',
        'toy_plush': 'Машинка',
        'accessory_bow': 'Наушники',
        'accessory_collar': 'Очки',
        'accessory_hat': 'Крылья',
      };
      for (final id in renamed.keys) {
        await db.insert('inventory', {
          'profile_id': profileId,
          'item_id': id,
          'quantity': 2,
          'acquired_at': DateTime.utc(2026).toIso8601String(),
        });
      }
      await db.insert('free_play_equipped_accessories', {
        'profile_id': profileId,
        'slot': 'head',
        'item_id': 'accessory_bow',
      });
      await db.insert('free_play_equipped_accessories', {
        'profile_id': profileId,
        'slot': 'neck',
        'item_id': 'accessory_collar',
      });

      final content = {
        for (final item in await AssetContentRepository().loadShopItems())
          item.id: item,
      };
      for (final entry in renamed.entries) {
        expect(content[entry.key]!.name, entry.value);
        expect(await games.getInventoryQuantity(profileId, entry.key), 2);
      }
      expect(content['accessory_bow']!.equipSlot, ShopEquipSlot.head);
      expect(content['accessory_collar']!.equipSlot, ShopEquipSlot.neck);
      expect(await FreePlayRepository(database).equipped(profileId), {
        ShopEquipSlot.head: 'accessory_bow',
        ShopEquipSlot.neck: 'accessory_collar',
      });
    },
  );
}
