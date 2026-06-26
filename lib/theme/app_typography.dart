import 'package:flutter/material.dart';

/// Centralized text hierarchy for Fuezone.
/// Creates a TextTheme with display, headline, title, body, label, and caption styles.
/// All styles use system font (Roboto by default in Material).
abstract final class AppTypography {
  static TextTheme getFuezoneTextTheme() {
    return TextTheme(
      // Display: Hero numbers (timer, scores)
      displayLarge: _buildStyle(
        fontSize: 56,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 1.2,
      ),
      displayMedium: _buildStyle(
        fontSize: 48,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 1.2,
      ),
      displaySmall: _buildStyle(
        fontSize: 40,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
        height: 1.2,
      ),

      // Headline: Screen titles, main actions
      headlineLarge: _buildStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        height: 1.3,
      ),
      headlineMedium: _buildStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        height: 1.3,
      ),
      headlineSmall: _buildStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.3,
      ),

      // Title: Card headers, section labels
      titleLarge: _buildStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.3,
      ),
      titleMedium: _buildStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        height: 1.3,
      ),
      titleSmall: _buildStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.3,
      ),

      // Body: Main text, descriptions
      bodyLarge: _buildStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      bodyMedium: _buildStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.25,
        height: 1.5,
      ),
      bodySmall: _buildStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        height: 1.5,
      ),

      // Label: Buttons, form labels, captions
      labelLarge: _buildStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
      ),
      labelMedium: _buildStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.4,
      ),
      labelSmall: _buildStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.4,
      ),
    );
  }

  /// Build a TextStyle with optional tabularFigures for number consistency.
  static TextStyle _buildStyle({
    required double fontSize,
    required FontWeight fontWeight,
    double letterSpacing = 0,
    double height = 1,
    bool tabularFigures = false,
  }) {
    final fontFeatures = tabularFigures
        ? [const FontFeature.tabularFigures()]
        : <FontFeature>[];

    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: fontFeatures,
    );
  }

  /// Convenience getter: displayLarge with tabularFigures for timer numbers.
  static TextStyle get displayLargeTabular => _buildStyle(
        fontSize: 56,
        fontWeight: FontWeight.w900,
        tabularFigures: true,
      );

  /// Convenience getter: headlineLarge with tabularFigures.
  static TextStyle get headlineLargeTabular => _buildStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        tabularFigures: true,
      );
}
