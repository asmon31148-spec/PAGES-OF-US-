import 'package:flutter/material.dart';

/// Immutable color palette defining a theme's appearance in a specific brightness mode.
class ThemePalette {
  final List<Color> gradientColors;
  final Color glassTint;
  final double glassOpacity;
  final Color primaryText;
  final Color secondaryText;
  final Color accentColor;
  final Color iconColor;
  final Color dividerColor;
  final Color canvasBackground;
  final Color cardBackground;
  final Color specularBorderColor;
  final double specularBorderOpacity;

  const ThemePalette({
    required this.gradientColors,
    required this.glassTint,
    required this.glassOpacity,
    required this.primaryText,
    required this.secondaryText,
    required this.accentColor,
    required this.iconColor,
    required this.dividerColor,
    required this.canvasBackground,
    required this.cardBackground,
    required this.specularBorderColor,
    required this.specularBorderOpacity,
  });

  /// Flat, calm semi-transparent surface color tinted subtly by the active theme.
  Color flatSurfaceColor(bool isDark) {
    final tint = gradientColors.isNotEmpty ? gradientColors.first : accentColor;
    final blended = Color.alphaBlend(tint.withValues(alpha: isDark ? 0.08 : 0.05), cardBackground);
    return blended.withValues(alpha: isDark ? 0.88 : 0.94);
  }

  /// Clean 1px hairline border color tuned to the active theme's accent.
  Color crispBorderColor(bool isDark) =>
      Color.alphaBlend(accentColor.withValues(alpha: isDark ? 0.26 : 0.20), dividerColor);
}
