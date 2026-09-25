import 'dart:math' as math;

import 'package:finny/models/shop_item.dart';
import 'package:flutter/material.dart';

// Supplied production images have three square panels in one 3:1 PNG.
// Paint-time clipping keeps the source files unmodified.
class ThingsItemArt extends StatelessWidget {
  const ThingsItemArt({required this.item, super.key});

  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    if (item.id == 'toy_ball') {
      return Image.asset(
        'assets/minigames/ball/ball.png',
        fit: BoxFit.contain,
        semanticLabel: item.name,
      );
    }
    final (sheet, panel) = switch (item.id) {
      'toy_frisbee' => ('assets/images/things/toys_sheet.png', 1),
      'food_apple' => ('assets/images/things/food_sheet.png', 0),
      'food_feed' => ('assets/images/things/food_sheet.png', 1),
      'food_treat' => ('assets/images/things/food_sheet.png', 2),
      'care_toothbrush' => ('assets/images/things/care_sheet.png', 0),
      'care_shampoo' => ('assets/images/things/care_sheet.png', 1),
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
