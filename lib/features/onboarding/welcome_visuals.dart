import 'package:finny/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class WelcomeBackground extends StatelessWidget {
  const WelcomeBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFDFDFF), Color(0xFFF1EEFF)],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          left: -130,
          top: 80,
          child: _orb(270, const Color(0xFFE5E0FF)),
        ),
        Positioned(
          right: -100,
          top: 280,
          child: _orb(240, const Color(0xFFE8E2FF)),
        ),
        Positioned(
          left: -80,
          bottom: 120,
          child: _orb(170, const Color(0xFFF0E9FF)),
        ),
        child,
      ],
    ),
  );

  Widget _orb(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: 0.6),
    ),
  );
}

class FinnyBrand extends StatelessWidget {
  const FinnyBrand({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Finny',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 38,
          fontWeight: FontWeight.w900,
          letterSpacing: -2,
        ),
      ),
      Icon(Icons.star_rounded, color: Color(0xFFFFC44F), size: 25),
    ],
  );
}

class WelcomeProgress extends StatelessWidget {
  const WelcomeProgress({required this.step, super.key});

  final int step;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 144,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x206C5CE7),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var index = 0; index < 3; index++) ...[
              if (index > 0) const SizedBox(width: 7),
              Expanded(
                child: Container(
                  height: 9,
                  decoration: BoxDecoration(
                    color: index == step
                        ? AppColors.primary
                        : const Color(0xFFE1DDF4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Шаг ${step + 1} из 3',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class WelcomeButton extends StatelessWidget {
  const WelcomeButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      disabledBackgroundColor: const Color(0xFFB8AEF4),
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 62),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      elevation: onPressed == null ? 0 : 7,
      shadowColor: AppColors.primary.withValues(alpha: 0.32),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
    ),
  );
}

InputDecoration welcomeInputDecoration({required String hint, String? error}) =>
    InputDecoration(
      hintText: hint,
      errorText: error,
      hintStyle: const TextStyle(color: Color(0xFF9997AE)),
      filled: true,
      fillColor: const Color(0xFFF7F5FF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Color(0xFFDCD5FF), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Color(0xFFDCD5FF), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
