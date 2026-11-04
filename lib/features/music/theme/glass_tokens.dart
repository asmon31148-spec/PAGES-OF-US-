import 'package:flutter/material.dart';

/// Design tokens for Apple iOS 26 Liquid Glass styling
/// Following the Antigravity Liquid Glass UI Guide
class GlassTokens {
  // Blur sigmas
  static const double blurNormal = 18.0; // Cards, mini player
  static const double blurStrong = 28.0; // Bottom bar, sheets

  // Glass tint & border
  static final Color glassTint = Colors.white.withOpacity(0.14);
  static final Color glassBorder = Colors.white.withOpacity(0.30);
  static const double borderWidth = 1.0;

  // Gradient rim highlight (depth from top-left to bottom-right)
  static final LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withOpacity(0.22),
      Colors.white.withOpacity(0.06),
    ],
  );

  // Border gradient (bright edge catching light at top-left)
  static final LinearGradient borderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withOpacity(0.45),
      Colors.white.withOpacity(0.12),
    ],
  );

  // Radii
  static const double radiusCard = 20.0;
  static const double radiusSheet = 28.0;
  static const double radiusPill = 999.0;

  // Soft floating shadow
  static final BoxShadow softShadow = BoxShadow(
    color: Colors.black.withOpacity(0.25),
    blurRadius: 24,
    offset: const Offset(0, 8),
  );

  // Colors
  static const Color textPrimary = Colors.white;
  static final Color textSecondary = Colors.white.withOpacity(0.65);
  static final Color textMuted = Colors.white.withOpacity(0.40);
  static const Color accent = Color(0xFFE07A5F);
  static const Color accentTerra = Color(0xFFE07A5F);
  static const Color accentEmerald = Color(0xFF10B981);

  // Typography
  static const TextStyle largeTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static final TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );
}
