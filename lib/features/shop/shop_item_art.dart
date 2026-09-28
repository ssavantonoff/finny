import 'dart:math' as math;

import 'package:finny/models/shop_item.dart';
import 'package:flutter/material.dart';

// Supplied production images have three square panels in one 3:1 PNG.
// Paint-time clipping keeps the source files unmodified.
class ShopItemArt extends StatelessWidget {
  const ShopItemArt({required this.item, super.key});

  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    final standaloneAsset = switch (item.id) {
      'toy_ball' => 'assets/minigames/ball/ball.png',
      'accessory_bow' => 'assets/images/things/cap_wearable.png',
      'accessory_collar' => 'assets/images/things/bandana_wearable.png',
      'accessory_hat' => 'assets/images/things/wings.png',
      'care_shampoo' => 'assets/images/things/shampoo.png',
      'care_comb' => 'assets/images/things/towel.png',
      _ => null,
    };
    if (standaloneAsset != null) {
      return Image.asset(
        standaloneAsset,
        fit: BoxFit.contain,
        semanticLabel: item.name,
      );
    }
    final (sheet, panel) = switch (item.id) {
      'toy_frisbee' => ('assets/images/things/toys_sheet.png', 1),
      'toy_plush' => ('assets/images/things/toys_sheet.png', 2),
      'food_apple' => ('assets/images/things/food_sheet.png', 0),
      'food_feed' => ('assets/images/things/food_sheet.png', 1),
      'food_treat' => ('assets/images/things/food_sheet.png', 2),
      'care_toothbrush' => ('assets/images/things/care_sheet.png', 0),
      'care_shampoo' => ('assets/images/things/care_sheet.png', 1),
      'care_comb' => ('assets/images/things/care_sheet.png', 2),
      _ => (null, -1),
    };
    if (sheet == null) return const SizedBox.expand();

    return Semantics(
      image: true,
      label: item.name,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.min(constraints.maxWidth, constraints.maxHeight);
            return Center(
              child: SizedBox.square(
                dimension: side,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: switch (panel) {
                      0 => Alignment.centerLeft,
                      1 => Alignment.center,
                      _ => Alignment.centerRight,
                    },
                    minWidth: side * 3,
                    maxWidth: side * 3,
                    minHeight: side,
                    maxHeight: side,
                    child: Image.asset(
                      sheet,
                      width: side * 3,
                      height: side,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
