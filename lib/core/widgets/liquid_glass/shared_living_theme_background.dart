import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../theme/models/app_theme_data.dart';
import '../../theme/models/theme_palette.dart';

/// Clean, calm, distraction-free background surface without blurred color blobs or gradient bleeds.
class SharedLivingThemeBackground extends StatelessWidget {
  final Widget child;
  final bool isPaused;

  const SharedLivingThemeBackground({
    super.key,
    required this.child,
    this.isPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final palette = themeProvider.currentPalette;
    final isDark = themeProvider.isDark;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          color: palette.canvasBackground,
        ),
        if (themeProvider.isEyeComfort)
          IgnorePointer(
            child: Container(
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
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.canvasBackground);
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
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.canvasBackground);
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
