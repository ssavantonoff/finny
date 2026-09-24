import 'package:flutter/material.dart';

import 'finny_catch_models.dart';

abstract final class FinnyCatchAssets {
  static const finny = 'assets/minigames/finny_catch/finny_stage3.png';
  static const cloud = 'assets/minigames/finny_catch/cloud.png';
  static const atlas = 'assets/minigames/finny_catch/icons_atlas.png';
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
    // The supplied transparent production sheet contains the approved coin and
    // sparkle. Display a region of that sheet without redrawing either asset.
    final source = type == FinnyCatchObjectType.coin
        ? const Rect.fromLTWH(0, 60, 535, 600)
        : const Rect.fromLTWH(975, 60, 485, 600);
    final scale = size / source.height;
    return Semantics(
      image: true,
      label: type == FinnyCatchObjectType.coin ? 'Монета' : 'Звёздочка',
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
