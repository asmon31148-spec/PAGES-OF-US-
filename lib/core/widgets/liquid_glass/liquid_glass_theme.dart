import 'package:flutter/material.dart';
import '../../theme/models/theme_palette.dart';

/// Clean, sharp, zero-blur flat-glass design tokens.
class LiquidGlassTheme {
  static const double blurCard = 0.0;
  static const double blurSheet = 0.0;
  static const double blurPill = 0.0;
  static const double blurMinimal = 0.0;

  static const Color darkCanvas = Color(0xFF0E1016);
  static const Color lightCanvas = Color(0xFFF6F5F2);

  static Color titleColor(bool isDark, [ThemePalette? palette]) =>
      palette?.primaryText ?? (isDark ? const Color(0xFFF5F3F0) : const Color(0xFF1F242D));

  static Color bodyColor(bool isDark, [ThemePalette? palette]) =>
      palette?.primaryText ?? (isDark ? const Color(0xFFE6E3DE) : const Color(0xFF282F3A));

  static Color subtitleColor(bool isDark, [ThemePalette? palette]) =>
      palette?.secondaryText ?? (isDark ? const Color(0xFFA9B1BC) : const Color(0xFF5A6472));

  static Color mutedColor(bool isDark) =>
      isDark ? const Color(0xFF939CA8) : const Color(0xFF6B7482);

  static List<BoxShadow> cardShadow(bool isDark) => const [];

  static List<BoxShadow> glowShadow(Color accentColor) => const [];

  static Color flatSurface(bool isDark, {Color? tint, ThemePalette? palette}) {
    final base = palette?.flatSurfaceColor(isDark) ??
        (isDark
            ? const Color(0xFF171A22).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.90));
    if (tint != null) {
      return Color.alphaBlend(tint.withValues(alpha: isDark ? 0.14 : 0.10), base);
    }
    return base;
  }

  static Border crispBorder(bool isDark, {ThemePalette? palette, Color? color}) {
    final borderCol = color ??
        (palette?.crispBorderColor(isDark) ??
            (isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.10)));
    return Border.all(color: borderCol, width: 1.0);
  }

  static Color chipFill(bool isDark, {bool isSelected = false, Color? accentColor}) {
    final accent = accentColor ?? const Color(0xFF5D7A6E);
    if (isSelected) {
      return accent.withValues(alpha: isDark ? 0.24 : 0.16);
    }
    return isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
  }

  static Border sideBorder(bool isDark, {bool isSelected = false, Color? accentColor}) {
    if (isSelected) {
      return Border.all(color: accentColor ?? const Color(0xFF5D7A6E), width: 1.0);
    }
    return Border.all(
      color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.10),
      width: 1.0,
    );
  }
}
