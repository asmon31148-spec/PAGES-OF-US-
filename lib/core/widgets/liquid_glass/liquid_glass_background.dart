import 'package:flutter/material.dart';
import 'shared_living_theme_background.dart';

export 'shared_living_theme_background.dart'
    show
        SharedLivingThemeBackground,
        LivingAtmospherePreview,
        LivingAtmospherePainter,
        StaticAtmospherePainter;

/// Central Apple Liquid Glass Atmosphere Background.
/// Wraps content in the couple's active living theme background with 30fps smooth drift,
/// GPU optimization, and auto-pause guards.
class LiquidGlassBackground extends StatelessWidget {
  final Widget child;
  final bool isPaused;

  const LiquidGlassBackground({
    super.key,
    required this.child,
    this.isPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    return SharedLivingThemeBackground(
      isPaused: isPaused,
      child: child,
    );
  }
}
