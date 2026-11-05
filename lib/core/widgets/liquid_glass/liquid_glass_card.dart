import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import 'liquid_glass_theme.dart';

/// Authentic Apple iOS / visionOS Liquid Glass Card
/// High-performance GPU-optimized implementation:
/// Uses 1px specular rim gradient, top-down gloss refraction, and ambient drop shadow.
/// Avoids heavy per-frame saveLayer Gaussian blurs in scrollable lists for locked 120 FPS.
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
    this.enableBlur = false,
    this.blurSigma = LiquidGlassTheme.blurCard,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final borderRadius = BorderRadius.circular(radius);
    final innerRadius = BorderRadius.circular((radius - 1.0).clamp(0.0, 999.0));

    Widget innerContent = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: innerRadius,
        gradient: LiquidGlassTheme.cardGloss(isDark, tint: tint),
      ),
      child: child,
    );

    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LiquidGlassTheme.specularBorder(isDark),
        boxShadow: LiquidGlassTheme.cardShadow(isDark),
      ),
      padding: const EdgeInsets.all(1.0), // 1px specular rim light reflection
      child: ClipRRect(
        borderRadius: innerRadius,
        child: enableBlur
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
