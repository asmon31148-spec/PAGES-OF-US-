import 'package:flutter/material.dart';

/// Immutable color palette defining a theme's appearance in a specific brightness mode
class ThemePalette {
  /// 3 to 4 gradient colors forming the living atmospheric background
  final List<Color> gradientColors;

  /// Frosted glass tint color & opacity
  final Color glassTint;
  final double glassOpacity;

  /// High-contrast typography roles (WCAG AA >= 4.5:1 compliant)
  final Color primaryText;
  final Color secondaryText;

  /// Vibrant brand accent, icon, and structural dividing lines
  final Color accentColor;
  final Color iconColor;
  final Color dividerColor;

  /// Base canvas tone behind the atmospheric mesh
  final Color canvasBackground;

  /// Solid/translucent base surface of cards
  final Color cardBackground;

  /// Top-left specular rim reflection highlight
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

  /// Linear gradient for living cards and floating surfaces
  LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          cardBackground.withOpacity(0.94),
          cardBackground.withOpacity(0.90),
        ],
      );

  /// 1px specular light rim border catching light on top-left
  LinearGradient get specularBorderGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          specularBorderColor.withOpacity(specularBorderOpacity),
          specularBorderColor.withOpacity(specularBorderOpacity * 0.45),
          specularBorderColor.withOpacity(0.04),
        ],
      );
}
