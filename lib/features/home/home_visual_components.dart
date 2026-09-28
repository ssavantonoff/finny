import 'dart:async';
import 'dart:math' as math;

import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_visual.dart';
import 'package:finny/features/home/home_room_visual.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_art.dart';
import 'package:finny/features/minigames/finny_catch/finny_catch_models.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/shop_item.dart';
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

class FreePlayCatchCard extends StatelessWidget {
  const FreePlayCatchCard({super.key, required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('free-play-finny-catch'),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.primaryDark, AppColors.primary],
      ),
      borderRadius: BorderRadius.circular(AppRadii.card),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          const FinnyCatchArt(type: FinnyCatchObjectType.coin, size: 44),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Лови монеты',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: Colors.white),
                ),
                Text(
                  'Играй с Финни и зарабатывай монеты',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.tiny),
          FilledButton(
            key: const Key('free-play-finny-catch-play'),
            onPressed: onPlay,
            style: FilledButton.styleFrom(
              minimumSize: const Size(68, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDark,
            ),
            child: const Text('Играть'),
          ),
        ],
      ),
    ),
  );
}

class HomeWallet extends StatelessWidget {
  const HomeWallet({super.key, required this.balance, this.compact = false});

  final int balance;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$balance монет',
    child: ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
        ),
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 4 : 7,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FinnyCoin(size: compact ? 18 : 22),
                SizedBox(width: compact ? AppSpacing.tiny : AppSpacing.small),
                Text(
                  '$balance',
                  style:
                      (compact
                              ? Theme.of(context).textTheme.bodyLarge
                              : Theme.of(context).textTheme.titleLarge)
                          ?.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class HomeSceneBackdrop extends StatelessWidget {
  const HomeSceneBackdrop({
    super.key,
    required this.child,
    this.phase,
    this.roomAsset = 'assets/images/home/room_base.png',
  });

  final Widget child;
  final VirtualDayPhase? phase;
  final String roomAsset;

  List<Color> get _tintColors => switch (phase) {
    VirtualDayPhase.morning => const [Color(0x14FFE1EE), Color(0x0CFFE8DE)],
    VirtualDayPhase.daytime => const [Color(0x14FFFFFF), Color(0x0AFFFFFF)],
    VirtualDayPhase.evening => const [Color(0x46665FB5), Color(0x38736DB3)],
    null => const [Color(0x1FFFFFFF), Color(0x1FFFFFFF)],
  };

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      AnimatedSwitcher(
        key: const Key('home-room-background'),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        child: Image.asset(
          roomAsset,
          key: ValueKey(roomAsset),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          excludeFromSemantics: true,
        ),
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
  const FinnyNameBadge({super.key, required this.name, this.compact = false});

  final String name;
  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            (compact
                    ? Theme.of(context).textTheme.bodyMedium
                    : Theme.of(context).textTheme.bodyLarge)
                ?.copyWith(color: AppColors.textPrimary),
      ),
    ),
  );
}

class FinnyRoomScene extends StatefulWidget {
  const FinnyRoomScene({
    super.key,
    required this.pet,
    this.showBackground = true,
    this.equippedAccessories = const {},
    this.petReactionToken = 0,
  });

  final Pet pet;
  final bool showBackground;
  final Map<ShopEquipSlot, String> equippedAccessories;
  final int petReactionToken;

  @override
  State<FinnyRoomScene> createState() => _FinnyRoomSceneState();
}

