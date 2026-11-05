import 'package:flutter/material.dart';
import 'theme_palette.dart';

enum ThemeAnimationStyle {
  flowingBlobs,
  slowGradientShift,
}

enum ThemePerformanceLevel {
  full,
  balanced,
  batterySaver;

  static ThemePerformanceLevel fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'battery_saver':
      case 'batterysaver':
        return ThemePerformanceLevel.batterySaver;
      case 'balanced':
        return ThemePerformanceLevel.balanced;
      case 'full':
      default:
        return ThemePerformanceLevel.full;
    }
  }

  String toDbString() {
    switch (this) {
      case ThemePerformanceLevel.batterySaver:
        return 'battery_saver';
      case ThemePerformanceLevel.balanced:
        return 'balanced';
      case ThemePerformanceLevel.full:
        return 'full';
    }
  }

  String get displayName {
    switch (this) {
      case ThemePerformanceLevel.full:
        return 'Full Magic';
      case ThemePerformanceLevel.balanced:
        return 'Balanced';
      case ThemePerformanceLevel.batterySaver:
        return 'Battery Saver';
    }
  }

  String get description {
    switch (this) {
      case ThemePerformanceLevel.full:
        return 'Living moving blobs & subtle organic drift at 30 fps';
      case ThemePerformanceLevel.balanced:
        return 'Gentle slow ambient pulse with lower GPU cycles';
      case ThemePerformanceLevel.batterySaver:
        return 'Static frozen gradient with zero animation overhead';
    }
  }
}

/// Immutable definition of a romantic living couple theme
class AppThemeData {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final ThemePalette lightPalette;
  final ThemePalette darkPalette;
  final ThemeAnimationStyle animationStyle;
  final double animationSpeed;
  final double blurRadius;

  const AppThemeData({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.lightPalette,
    required this.darkPalette,
    this.animationStyle = ThemeAnimationStyle.flowingBlobs,
    this.animationSpeed = 1.0,
    this.blurRadius = 32.0,
  });

  ThemePalette palette(bool isDark) => isDark ? darkPalette : lightPalette;
}
