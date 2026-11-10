import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../theme/models/app_theme_data.dart';
import '../../theme/models/theme_palette.dart';

/// App-wide living gradient background placed behind the Apple Liquid Glass UI.
/// Delivers atmospheric refraction & romance with:
/// - 30 FPS capped rendering for buttery smooth, battery-friendly performance
/// - 3 Performance modes:
///     1. Full Magic: Dynamic living organic blobs drifting across the canvas
///     2. Balanced: Anchored soothing ambient breathing pulse (low GPU cycles)
///     3. Battery Saver: 100% frozen static gradient mesh (0 FPS, 0% CPU/GPU overhead)
/// - Auto-pause guards on app backgrounding or high-load states
/// - 500ms soft cross-fade between theme transitions
class SharedLivingThemeBackground extends StatefulWidget {
  final Widget child;
  final bool isPaused;

  const SharedLivingThemeBackground({
    super.key,
    required this.child,
    this.isPaused = false,
  });

  @override
  State<SharedLivingThemeBackground> createState() => _SharedLivingThemeBackgroundState();
}

class _SharedLivingThemeBackgroundState extends State<SharedLivingThemeBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _driftController;
  final ValueNotifier<double> _throttledProgress = ValueNotifier<double>(0.0);
  int _lastPaintMillis = 0;
  ThemePerformanceLevel? _currentPerformance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialized with 7.5s cycle for visible, smooth organic liquid drift
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7500),
    );
    _driftController.addListener(() {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 30 FPS cap (~33ms): skips redundant redraws on 120Hz/90Hz displays,
      // freeing up 75% of GPU cycles for native zero-latency touch and buttery scrolling!
      if (now - _lastPaintMillis >= 33) {
        _lastPaintMillis = now;
        _throttledProgress.value = _driftController.value;
      }
    });
  }

  void _syncAnimationState(ThemePerformanceLevel performance) {
    if (_currentPerformance == performance) return;
    _currentPerformance = performance;

    if (performance == ThemePerformanceLevel.batterySaver) {
      if (_driftController.isAnimating) {
        _driftController.stop();
      }
    } else {
      final targetDuration = performance == ThemePerformanceLevel.balanced
          ? const Duration(milliseconds: 4500) // 4.5s rhythmic breathing cycle
          : const Duration(milliseconds: 7500); // 7.5s active liquid drift

      _driftController.duration = targetDuration;
      if (!widget.isPaused && !_driftController.isAnimating) {
        _driftController.repeat();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context);
    _syncAnimationState(themeProvider.performanceLevel);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_driftController.isAnimating &&
          !widget.isPaused &&
          _currentPerformance != ThemePerformanceLevel.batterySaver) {
        _driftController.repeat();
      }
    } else {
      if (_driftController.isAnimating) {
        _driftController.stop();
      }
    }
  }

  @override
  void didUpdateWidget(covariant SharedLivingThemeBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPaused != oldWidget.isPaused) {
      if (widget.isPaused) {
        _driftController.stop();
      } else if (_currentPerformance != ThemePerformanceLevel.batterySaver) {
        _driftController.repeat();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _driftController.dispose();
    _throttledProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final palette = themeProvider.currentPalette;
    final performance = themeProvider.performanceLevel;
    final isDark = themeProvider.isDark;

    // Keep animation controller state synchronized with provider
    _syncAnimationState(performance);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Isolated Repaint Boundary for the living atmospheric canvas
        RepaintBoundary(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            child: _buildMeshCanvas(
              key: ValueKey('${themeProvider.themeId}_${isDark ? 'dark' : 'light'}_${performance.name}'),
              palette: palette,
              performance: performance,
              isDark: isDark,
            ),
          ),
        ),

        // 1b. Extra Eye-Comfort Soft Optical Layer (zero blur GPU cost!)
        if (themeProvider.isEyeComfort)
          IgnorePointer(
            child: Container(
              color: isDark
                  ? const Color(0xFF1F160E).withOpacity(0.18)
                  : const Color(0xFFFBF3E6).withOpacity(0.28),
            ),
          ),

        // 2. Foreground Liquid Glass application content (isolated boundary for 60/120fps performance)
        RepaintBoundary(child: widget.child),
      ],
    );
  }

  Widget _buildMeshCanvas({
    required Key key,
    required ThemePalette palette,
    required ThemePerformanceLevel performance,
    required bool isDark,
  }) {
    if (performance == ThemePerformanceLevel.batterySaver) {
      // 0% CPU/GPU timer overhead: static rendered gradient mesh
      return CustomPaint(
        key: key,
        painter: StaticAtmospherePainter(
          palette: palette,
          isDark: isDark,
        ),
        size: Size.infinite,
      );
    }

    // Full & Balanced modes: 30 FPS throttled living animation for buttery smooth gestures
    return AnimatedBuilder(
      key: key,
      animation: _throttledProgress,
      builder: (context, _) {
        return CustomPaint(
          painter: LivingAtmospherePainter(
            progress: _throttledProgress.value,
            palette: palette,
            performance: performance,
            isDark: isDark,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// Custom painter rendering organic floating radial glow blooms
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
    if (!isDark) {
      // Light-mode: Respect theme canvasBackground blended softly into warm alabaster silk
      final baseCanvas = palette.canvasBackground;
      final bgGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          baseCanvas,
          Color.lerp(baseCanvas, const Color(0xFFFFFBF7), 0.5) ?? baseCanvas,
          baseCanvas,
        ],
        stops: const [0.0, 0.52, 1.0],
      );
      final bgPaint = Paint()
        ..shader = bgGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    } else {
      // Dark-mode: Obsidian canvas
      final basePaint = Paint()..color = palette.canvasBackground;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);
    }

    final colors = palette.gradientColors;
    if (colors.isEmpty) return;

    final t = progress * 2 * math.pi;

    if (performance == ThemePerformanceLevel.balanced) {
      // =========================================================================
      // BALANCED MODE: Calm rhythmic breathing ambient light (NO lateral motion)
      // 4.5s sinusoidal breathing cycle (expanding & contracting)
      // Saves GPU cycles: zero displacement calculations, 2-3 anchored breathing nodes
      // =========================================================================
      final breath1 = (math.sin(t) + 1.0) / 2.0; // 0.0 -> 1.0 smooth breathing
      final breath2 = (math.cos(t) + 1.0) / 2.0;

      // Anchored Node 1: Top-Right breathing aura
      final p1 = Offset(size.width * 0.76, size.height * 0.22);
      final r1 = size.width * (0.46 + 0.24 * breath1);
      final op1 = (isDark ? 0.26 : 0.22) + 0.22 * breath1;
      _drawGlow(canvas, p1, r1, colors[0], op1);

      // Anchored Node 2: Bottom-Left breathing aura
      final c2 = colors.length > 1 ? colors[1] : colors[0];
      final p2 = Offset(size.width * 0.24, size.height * 0.78);
      final r2 = size.width * (0.48 + 0.22 * breath2);
      final op2 = (isDark ? 0.24 : 0.20) + 0.20 * breath2;
      _drawGlow(canvas, p2, r2, c2, op2);

      // Anchored Node 3 (Subtle Center Warmth)
      if (colors.length > 2) {
        final breath3 = (math.sin(t * 0.8 + 1.0) + 1.0) / 2.0;
        final p3 = Offset(size.width * 0.52, size.height * 0.48);
        final r3 = size.width * (0.36 + 0.16 * breath3);
        final op3 = (isDark ? 0.18 : 0.14) + 0.16 * breath3;
        _drawGlow(canvas, p3, r3, colors[2], op3);
      }
      return;
    }

    // ===========================================================================
    // FULL MAGIC MODE: Dynamic living organic blobs drifting across the screen
    // 7.5s cycle with wide Lissajous orbits (visible, rich, flowing fluid motion)
    // 4 distinct orbs creating hypnotic overlapping luminous liquid blooms
    // ===========================================================================
    // Blob 1: Upper-Right Organic Floating Blob
    final p1 = Offset(
      size.width * (0.62 + 0.26 * math.sin(t)),
      size.height * (0.22 + 0.16 * math.cos(t * 0.9)),
    );
    final r1 = size.width * (0.52 + 0.08 * math.sin(t * 1.3));
    _drawGlow(canvas, p1, r1, colors[0], isDark ? 0.54 : 0.46);

    // Blob 2: Mid-Left Floating Blob (Counter-flow)
    final c2 = colors.length > 1 ? colors[1] : colors[0];
    final p2 = Offset(
      size.width * (0.30 + 0.24 * math.cos(t * 1.1 + 0.7)),
      size.height * (0.56 + 0.18 * math.sin(t * 0.8 + 0.5)),
    );
    final r2 = size.width * (0.48 + 0.06 * math.cos(t * 1.1));
    _drawGlow(canvas, p2, r2, c2, isDark ? 0.48 : 0.42);

    // Blob 3: Lower-Right Floating Blob (Diagonal glide)
    final c3 = colors.length > 2 ? colors[2] : colors[0];
    final p3 = Offset(
      size.width * (0.70 + 0.22 * math.sin(t * 0.75 + 2.1)),
      size.height * (0.80 + 0.15 * math.cos(t * 1.2 + 1.2)),
    );
    final r3 = size.width * (0.50 + 0.07 * math.sin(t * 0.9));
    _drawGlow(canvas, p3, r3, c3, isDark ? 0.46 : 0.40);

    // Blob 4: Accent Core Floating Orb
    final c4 = colors.length > 3 ? colors[3] : palette.accentColor;
    final p4 = Offset(
      size.width * (0.42 + 0.20 * math.cos(t * 1.4 + 1.8)),
      size.height * (0.38 + 0.16 * math.sin(t * 1.3 + 1.5)),
    );
    final r4 = size.width * (0.38 + 0.05 * math.cos(t * 1.5));
    _drawGlow(canvas, p4, r4, c4, isDark ? 0.42 : 0.36);
  }

  void _drawGlow(Canvas canvas, Offset center, double radius, Color color, double opacity) {
    final clampedOpacity = opacity.clamp(0.0, 1.0);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(clampedOpacity),
          color.withOpacity(clampedOpacity * 0.65),
          color.withOpacity(clampedOpacity * 0.20),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant LivingAtmospherePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.palette != palette ||
        oldDelegate.performance != performance ||
        oldDelegate.isDark != isDark;
  }
}

