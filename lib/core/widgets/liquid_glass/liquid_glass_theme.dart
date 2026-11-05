import 'package:flutter/material.dart';
import '../../theme/models/theme_palette.dart';

/// Centralized Apple iOS 26 Liquid Glass Design System tokens.
/// Standardizes glass refraction, blur sigma, specular rim gradients,
/// tinted glass surfaces, and warm floating depth across both Light and Dark modes.
class LiquidGlassTheme {
  // Blur constants (16 to 24 sigma for cards & pills, 24 to 30 for sheets)
  static const double blurCard = 18.0;
  static const double blurSheet = 26.0;
  static const double blurPill = 16.0;
  static const double blurMinimal = 12.0;

  // Background deep tones
  static const Color darkCanvas = Color(0xFF0C0E14);
  static const Color lightCanvas = Color(0xFFFAF7F2); // Warm ivory pastel canvas

  // Typography Tokens with guaranteed contrast
  static Color titleColor(bool isDark, [ThemePalette? palette]) =>
      palette?.primaryText ?? (isDark ? const Color(0xFFFBFBFC) : const Color(0xFF181A20));

  static Color bodyColor(bool isDark, [ThemePalette? palette]) =>
      palette?.primaryText ?? (isDark ? const Color(0xFFE5E7EB) : const Color(0xFF2D313A));

  static Color subtitleColor(bool isDark, [ThemePalette? palette]) =>
      palette?.secondaryText ?? (isDark ? const Color(0xFFA5ACB8) : const Color(0xFF5E6778));

  static Color mutedColor(bool isDark) =>
      isDark ? const Color(0x80FFFFFF) : const Color(0x8A181A20);

  // Card Ambient Shadow (Soft low-opacity warm tint in light mode, no hard grey)
  static List<BoxShadow> cardShadow(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withOpacity(0.38)
              : const Color(0xFFB89578).withOpacity(0.14), // Soft warm peach/caramel tint
          blurRadius: 18,
          spreadRadius: -2,
          offset: const Offset(0, 6),
        ),
      ];

  // Button Glow Shadow
  static List<BoxShadow> glowShadow(Color accentColor) => [
        BoxShadow(
          color: accentColor.withOpacity(0.35),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 5),
        ),
      ];

  // Specular Border Gradient (Thin bright white border 60-80% opacity catching light top-left)
  static LinearGradient specularBorder(bool isDark, [ThemePalette? palette]) {
    if (palette != null && isDark) {
      return palette.specularBorderGradient;
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withOpacity(0.48), // Top-left rim highlight
              Colors.white.withOpacity(0.18),
              Colors.white.withOpacity(0.04), // Gentle fadeout
            ]
          : [
              Colors.white.withOpacity(0.78), // 60-80% bright white highlight top-left
              Colors.white.withOpacity(0.40),
              Colors.white.withOpacity(0.14),
            ],
    );
  }

  // Faint Memory Card Edge (0.5px line catching light top-left, fading bottom-right)
  static LinearGradient faintGlassEdge(bool isDark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withOpacity(0.28),
              Colors.white.withOpacity(0.12),
              Colors.white.withOpacity(0.04),
            ]
          : [
              Colors.white.withOpacity(0.70),
              Colors.white.withOpacity(0.30),
              Colors.white.withOpacity(0.08),
            ],
    );
  }

  // Card Inner Gloss: 55-70% opacity translucent white in light mode
  // Allows the living pastel gradient mesh to refract through the surface!
  static LinearGradient cardGloss(bool isDark, {Color? tint, ThemePalette? palette}) {
    if (tint != null) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                tint.withOpacity(0.30),
                tint.withOpacity(0.12),
              ]
            : [
                tint.withOpacity(0.28),
                tint.withOpacity(0.10),
              ],
      );
    }

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              (palette?.cardBackground ?? const Color(0xFF141722)).withOpacity(0.78),
              (palette?.cardBackground ?? const Color(0xFF141722)).withOpacity(0.68),
            ]
          : [
              Colors.white.withOpacity(0.66), // 55% - 70% opacity translucent white
              Colors.white.withOpacity(0.56),
            ],
    );
  }

  // Surface fill for chips, pills, circular buttons
  static Color chipFill(bool isDark, {bool isSelected = false, Color? accentColor}) {
    if (isSelected) {
      return accentColor ?? const Color(0xFFE07A5F);
    }
    return isDark ? Colors.white.withOpacity(0.09) : Colors.white.withOpacity(0.64);
  }

  // Border for chips and small controls
  static Border sideBorder(bool isDark, {bool isSelected = false, Color? accentColor}) {
    if (isSelected) {
      return Border.all(color: accentColor ?? const Color(0xFFE07A5F), width: 1);
    }
    return Border.all(
      color: isDark ? Colors.white.withOpacity(0.18) : Colors.white.withOpacity(0.75),
      width: 0.8,
    );
  }
}
