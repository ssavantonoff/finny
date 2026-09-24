import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF6C5CE7);
  static const primaryLight = Color(0xFFEEEAFE);
  static const primaryDark = Color(0xFF4F3FD1);
  static const background = Color(0xFFF7F7FC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSecondary = Color(0xFFF2F2FA);
  static const textPrimary = Color(0xFF202231);
  static const textSecondary = Color(0xFF686B7A);
  static const border = Color(0xFFE1E2EC);
  static const success = Color(0xFF4CAF7A);
  static const warning = Color(0xFFF5A623);
  static const error = Color(0xFFE85D6A);
  static const need = Color(0xFF4DA3FF);
  static const want = Color(0xFFF47BA8);
  static const savings = Color(0xFF20B8B0);
  static const satiety = Color(0xFFFFB84D);
  static const care = Color(0xFF4CC9A7);
  static const mood = Color(0xFF7B6CF6);
}

abstract final class AppSpacing {
  static const double tiny = 4;
  static const double small = 8;
  static const double compact = 12;
  static const double medium = 16;
  static const double comfortable = 20;
  static const double large = 24;
  static const double extraLarge = 32;
}

abstract final class AppRadii {
  static const double scene = 28;
  static const double card = 20;
  static const double smallCard = 16;
  static const double button = 18;
  static const double dialog = 24;
}

// Nunito can be bundled later; these styles use the current local font.
abstract final class AppTypography {
  static const textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
  );
}

abstract final class AppTheme {
  static const _seedColor = Color(0xFF4F7DF3);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF8FAFF),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, height: 1.2),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(height: 1.45),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(120, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static ThemeData home(ThemeData base) => base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.surface,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: AppTypography.textTheme,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(120, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.dialog),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.dialog),
        ),
      ),
    ),
  );

  static NavigationBarThemeData get navigation => NavigationBarThemeData(
    backgroundColor: AppColors.surface,
    indicatorColor: AppColors.primaryLight,
    elevation: 0,
    height: 72,
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.textSecondary,
      ),
    ),
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        size: 23,
        color: states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.textSecondary,
      ),
    ),
  );
}
