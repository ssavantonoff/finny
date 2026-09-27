import 'package:finny/core/visual/finny_visual.dart';
import 'package:flutter/material.dart';

class FinnyPreview extends StatelessWidget {
  const FinnyPreview({
    required this.colorId,
    required this.patternId,
    this.developmentStage = 1,
    this.name = 'Финни',
    this.height = 225,
    super.key,
  });

  final String colorId;
  final String patternId;
  final int developmentStage;
  final String name;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: FinnyVisual.description(
      developmentStage: developmentStage,
      colorId: colorId,
      patternId: patternId,
      name: name,
    ),
    child: SizedBox(
      height: height,
      child: Image.asset(
        FinnyVisual.assetFor(
          developmentStage: developmentStage,
          colorId: colorId,
          patternId: patternId,
        ),
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return const Center(
            child: Icon(Icons.star_rounded, size: 52, color: Color(0xFFB8AEF4)),
          );
        },
      ),
    ),
  );
}
