import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get dark  => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textTheme = AppTypography.getFuezoneTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
      ).copyWith(
        surface: isDark ? AppColors.surface : AppColors.surfaceLight,
        onSurface: isDark ? AppColors.onSurface : AppColors.onBackgroundLight,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
      ),
      scaffoldBackgroundColor:
          isDark ? AppColors.background : AppColors.backgroundLight,
      textTheme: textTheme,
      // Feedback de toque via PressableCard (escala); ripple desativado.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      // Elevado button theme com espaçamento e sombra
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
