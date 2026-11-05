import 'package:flutter/material.dart';

/// Centralized Apple Liquid Glass Design System tokens
/// Tuned for visible specular refraction, high contrast, and distinct theme separation
class LiquidGlassTheme {
  // Blur constants
  static const double blurCard = 22.0;
  static const double blurSheet = 30.0;
  static const double blurPill = 18.0;

  // Background deep tones (Clean obsidian in dark, warm cream silk in light)
  static const Color darkCanvas = Color(0xFF0C0E14); // Deep midnight obsidian (never murky green)
  static const Color lightCanvas = Color(0xFFF0EBE3); // Warm cream silk (allows white glass to POP)

  // Typography Tokens (Guaranteed razor-sharp contrast in all modes)
  static Color titleColor(bool isDark) =>
      isDark ? const Color(0xFFFBFBFC) : const Color(0xFF1C1D21);

  static Color bodyColor(bool isDark) =>
      isDark ? const Color(0xFFE5E7EB) : const Color(0xFF2E3239);

  static Color subtitleColor(bool isDark) =>
      isDark ? const Color(0xFFA0A6B2) : const Color(0xFF6B7280);

  // Card Ambient Shadow (Crisp depth in both light and dark)
  static List<BoxShadow> cardShadow(bool isDark) => [
        BoxShadow(
          color: isDark ? Colors.black.withOpacity(0.55) : const Color(0x1F2B2D38),
          blurRadius: 20,
          spreadRadius: -2,
          offset: const Offset(0, 6),
        ),
      ];

  // Button Glow Shadow
  static List<BoxShadow> glowShadow(Color accentColor) => [
        BoxShadow(
          color: accentColor.withOpacity(0.45),
          blurRadius: 18,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      ];

  // Specular Border Gradient (Visible bright rim reflection on top-left)
  static LinearGradient specularBorder(bool isDark) {
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
              Colors.white, // Crisp white specular line
              Colors.white.withOpacity(0.70),
              Colors.black.withOpacity(0.08), // Gentle outline
            ],
    );
  }

  // Card Inner Tint & Gloss Gradient
  static LinearGradient cardGloss(bool isDark, {Color? tint}) {
    if (tint != null) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                tint.withOpacity(0.28),
                tint.withOpacity(0.10),
              ]
            : [
                tint.withOpacity(0.20),
                tint.withOpacity(0.08),
              ],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              const Color(0xFF1B202B).withOpacity(0.90),
              const Color(0xFF10131B).withOpacity(0.92),
            ]
          : [
              Colors.white.withOpacity(0.96),
              const Color(0xFFFAF7F2).withOpacity(0.92),
            ],
    );
  }
}
