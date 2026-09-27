import 'dart:io';

import 'package:finny/core/visual/finny_visual.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 27 canonical combinations have unique production PNG assets', () {
    final paths = <String>{};
    for (final stage in [1, 2, 3]) {
      for (final color in FinnyVisual.colors) {
        for (final pattern in FinnyVisual.patterns) {
          final path = FinnyVisual.assetFor(
            developmentStage: stage,
            colorId: color,
            patternId: pattern,
          );
          expect(path, 'assets/images/finny/stage$stage/${color}_$pattern.png');
          expect(File(path).existsSync(), isTrue, reason: path);
          expect(paths.add(path), isTrue);
          expect(path, isNot(contains('neutral')));
        }
      }
    }
    expect(paths, hasLength(27));
  });

  test('legacy values clamp safely without changing persisted data', () {
    expect(
      FinnyVisual.assetFor(
        developmentStage: 0,
        colorId: 'old',
        patternId: 'old',
      ),
      'assets/images/finny/stage1/purple_plain.png',
    );
    expect(
      FinnyVisual.assetFor(
        developmentStage: 4,
        colorId: 'mint',
        patternId: 'stripes',
      ),
      'assets/images/finny/stage3/mint_stripes.png',
    );
  });
}
