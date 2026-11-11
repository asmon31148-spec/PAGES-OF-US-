import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import 'liquid_glass_theme.dart';

/// Clean, sharp flat-glass card: semi-transparent surface + crisp 1px border (no blur or shadows).
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
    this.radius = 20.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.tint,
    this.onTap,
    this.enableBlur = false,
    this.blurSigma = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final palette = themeProvider.currentPalette;

    final card = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.flatSurface(isDark, tint: tint, palette: palette),
        borderRadius: BorderRadius.circular(radius),
        border: LiquidGlassTheme.crispBorder(isDark, palette: palette),
      ),
      child: child,
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