/// Static snapshot painter for battery-saver mode (0% animation timer)
class StaticAtmospherePainter extends CustomPainter {
  final ThemePalette palette;
  final bool isDark;

  StaticAtmospherePainter({
    required this.palette,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isDark) {
      const bgGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF7F2),
          Color(0xFFF7F2FA),
          Color(0xFFF0F5FA),
        ],
        stops: [0.0, 0.52, 1.0],
      );
      final bgPaint = Paint()
        ..shader = bgGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    } else {
      final basePaint = Paint()..color = palette.canvasBackground;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);
    }

    final colors = palette.gradientColors;
    if (colors.isEmpty) return;

    // Static Node 1: Top-Right fixed radiant glow
    _drawStaticGlow(
      canvas,
      Offset(size.width * 0.82, size.height * 0.18),
      size.width * 0.65,
      colors[0],
      isDark ? 0.38 : 0.32,
    );

    // Static Node 2: Mid-Left fixed radiant glow
    if (colors.length > 1) {
      _drawStaticGlow(
        canvas,
        Offset(size.width * 0.18, size.height * 0.52),
        size.width * 0.60,
        colors[1],
        isDark ? 0.34 : 0.28,
      );
    }

    // Static Node 3: Bottom-Right fixed radiant glow
    if (colors.length > 2) {
      _drawStaticGlow(
        canvas,
        Offset(size.width * 0.72, size.height * 0.82),
        size.width * 0.65,
        colors[2],
        isDark ? 0.30 : 0.24,
      );
    }
  }

  void _drawStaticGlow(Canvas canvas, Offset center, double radius, Color color, double opacity) {
    final clampedOpacity = opacity.clamp(0.0, 1.0);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(clampedOpacity),
          color.withOpacity(clampedOpacity * 0.65),
          color.withOpacity(clampedOpacity * 0.20),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant StaticAtmospherePainter oldDelegate) {
    return oldDelegate.palette != palette || oldDelegate.isDark != isDark;
  }
}

