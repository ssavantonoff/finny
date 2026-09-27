import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_visual.dart';
import 'package:finny/features/home/home_visual_components.dart';
import 'package:finny/models/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FinnyFlowBackdrop extends StatelessWidget {
  const FinnyFlowBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, AppColors.primaryLight],
            ),
          ),
        ),
      ),
      Positioned(
        top: -95,
        right: -100,
        child: _Bubble(
          size: 250,
          color: AppColors.primary.withValues(alpha: 0.10),
        ),
      ),
      Positioned(
        top: 170,
        left: -125,
        child: _Bubble(
          size: 250,
          color: AppColors.primary.withValues(alpha: 0.08),
        ),
      ),
      Positioned(
        bottom: 100,
        right: -150,
        child: _Bubble(
          size: 280,
          color: AppColors.primary.withValues(alpha: 0.07),
        ),
      ),
      child,
    ],
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class FinnyFlowButton extends StatelessWidget {
  const FinnyFlowButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 58,
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        disabledBackgroundColor: const Color(0xFFB7AEE9),
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        elevation: 5,
        shadowColor: AppColors.primary.withValues(alpha: 0.35),
      ),
      child: Text(label),
    ),
  );
}

class FinnyAmount extends StatelessWidget {
  const FinnyAmount(
    this.amount, {
    this.size = 22,
    this.color = AppColors.textPrimary,
    super.key,
  });
  final String amount;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$amount монет',
    child: ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              amount,
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            FinnyCoin(size: size * 0.9),
          ],
        ),
      ),
    ),
  );
}

/// Reads the active pet through the existing repository and canonical asset resolver.
class CurrentFinnyArt extends ConsumerStatefulWidget {
  const CurrentFinnyArt({
    required this.profileId,
    required this.height,
    super.key,
  });
  final int profileId;
  final double height;

  @override
  ConsumerState<CurrentFinnyArt> createState() => _CurrentFinnyArtState();
}

class _CurrentFinnyArtState extends ConsumerState<CurrentFinnyArt> {
  late Future<Pet?> _pet;

  @override
  void initState() {
    super.initState();
    _pet = ref.read(gameRepositoryProvider).getPet(widget.profileId);
  }

  @override
  void didUpdateWidget(CurrentFinnyArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      _pet = ref.read(gameRepositoryProvider).getPet(widget.profileId);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    child: FutureBuilder<Pet?>(
      future: _pet,
      builder: (context, snapshot) {
        final pet = snapshot.data;
        if (pet == null) return const SizedBox.shrink();
        return Semantics(
          image: true,
          label: FinnyVisual.descriptionForPet(pet),
          child: Image.asset(
            FinnyVisual.assetForPet(pet),
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        );
      },
    ),
  );
}
