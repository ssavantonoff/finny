import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/models/pet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FinnyCoin extends StatelessWidget {
  const FinnyCoin({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFFFC44F),
    ),
    padding: EdgeInsets.all(size * 0.15),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryDark,
      ),
      child: Icon(
        Icons.star_rounded,
        color: const Color(0xFFFFC44F),
        size: size * 0.56,
      ),
    ),
  );
}

class HomeWallet extends StatelessWidget {
  const HomeWallet({super.key, required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$balance монет',
    child: ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FinnyCoin(),
              const SizedBox(width: AppSpacing.small),
              Text(
                '$balance',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class FinnyRoomScene extends StatelessWidget {
  const FinnyRoomScene({super.key, required this.pet});

  final Pet pet;

  static String assetForStage(int stage) => switch (stage.clamp(1, 3)) {
    1 => 'assets/images/home/finny_stage1_neutral.png',
    2 => 'assets/images/home/finny_stage2_neutral.png',
    _ => 'assets/images/home/finny_stage3_neutral.png',
  };

  @override
  Widget build(BuildContext context) {
    final stage = pet.developmentStage.clamp(1, 3);
    final sceneHeight = (MediaQuery.sizeOf(context).height * 0.43).clamp(
      300.0,
      420.0,
    );
    final finnyHeight =
        sceneHeight *
        switch (stage) {
          1 => 0.62,
          2 => 0.69,
          _ => 0.76,
        };
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.scene),
      child: SizedBox(
        key: const Key('home-room-scene'),
        height: sceneHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/home/room_base.png',
              key: const Key('home-room-background'),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            Align(
              alignment: const Alignment(0, 0.87),
              child: SizedBox(
                height: finnyHeight,
                child: Image.asset(
                  assetForStage(stage),
                  key: Key('home-finny-stage-$stage'),
                  fit: BoxFit.contain,
                  semanticLabel: '${pet.name}, стадия $stage',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeGoalCard extends StatelessWidget {
  const HomeGoalCard({
    super.key,
    required this.name,
    required this.saved,
    required this.price,
  });

  final String name;
  final int saved;
  final int price;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('home-savings-goal'),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_rounded, color: AppColors.savings),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '$saved/$price',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: AppSpacing.tiny),
              const FinnyCoin(size: 18),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: price > 0 ? (saved / price).clamp(0.0, 1.0) : 0,
              minHeight: 8,
              color: AppColors.savings,
              backgroundColor: AppColors.surfaceSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/savings'),
              child: const Text('К цели'),
            ),
          ),
        ],
      ),
    ),
  );
}
