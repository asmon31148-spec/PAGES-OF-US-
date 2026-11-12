import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../theme/models/app_theme_data.dart';
import '../../theme/models/theme_palette.dart';

/// Crisp, GPU-light living theme atmosphere using each theme's real palette gradient
/// without expensive blur filters or 60fps animation tickers.
class SharedLivingThemeBackground extends StatelessWidget {
  final Widget child;
  final bool isPaused;

  const SharedLivingThemeBackground({
    super.key,
    required this.child,
    this.isPaused = false,
  });

  static BoxDecoration buildAtmosphereDecoration(ThemePalette palette, bool isDark) {
    final c0 = palette.gradientColors.isNotEmpty ? palette.gradientColors[0] : palette.accentColor;
    final c1 = palette.gradientColors.length > 1 ? palette.gradientColors[1] : c0;
    final c2 = palette.gradientColors.length > 2 ? palette.gradientColors[2] : c1;

    final topColor = Color.alphaBlend(c0.withValues(alpha: isDark ? 0.30 : 0.22), palette.canvasBackground);
    final midColor = Color.alphaBlend(c1.withValues(alpha: isDark ? 0.18 : 0.14), palette.canvasBackground);
    final bottomColor = Color.alphaBlend(c2.withValues(alpha: isDark ? 0.24 : 0.18), palette.canvasBackground);

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [topColor, midColor, palette.canvasBackground, bottomColor],
        stops: const [0.0, 0.35, 0.68, 1.0],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final palette = themeProvider.currentPalette;
    final isDark = themeProvider.isDark;
    final c0 = palette.gradientColors.isNotEmpty ? palette.gradientColors[0] : palette.accentColor;
    final c2 = palette.gradientColors.length > 2 ? palette.gradientColors[2] : c0;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: DecoratedBox(
            decoration: buildAtmosphereDecoration(palette, isDark),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.75, -0.78),
                      radius: 1.05,
                      colors: [
                        c0.withValues(alpha: isDark ? 0.22 : 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.80, 0.72),
                      radius: 1.0,
                      colors: [
                        c2.withValues(alpha: isDark ? 0.18 : 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (themeProvider.isEyeComfort)
          IgnorePointer(
            child: ColoredBox(
              color: isDark
                  ? const Color(0xFF1F160E).withValues(alpha: 0.16)
                  : const Color(0xFFFBF3E6).withValues(alpha: 0.24),
            ),
          ),
        RepaintBoundary(child: child),
      ],
    );
  }
}

class LivingAtmospherePainter extends CustomPainter {
  final double progress;
  final ThemePalette palette;
  final ThemePerformanceLevel performance;
  final bool isDark;

  LivingAtmospherePainter({
    required this.progress,
    required this.palette,
    required this.performance,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c0 = palette.gradientColors.isNotEmpty ? palette.gradientColors[0] : palette.accentColor;
    final c1 = palette.gradientColors.length > 1 ? palette.gradientColors[1] : c0;
    final c2 = palette.gradientColors.length > 2 ? palette.gradientColors[2] : c1;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(c0.withValues(alpha: isDark ? 0.45 : 0.36), palette.canvasBackground),
          Color.alphaBlend(c1.withValues(alpha: isDark ? 0.30 : 0.24), palette.canvasBackground),
          Color.alphaBlend(c2.withValues(alpha: isDark ? 0.38 : 0.28), palette.canvasBackground),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant LivingAtmospherePainter oldDelegate) {
    return oldDelegate.palette != palette || oldDelegate.isDark != isDark;
  }
}

class StaticAtmospherePainter extends CustomPainter {
  final ThemePalette palette;
  final bool isDark;

  StaticAtmospherePainter({
    required this.palette,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c0 = palette.gradientColors.isNotEmpty ? palette.gradientColors[0] : palette.accentColor;
    final c1 = palette.gradientColors.length > 1 ? palette.gradientColors[1] : c0;
    final c2 = palette.gradientColors.length > 2 ? palette.gradientColors[2] : c1;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(c0.withValues(alpha: isDark ? 0.48 : 0.38), palette.canvasBackground),
          Color.alphaBlend(c1.withValues(alpha: isDark ? 0.32 : 0.26), palette.canvasBackground),
          Color.alphaBlend(c2.withValues(alpha: isDark ? 0.40 : 0.30), palette.canvasBackground),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant StaticAtmospherePainter oldDelegate) {
    return oldDelegate.palette != palette || oldDelegate.isDark != isDark;
  }
}

class LivingAtmospherePreview extends StatelessWidget {
  final ThemePalette palette;
  final ThemePerformanceLevel performance;
  final bool isDark;
  final double height;

  const LivingAtmospherePreview({
    super.key,
    required this.palette,
    required this.performance,
    required this.isDark,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: StaticAtmospherePainter(palette: palette, isDark: isDark),
      ),
    );
  }
}
