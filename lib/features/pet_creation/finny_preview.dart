import 'package:flutter/material.dart';

class FinnyPreview extends StatelessWidget {
  const FinnyPreview({
    required this.colorId,
    required this.patternId,
    this.developmentStage = 1,
    super.key,
  });

  final String colorId;
  final String patternId;
  final int developmentStage;

  @override
  Widget build(BuildContext context) {
    final bodyColor = switch (colorId) {
      'purple' => const Color(0xFFAF8BE7),
      'mint' => const Color(0xFF76CEB6),
      _ => const Color(0xFF7FA9EF),
    };
    final accentColor = Color.lerp(bodyColor, Colors.black, 0.22)!;
    final colorName = switch (colorId) {
      'purple' => 'фиолетовый',
      'mint' => 'мятный',
      _ => 'синий',
    };
    final patternName = switch (patternId) {
      'spots' => 'пятнышки',
      'stripes' => 'полоски',
      _ => 'без узора',
    };
    final stage = developmentStage.clamp(1, 3);
    final scale = switch (stage) {
      1 => 0.82,
      2 => 0.92,
      _ => 1.0,
    };

    return Semantics(
      label: 'Финни: $colorName, $patternName, этап $stage',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          height: 225,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 190,
              height: 185,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(top: 4, left: 20, child: _ear(bodyColor, -0.2)),
                  Positioned(top: 4, right: 20, child: _ear(bodyColor, 0.2)),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(72),
                    child: Container(
                      width: 170,
                      height: 155,
                      color: bodyColor,
                      child: Stack(
                        children: [
                          if (patternId == 'spots') ...[
                            _spot(18, 28, 20, accentColor),
                            _spot(112, 18, 26, accentColor),
                            _spot(10, 102, 24, accentColor),
                            _spot(126, 94, 20, accentColor),
                          ],
                          if (patternId == 'stripes') ...[
                            for (final left in [15.0, 52.0, 89.0, 126.0])
                              Positioned(
                                left: left,
                                top: 0,
                                child: Transform.rotate(
                                  angle: 0.18,
                                  child: Container(
                                    width: 14,
                                    height: 160,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                          ],
                          Positioned(top: 62, left: 48, child: _eye()),
                          Positioned(top: 62, right: 48, child: _eye()),
                          Positioned(
                            top: 101,
                            left: 75,
                            child: Container(
                              width: 20,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF354254),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (stage >= 2)
                    Positioned(
                      right: 22,
                      bottom: 18,
                      child: Icon(
                        stage == 3 ? Icons.auto_awesome : Icons.star,
                        size: stage == 3 ? 28 : 22,
                        color: const Color(0xFFFFD166),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ear(Color color, double angle) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 55,
      height: 70,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(25),
      ),
    ),
  );

  Widget _eye() => Container(
    width: 13,
    height: 18,
    decoration: BoxDecoration(
      color: const Color(0xFF354254),
      borderRadius: BorderRadius.circular(10),
    ),
  );

  Widget _spot(double left, double top, double size, Color color) => Positioned(
    left: left,
    top: top,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}
