import 'package:finny/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Shared presentation styles for the short actions inside Finny dialogs.
abstract final class FinnyModalActions {
  static final ButtonStyle primary = FilledButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    disabledBackgroundColor: const Color(0xFFB7AEE9),
    disabledForegroundColor: Colors.white70,
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    shape: const StadiumBorder(),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
  );

  static final ButtonStyle secondary = TextButton.styleFrom(
    foregroundColor: AppColors.primaryDark,
    disabledForegroundColor: AppColors.textSecondary,
    backgroundColor: AppColors.primaryLight,
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    shape: const StadiumBorder(),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
  );
}
