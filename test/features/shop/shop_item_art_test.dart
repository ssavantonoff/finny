import 'dart:ui' as ui;

import 'package:finny/features/shop/shop_item_art.dart';
import 'package:finny/features/shop/shop_widgets.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    'care_shampoo': ('Шампунь', 'assets/images/things/shampoo.png', null),
    'care_comb': ('Полотенце', 'assets/images/things/towel.png', null),
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
    'accessory_bow': ('Наушники', 'assets/images/things/headphones.png', null),
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
        if (item.id == 'accessory_bow') {
          final scale = tester.widget<Transform>(
            find.byKey(const Key('shop-item-art-headphones-scale')),
          );
          final position = tester.widget<Transform>(
            find.byKey(const Key('shop-item-art-headphones-position')),
          );
          expect(scale.transform.getMaxScaleOnAxis(), closeTo(1.22, 0.001));
          expect(position.transform.getTranslation().x, greaterThan(0));
        } else {
          expect(
            find.byKey(const Key('shop-item-art-headphones-scale')),
            findsNothing,
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

  test('standalone product art keeps transparent pixels', () async {
    for (final asset in [
      'assets/images/things/headphones.png',
      'assets/images/things/shampoo.png',
      'assets/images/things/towel.png',
    ]) {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      final pixels = (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      var hasTransparentPixel = false;
      var hasVisiblePixel = false;
      for (var index = 3; index < pixels.length; index += 4) {
        hasTransparentPixel |= pixels[index] == 0;
        hasVisiblePixel |= pixels[index] > 200;
        if (hasTransparentPixel && hasVisiblePixel) break;
      }
      expect(hasTransparentPixel, isTrue, reason: asset);
      expect(hasVisiblePixel, isTrue, reason: asset);
      frame.image.dispose();
      codec.dispose();
    }
  });
}
