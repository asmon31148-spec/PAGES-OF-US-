import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../theme/app_colors.dart';
import 'liquid_glass_theme.dart';

/// Ambient Atmospheric Mesh Background that gives Liquid Glass its refraction & luminescence
/// Optimized with zero GPU BackdropFilter overhead for buttery smooth 120 FPS scrolling
class LiquidGlassBackground extends StatelessWidget {
  final Widget child;

  const LiquidGlassBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return Stack(
      children: [
        // 1. Static Ambient Canvas with glowing atmospheric mesh
        Positioned.fill(
          child: RepaintBoundary(
            child: Container(
              color: isDark ? LiquidGlassTheme.darkCanvas : LiquidGlassTheme.lightCanvas,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Top-Right Atmospheric Glow (Warm Terracotta / Peach)
                  Positioned(
                    top: -60,
                    right: -60,
                    width: 320,
                    height: 320,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.terra.withOpacity(isDark ? 0.22 : 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Mid-Left Atmospheric Glow (Ethereal Rose-Plum)
                  Positioned(
                    top: 280,
                    left: -80,
                    width: 300,
                    height: 300,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF6B3A64).withOpacity(isDark ? 0.20 : 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom-Center Atmospheric Glow (Golden Amber)
                  Positioned(
                    bottom: -50,
                    right: 40,
                    width: 280,
                    height: 280,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFE9C46A).withOpacity(isDark ? 0.15 : 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. Foreground content with true liquid glass elements
        child,
      ],
    );
  }
}
