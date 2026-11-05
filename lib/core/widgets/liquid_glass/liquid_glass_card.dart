import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import 'liquid_glass_theme.dart';

/// Authentic Apple iOS 26 Liquid Glass Card
/// High-performance GPU-optimized implementation:
/// Uses 1px specular rim gradient, top-down gloss refraction, and warm ambient drop shadow.
/// Translucent inner glass (55-70% in light mode) lets the living background shine through.
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? tint;
  final VoidCallback? onTap;
  final bool enableBlur;
  final double blurSigma;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.radius = 22.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.tint,
    this.onTap,
    this.enableBlur = true,
    this.blurSigma = LiquidGlassTheme.blurCard,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final palette = themeProvider.currentPalette;

    final borderRadius = BorderRadius.circular(radius);
    final innerRadius = BorderRadius.circular((radius - 1.0).clamp(0.0, 999.0));

    Widget innerContent = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: innerRadius,
        gradient: LiquidGlassTheme.cardGloss(isDark, tint: tint, palette: palette),
      ),
      child: child,
    );

    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LiquidGlassTheme.specularBorder(isDark, palette),
        boxShadow: LiquidGlassTheme.cardShadow(isDark),
      ),
      padding: const EdgeInsets.all(1.0), // 1px specular rim light reflection
      child: ClipRRect(
        borderRadius: innerRadius,
        child: enableBlur && blurSigma > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: innerContent,
              )
            : innerContent,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }

    return card;
  }
}
