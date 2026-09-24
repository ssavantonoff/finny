import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/virtual_day_rules.dart';
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
          color: AppColors.surface.withValues(alpha: 0.93),
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

class HomeSceneBackdrop extends StatelessWidget {
  const HomeSceneBackdrop({super.key, required this.child, this.phase});

  final Widget child;
  final VirtualDayPhase? phase;

  List<Color> get _tintColors => switch (phase) {
    VirtualDayPhase.morning => const [Color(0x14FFE1EE), Color(0x0CFFE8DE)],
    VirtualDayPhase.daytime => const [Color(0x14FFFFFF), Color(0x0AFFFFFF)],
    VirtualDayPhase.evening => const [Color(0x287773B4), Color(0x168A78AE)],
    null => const [Color(0x1FFFFFFF), Color(0x1FFFFFFF)],
  };

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        'assets/images/home/room_base.png',
        key: const Key('home-room-background'),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
      DecoratedBox(
        key: const Key('home-room-phase-tint'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _tintColors,
          ),
        ),
      ),
      child,
    ],
  );
}

class FinnyNameBadge extends StatelessWidget {
  const FinnyNameBadge({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.93),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: AppColors.textPrimary),
      ),
    ),
  );
}

class FinnyRoomScene extends StatelessWidget {
  const FinnyRoomScene({
    super.key,
    required this.pet,
    this.showBackground = true,
  });

  final Pet pet;
  final bool showBackground;

  static String assetForStage(int stage) => switch (stage.clamp(1, 3)) {
    1 => 'assets/images/home/finny_stage1_neutral.png',
    2 => 'assets/images/home/finny_stage2_neutral.png',
    _ => 'assets/images/home/finny_stage3_neutral.png',
  };

  @override
  Widget build(BuildContext context) {
    final stage = pet.developmentStage.clamp(1, 3);
    final roomHeight = (MediaQuery.sizeOf(context).height * 0.43).clamp(
      300.0,
      420.0,
    );
    final finnyHeight =
        roomHeight *
        switch (stage) {
          1 => 0.62,
          2 => 0.69,
          _ => 0.76,
        };
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.scene),
      child: SizedBox(
        key: const Key('home-room-scene'),
        height: showBackground ? roomHeight : finnyHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showBackground)
              Image.asset(
                'assets/images/home/room_base.png',
                key: const Key('home-room-background'),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            Align(
              alignment: showBackground
                  ? const Alignment(0, 0.87)
                  : Alignment.bottomCenter,
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
    color: AppColors.surface.withValues(alpha: 0.93),
    child: Padding(
      padding: EdgeInsets.all(
        MediaQuery.sizeOf(context).height < 700 ? 6 : AppSpacing.small,
      ),
      child: Row(
        children: [
          const _GoalIcon(),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (MediaQuery.sizeOf(context).height >= 700)
                  Text(
                    'Текущая цель',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: AppColors.textPrimary),
                ),
                Row(
                  children: [
                    Text(
                      '$saved/$price',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: AppSpacing.tiny),
                    const FinnyCoin(size: 16),
                  ],
                ),
                const SizedBox(height: AppSpacing.tiny),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: price > 0 ? (saved / price).clamp(0.0, 1.0) : 0,
                    minHeight: 6,
                    color: AppColors.primary,
                    backgroundColor: AppColors.primaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          TextButton(
            style: _goalActionStyle(),
            onPressed: () => context.go('/savings'),
            child: const Text('К цели'),
          ),
        ],
      ),
    ),
  );
}

class _GoalIcon extends StatelessWidget {
  const _GoalIcon();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const SizedBox(
      width: 48,
      height: 48,
      child: Icon(Icons.savings_rounded, color: AppColors.primary),
    ),
  );
}

ButtonStyle _goalActionStyle() => TextButton.styleFrom(
  backgroundColor: AppColors.primaryLight,
  foregroundColor: AppColors.primaryDark,
  minimumSize: const Size(0, 40),
  padding: const EdgeInsets.symmetric(horizontal: 8),
  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  shape: const StadiumBorder(),
);

class HomeNoGoalCard extends StatelessWidget {
  const HomeNoGoalCard({
    super.key,
    required this.saved,
    this.title = 'Цель не выбрана',
    this.onSelect,
  });

  final int saved;
  final String title;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('home-savings-goal'),
    color: AppColors.surface.withValues(alpha: 0.93),
    child: Padding(
      padding: EdgeInsets.all(
        MediaQuery.sizeOf(context).height < 700 ? 6 : AppSpacing.small,
      ),
      child: Row(
        children: [
          const _GoalIcon(),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: AppColors.textPrimary),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Накоплено: $saved',
                        key: const Key('home-saved-without-goal'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.tiny),
                    const FinnyCoin(size: 16),
                  ],
                ),
              ],
            ),
          ),
          if (onSelect != null) ...[
            const SizedBox(width: AppSpacing.small),
            TextButton(
              style: _goalActionStyle(),
              onPressed: onSelect,
              child: const Text('Выбрать цель'),
            ),
          ],
        ],
      ),
    ),
  );
}
