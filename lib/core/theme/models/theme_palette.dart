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

  /// Flat, calm semi-transparent surface color for sharp crisp cards.
  Color flatSurfaceColor(bool isDark) =>
      cardBackground.withValues(alpha: isDark ? 0.88 : 0.94);

  /// Clean 1px hairline border color without gradient sheen or glow.
  Color crispBorderColor(bool isDark) =>
      dividerColor.withValues(alpha: isDark ? 0.85 : 0.90);
}