class _FinnyRoomSceneState extends State<FinnyRoomScene>
    with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..addStatusListener(_idleStatus);
  late final AnimationController _petReaction = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  Timer? _idleTimer;
  bool _animationsDisabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled == _animationsDisabled && _idleTimer != null) return;
    _animationsDisabled = disabled;
    _idleTimer?.cancel();
    if (disabled) {
      _idle.stop();
      _idle.value = 0;
      _petReaction.stop();
      _petReaction.value = 0;
    } else {
      _idleTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && !_animationsDisabled) _idle.forward();
      });
    }
  }

  void _idleStatus(AnimationStatus status) {
    if (_animationsDisabled || !mounted) return;
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      _idleTimer?.cancel();
      _idleTimer = Timer(const Duration(milliseconds: 16), () {
        if (!mounted || _animationsDisabled) return;
        if (status == AnimationStatus.completed) {
          _idle.reverse();
        } else {
          _idle.forward();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant FinnyRoomScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.petReactionToken > oldWidget.petReactionToken &&
        !_animationsDisabled) {
      _petReaction.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _idle.dispose();
    _petReaction.dispose();
    super.dispose();
  }

  double get _reactionScale => TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.03), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.03, end: 0.99), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 0.99, end: 1), weight: 25),
  ]).transform(_petReaction.value);

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final stage = pet.developmentStage.clamp(1, 3);
    final accessories = HomeRoomVisual.accessoriesFor(
      widget.equippedAccessories,
    );
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
    final scene = SizedBox(
      key: const Key('home-room-scene'),
      height: widget.showBackground ? roomHeight : finnyHeight,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final aspect = HomeRoomVisual.petAspectRatio(stage);
          final canvasWidth = math.min(
            finnyHeight * aspect,
            constraints.maxWidth,
          );
          return Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              if (widget.showBackground)
                Image.asset(
                  'assets/images/home/room_base.png',
                  key: const Key('home-room-background'),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              Align(
                alignment: widget.showBackground
                    ? const Alignment(0, 0.87)
                    : Alignment.bottomCenter,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_idle, _petReaction]),
                  builder: (context, child) {
                    final sway = Curves.easeInOut.transform(_idle.value);
                    return Transform.translate(
                      key: const Key('home-finny-motion'),
                      offset: Offset(0, -3 * sway),
                      child: Transform.scale(
                        scale: (1 + 0.012 * sway) * _reactionScale,
                        child: child,
                      ),
                    );
                  },
                  child: SizedBox(
                    key: const Key('home-finny-canvas'),
                    width: canvasWidth,
                    height: canvasWidth / aspect,
                    child: LayoutBuilder(
                      builder: (context, canvas) => Stack(
                        clipBehavior: Clip.none,
                        fit: StackFit.expand,
                        children: [
                          for (final visual in HomeRoomVisual.accessories.where(
                            (visual) => visual.behindPet,
                          ))
                            _accessorySlot(
                              visual,
                              accessories,
                              stage,
                              canvas.biggest,
                            ),
                          Image.asset(
                            FinnyVisual.assetForPet(pet),
                            key: Key('home-finny-stage-$stage'),
                            fit: BoxFit.contain,
                            semanticLabel: FinnyVisual.descriptionForPet(pet),
                          ),
                          for (final slot in [
                            ShopEquipSlot.neck,
                            ShopEquipSlot.head,
                          ])
                            for (final visual
                                in HomeRoomVisual.accessories.where(
                                  (visual) =>
                                      visual.slot == slot && !visual.behindPet,
                                ))
                              _accessorySlot(
                                visual,
                                accessories,
                                stage,
                                canvas.biggest,
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    return widget.showBackground
        ? ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.scene),
            child: scene,
          )
        : scene;
  }

  static Rect _scaledRect(Rect rect, Size canvas) => Rect.fromLTWH(
    rect.left * canvas.width,
    rect.top * canvas.height,
    rect.width * canvas.width,
    rect.height * canvas.height,
  );

  Widget _accessorySlot(
    HomeAccessoryVisual visual,
    List<HomeAccessoryVisual> equipped,
    int stage,
    Size canvas,
  ) => Positioned.fromRect(
    rect: _scaledRect(visual.anchorFor(stage), canvas),
    child: AnimatedSwitcher(
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      duration: _animationsDisabled
          ? Duration.zero
          : const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: equipped.contains(visual)
          ? Image.asset(
              visual.asset,
              key: Key('home-accessory-${visual.itemId}'),
              fit: visual.behindPet ? BoxFit.fill : BoxFit.contain,
              excludeFromSemantics: true,
            )
          : SizedBox(key: Key('home-accessory-empty-${visual.itemId}')),
    ),
  );
}

class HomeGoalCard extends StatelessWidget {
  const HomeGoalCard({
    super.key,
    required this.name,
    required this.saved,
    required this.price,
    this.compact = false,
  });

  final String name;
  final int saved;
  final int price;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('home-savings-goal'),
    color: AppColors.surface.withValues(alpha: 0.84),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : AppSpacing.small,
        vertical: compact ? 2 : AppSpacing.small,
      ),
      child: Row(
        children: [
          _GoalIcon(compact: compact),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!compact)
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
                SizedBox(height: compact ? 2 : AppSpacing.tiny),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: price > 0 ? (saved / price).clamp(0.0, 1.0) : 0,
                    minHeight: compact ? 4 : 6,
                    color: AppColors.primary,
                    backgroundColor: AppColors.primaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          TextButton(
            style: _goalActionStyle(compact),
            onPressed: () => context.go('/savings'),
            child: const Text('К цели'),
          ),
        ],
      ),
    ),
  );
}

class _GoalIcon extends StatelessWidget {
  const _GoalIcon({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(compact ? 14 : 16),
    ),
    child: SizedBox(
      width: compact ? 40 : 48,
      height: compact ? 40 : 48,
      child: const Icon(Icons.savings_rounded, color: AppColors.primary),
    ),
  );
}

ButtonStyle _goalActionStyle(bool compact) => TextButton.styleFrom(
  backgroundColor: AppColors.primaryLight,
  foregroundColor: AppColors.primaryDark,
  minimumSize: Size(0, compact ? 36 : 40),
  padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
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
    this.compact = false,
  });

  final int saved;
  final String title;
  final VoidCallback? onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('home-savings-goal'),
    color: AppColors.surface.withValues(alpha: 0.84),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : AppSpacing.small,
        vertical: compact ? 2 : AppSpacing.small,
      ),
      child: Row(
        children: [
          _GoalIcon(compact: compact),
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
              style: _goalActionStyle(compact),
              onPressed: onSelect,
              child: const Text('Выбрать цель'),
            ),
          ],
        ],
      ),
    ),
  );
}