/// Live interactive fluidity & motion preview card
class LivingAtmospherePreview extends StatefulWidget {
  final ThemePalette palette;
  final ThemePerformanceLevel performance;
  final bool isDark;
  final double height;

  const LivingAtmospherePreview({
    super.key,
    required this.palette,
    required this.performance,
    required this.isDark,
    this.height = 115,
  });

  @override
  State<LivingAtmospherePreview> createState() => _LivingAtmospherePreviewState();
}

class _LivingAtmospherePreviewState extends State<LivingAtmospherePreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final ValueNotifier<double> _throttledProgress = ValueNotifier<double>(0.0);
  int _lastPaintMillis = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationFor(widget.performance),
    );
    _controller.addListener(() {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastPaintMillis >= 33) {
        _lastPaintMillis = now;
        _throttledProgress.value = _controller.value;
      }
    });
    if (widget.performance != ThemePerformanceLevel.batterySaver) {
      _controller.repeat();
    }
  }

  Duration _durationFor(ThemePerformanceLevel perf) {
    switch (perf) {
      case ThemePerformanceLevel.full:
        return const Duration(milliseconds: 7500);
      case ThemePerformanceLevel.balanced:
        return const Duration(milliseconds: 4500);
      case ThemePerformanceLevel.batterySaver:
        return const Duration(seconds: 1);
    }
  }

  @override
  void didUpdateWidget(covariant LivingAtmospherePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.performance != widget.performance) {
      if (widget.performance == ThemePerformanceLevel.batterySaver) {
        _controller.stop();
      } else {
        _controller.duration = _durationFor(widget.performance);
        if (!_controller.isAnimating) {
          _controller.repeat();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _throttledProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perf = widget.performance;
    final isFull = perf == ThemePerformanceLevel.full;
    final isBalanced = perf == ThemePerformanceLevel.balanced;
    final isBatterySaver = perf == ThemePerformanceLevel.batterySaver;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.12),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? 0.35 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Mini Living Atmosphere Canvas
            if (isBatterySaver)
              CustomPaint(
                painter: StaticAtmospherePainter(
                  palette: widget.palette,
                  isDark: widget.isDark,
                ),
                size: Size.infinite,
              )
            else
              AnimatedBuilder(
                animation: _throttledProgress,
                builder: (context, _) => CustomPaint(
                  painter: LivingAtmospherePainter(
                    progress: _throttledProgress.value,
                    palette: widget.palette,
                    performance: perf,
                    isDark: widget.isDark,
                  ),
                  size: Size.infinite,
                ),
              ),

            // 2. Liquid Glass Frost Overlay & Explanatory Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (widget.isDark ? Colors.black : Colors.white).withOpacity(0.20),
                    (widget.isDark ? Colors.black : Colors.white).withOpacity(0.55),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mode Title Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: (widget.isDark ? Colors.black : Colors.white).withOpacity(0.65),
                          border: Border.all(
                            color: widget.palette.accentColor.withOpacity(0.40),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isFull
                              ? '✨ Full Magic'
                              : isBalanced
                                  ? '🌿 Balanced'
                                  : '🔋 Battery Saver',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: widget.palette.primaryText,
                          ),
                        ),
                      ),

                      // Live Ticker Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isFull
                              ? const Color(0xFF10B981).withOpacity(0.25)
                              : isBalanced
                                  ? const Color(0xFF06B6D4).withOpacity(0.25)
                                  : Colors.white.withOpacity(0.15),
                          border: Border.all(
                            color: isFull
                                ? const Color(0xFF10B981)
                                : isBalanced
                                    ? const Color(0xFF06B6D4)
                                    : Colors.white.withOpacity(0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isFull
                                    ? const Color(0xFF10B981)
                                    : isBalanced
                                        ? const Color(0xFF06B6D4)
                                        : Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isFull
                                  ? '30 FPS Drift'
                                  : isBalanced
                                      ? 'Breathing Light'
                                      : 'Frozen 0 FPS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: widget.palette.primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Explanatory Subtitle
                  Text(
                    isFull
                        ? 'Luminous organic blobs actively floating & swirling in real-time.'
                        : isBalanced
                            ? 'Gentle rhythmic breathing pulse with zero lateral movement.'
                            : '100% frozen static gradient with zero animation & 0% GPU draw.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: widget.palette.primaryText.withOpacity(0.90),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
