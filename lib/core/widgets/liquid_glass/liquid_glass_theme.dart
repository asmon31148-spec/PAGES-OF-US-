import 'package:flutter/material.dart';
import '../theme/models/theme_palette.dart';

/// Centralized Apple Liquid Glass Design System tokens
/// Tuned for visible specular refraction, translucent living depth, and high contrast legibility.
class LiquidGlassTheme {
  // Blur constants
  static const double blurCard = 22.0;
  static const double blurSheet = 30.0;
  static const double blurPill = 18.0;

  // Background deep tones
  static const Color darkCanvas = Color(0xFF0C0E14);
  static const Color lightCanvas = Color(0xFFECE7DE);

  // Typography Tokens
  static Color titleColor(bool isDark, [ThemePalette? palette]) =>
      palette?.primaryText ?? (isDark ? const Color(0xFFFBFBFC) : const Color(0xFF1A1C22));

  static Color bodyColor(bool isDark, [ThemePalette? palette]) =>
      palette?.primaryText ?? (isDark ? const Color(0xFFE5E7EB) : const Color(0xFF2E3239));

  static Color subtitleColor(bool isDark, [ThemePalette? palette]) =>
      palette?.secondaryText ?? (isDark ? const Color(0xFFA5ACB8) : const Color(0xFF64748B));

  // Card Ambient Shadow (Crisp floating depth)
  static List<BoxShadow> cardShadow(bool isDark) => [
        BoxShadow(
          color: isDark ? Colors.black.withOpacity(0.40) : const Color(0x182B2D38),
          blurRadius: 18,
          spreadRadius: -2,
          offset: const Offset(0, 6),
        ),
      ];

  // Button Glow Shadow
  static List<BoxShadow> glowShadow(Color accentColor) => [
        BoxShadow(
          color: accentColor.withOpacity(0.40),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 5),
        ),
      ];

  // Specular Border Gradient (Visible 1px bright rim reflection catching light on top-left)
  static LinearGradient specularBorder(bool isDark, [ThemePalette? palette]) {
    if (palette != null) {
      return palette.specularBorderGradient;
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withOpacity(0.50), // Prominent top-left rim light
              Colors.white.withOpacity(0.18),
              Colors.white.withOpacity(0.04), // Soft fadeout
            ]
          : [
              Colors.white.withOpacity(0.95), // Crisp white specular line
              Colors.white.withOpacity(0.65),
              Colors.black.withOpacity(0.06), // Gentle outline
            ],
    );
  }

  // Card Inner Tint & Translucent Gloss Gradient
  // Uses 72%-78% opacity so the living theme gradients refract through the glass!
  static LinearGradient cardGloss(bool isDark, {Color? tint, ThemePalette? palette}) {
    if (tint != null) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                tint.withOpacity(0.32),
                tint.withOpacity(0.14),
              ]
            : [
                tint.withOpacity(0.24),
                tint.withOpacity(0.10),
              ],
      );
    }

    if (palette != null) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                palette.cardBackground.withOpacity(0.78),
                palette.cardBackground.withOpacity(0.68),
              ]
            : [
                palette.cardBackground.withOpacity(0.82),
                palette.cardBackground.withOpacity(0.74),
              ],
      );
    }

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              const Color(0xFF141722).withOpacity(0.78),
              const Color(0xFF0F121C).withOpacity(0.68),
            ]
          : [
              Colors.white.withOpacity(0.85),
              const Color(0xFFF7F5F0).withOpacity(0.75),
            ],
    );
  }
}
