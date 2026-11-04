import 'package:flutter/material.dart';

/// Centralized Apple Liquid Glass Design System tokens
class LiquidGlassTheme {
  // Blur constants
  static const double blurCard = 22.0;
  static const double blurSheet = 30.0;
  static const double blurPill = 18.0;

  // Background deep tones
  static const Color darkCanvas = Color(0xFF090B0E); // Deep midnight obsidian
  static const Color lightCanvas = Color(0xFFF7F5F0); // Pearlescent warm silk

  // Card Ambient Shadow
  static List<BoxShadow> cardShadow(bool isDark) => [
        BoxShadow(
          color: isDark ? Colors.black.withOpacity(0.45) : Colors.black.withOpacity(0.07),
          blurRadius: 24,
          spreadRadius: -2,
          offset: const Offset(0, 8),
        ),
      ];

  // Button Glow Shadow
  static List<BoxShadow> glowShadow(Color accentColor) => [
        BoxShadow(
          color: accentColor.withOpacity(0.42),
          blurRadius: 18,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      ];

  // Specular Border Gradient (Top-left light reflection to bottom-right fade)
  static LinearGradient specularBorder(bool isDark) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withOpacity(0.35),
              Colors.white.withOpacity(0.12),
              Colors.white.withOpacity(0.04),
            ]
          : [
              Colors.white.withOpacity(0.95),
              Colors.white.withOpacity(0.50),
              Colors.black.withOpacity(0.06),
            ],
    );
  }

  // Card Inner Tint Gradient
  static LinearGradient cardGloss(bool isDark, {Color? tint}) {
    if (tint != null) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                tint.withOpacity(0.24),
                tint.withOpacity(0.08),
              ]
            : [
                tint.withOpacity(0.18),
                tint.withOpacity(0.06),
              ],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Colors.white.withOpacity(0.11),
              Colors.white.withOpacity(0.04),
            ]
          : [
              Colors.white.withOpacity(0.85),
              Colors.white.withOpacity(0.55),
            ],
    );
  }
}
