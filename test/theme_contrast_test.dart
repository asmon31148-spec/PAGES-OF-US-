import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pages_of_us/core/theme/theme_registry.dart';
import 'package:pages_of_us/core/theme/models/app_theme_data.dart';
import 'package:pages_of_us/core/theme/models/theme_palette.dart';

/// Calculates WCAG 2.1 relative luminance for a given color
double calculateRelativeLuminance(Color color) {
  double transform(double channel) {
    if (channel <= 0.04045) {
      return channel / 12.92;
    } else {
      return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
    }
  }

  final r = transform(color.red / 255.0);
  final g = transform(color.green / 255.0);
  final b = transform(color.blue / 255.0);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Calculates WCAG 2.1 contrast ratio between two colors
double calculateContrastRatio(Color foreground, Color background) {
  final l1 = calculateRelativeLuminance(foreground);
  final l2 = calculateRelativeLuminance(background);

  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);

  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('Shared Live Theme System - WCAG AA Contrast Tests', () {
    test('Registry contains all 13 themes', () {
      expect(ThemeRegistry.allThemes.length, 13);
    });

    for (final theme in ThemeRegistry.allThemes) {
      test('Theme "${theme.name}" (${theme.id}) passes WCAG AA (>= 4.5:1) in Light Mode', () {
        final palette = theme.lightPalette;
        final ratio = calculateContrastRatio(palette.primaryText, palette.cardBackground);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'Theme ${theme.id} light mode primaryText (${palette.primaryText}) vs cardBackground (${palette.cardBackground}) had contrast ratio $ratio, which is less than 4.5:1',
        );
      });

      test('Theme "${theme.name}" (${theme.id}) passes WCAG AA (>= 4.5:1) in Dark Mode', () {
        final palette = theme.darkPalette;
        final ratio = calculateContrastRatio(palette.primaryText, palette.cardBackground);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'Theme ${theme.id} dark mode primaryText (${palette.primaryText}) vs cardBackground (${palette.cardBackground}) had contrast ratio $ratio, which is less than 4.5:1',
        );
      });
    }
  });
}
