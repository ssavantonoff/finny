import 'package:finny/features/shop/shop_item_art.dart';
import 'package:finny/features/shop/shop_widgets.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expected = <String, (String name, String asset, Alignment? alignment)>{
    'food_apple': (
      'Яблоко',
      'assets/images/things/food_sheet.png',
      Alignment.centerLeft,
    ),
    'food_feed': (
      'Корм',
      'assets/images/things/food_sheet.png',
      Alignment.center,
    ),
    'food_treat': (
      'Звёздное печенье',
      'assets/images/things/food_sheet.png',
      Alignment.centerRight,
    ),
    'care_toothbrush': (
      'Зубная щётка',
      'assets/images/things/care_sheet.png',
      Alignment.centerLeft,
    ),
    'care_shampoo': (
      'Шампунь',
      'assets/images/things/care_sheet.png',
      Alignment.center,
    ),
    'care_comb': (
      'Полотенце',
      'assets/images/things/care_sheet.png',
      Alignment.centerRight,
    ),
    'toy_ball': ('Мяч', 'assets/minigames/ball/ball.png', null),
    'toy_frisbee': (
      'Фрисби',
      'assets/images/things/toys_sheet.png',
      Alignment.center,
    ),
    'toy_plush': (
      'Машинка',
      'assets/images/things/toys_sheet.png',
      Alignment.centerRight,
    ),
    'accessory_bow': (
      'Наушники',
      'assets/images/things/accessories_sheet.png',
      Alignment.centerLeft,
    ),
    'accessory_collar': (
      'Очки',
      'assets/images/things/accessories_sheet.png',
      Alignment.center,
    ),
    'accessory_hat': (
      'Крылья',
      'assets/images/things/accessories_sheet.png',
      Alignment.centerRight,
    ),
  };

  testWidgets(
    'all 12 catalog IDs use their final production art in Shop and Things',
    (tester) async {
      final items = await AssetContentRepository().loadShopItems();
      expect(items.map((item) => item.id).toSet(), expected.keys.toSet());

      for (final item in items) {
        final (name, asset, alignment) = expected[item.id]!;
        expect(item.name, name);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox.square(
                  dimension: 100,
                  child: ShopItemArt(item: item),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final image = tester.widget<Image>(find.byType(Image));
        expect((image.image as AssetImage).assetName, asset, reason: item.id);
        expect(image.fit, BoxFit.contain, reason: item.id);
        if (alignment == null) {
          expect(find.byType(OverflowBox), findsNothing);
        } else {
          expect(
            tester.widget<OverflowBox>(find.byType(OverflowBox)).alignment,
            alignment,
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ShopItemIcon(item: item)),
          ),
        );
        expect(find.byType(ShopItemArt), findsOneWidget, reason: item.id);
      }
    },
  );
}
