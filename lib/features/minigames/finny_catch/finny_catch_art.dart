import 'package:flutter/material.dart';

import 'finny_catch_models.dart';

abstract final class FinnyCatchAssets {
  static const cloud = 'assets/minigames/finny_catch/cloud.png';
  static const atlas = 'assets/minigames/finny_catch/icons_atlas.png';
  static const sparkle = 'assets/minigames/finny_catch/sparkle.png';
}

class FinnyCatchArt extends StatelessWidget {
  const FinnyCatchArt({required this.type, required this.size, super.key});

  final FinnyCatchObjectType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (type == FinnyCatchObjectType.cloud) {
      return Image.asset(
        FinnyCatchAssets.cloud,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Облако',
      );
    }
    if (type == FinnyCatchObjectType.sparkle) {
      return Image.asset(
        FinnyCatchAssets.sparkle,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Звёздочка',
      );
    }
    // The approved coin still comes from the existing production sheet.
    const source = Rect.fromLTWH(0, 60, 535, 600);
    final scale = size / source.height;
    return Semantics(
      image: true,
      label: 'Монета',
      child: SizedBox(
        width: source.width * scale,
        height: size,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -source.left * scale,
                top: -source.top * scale,
                width: 2172 * scale,
                height: 724 * scale,
                child: Image.asset(
                  FinnyCatchAssets.atlas,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
