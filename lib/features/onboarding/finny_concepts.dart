import 'package:finny/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class FinnyConcept {
  const FinnyConcept(
    this.title,
    this.description,
    this.example,
    this.accent,
    this.icon,
  );

  final String title;
  final String description;
  final String example;
  final Color accent;
  final IconData icon;
}

const finnyConcepts = [
  FinnyConcept(
    'Нужно',
    'То, без чего Финни трудно обойтись.',
    'Корм • уход',
    AppColors.need,
    Icons.restaurant_rounded,
  ),
  FinnyConcept(
    'Хочу',
    'Приятные покупки, которые можно отложить.',
    'Игрушки • аксессуары',
    AppColors.want,
    Icons.sports_baseball_rounded,
  ),
  FinnyConcept(
    'Копилка',
    'Монеты, которые ты сохраняешь для будущей цели.',
    'Ночник • самокат • домик',
    AppColors.savings,
    Icons.savings_rounded,
  ),
];

class FinnyConceptCard extends StatelessWidget {
  const FinnyConceptCard({
    super.key,
    required this.concept,
    this.showExample = false,
  });

  final FinnyConcept concept;
  final bool showExample;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Color.lerp(Colors.white, concept.accent, 0.09),
      borderRadius: BorderRadius.circular(AppRadii.dialog),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14716CD5),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: concept.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Icon(concept.icon, size: 30, color: concept.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                concept.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: concept.accent,
                ),
              ),
              Text(
                concept.description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              if (showExample) ...[
                const SizedBox(height: AppSpacing.tiny),
                Text(
                  concept.example,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
