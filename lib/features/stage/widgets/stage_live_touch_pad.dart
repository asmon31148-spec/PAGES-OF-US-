import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';

class StageLiveTouchPad extends StatefulWidget {
  const StageLiveTouchPad({super.key});

  @override
  State<StageLiveTouchPad> createState() => _StageLiveTouchPadState();
}

class _StageLiveTouchPadState extends State<StageLiveTouchPad>
    with SingleTickerProviderStateMixin {
  bool _isTouching = false;
  Offset? _myTouch;
  Timer? _heartbeatTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  void _startHeartbeat(bool bothTouching) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (bothTouching) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _handleTouch(
    Offset local,
    Size size,
    StageProvider stageProvider,
    String spaceId,
    String userId,
    bool isTouching,
  ) {
    final nx = (local.dx / size.width).clamp(0.0, 1.0);
    final ny = (local.dy / size.height).clamp(0.0, 1.0);
    stageProvider.sendTouchPadEvent(spaceId, userId, nx, ny, isTouching: isTouching);
  }

  @override
  void dispose() {
    _stopHeartbeat();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final stageProvider = context.watch<StageProvider>();
    final user = authProvider.user;
    final space = authProvider.space;

    final partnerTouch = stageProvider.partnerTouchPoint;
    final isPartnerTouching = stageProvider.isPartnerTouching;
    final bothTouching = _isTouching && isPartnerTouching;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 180,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: bothTouching
              ? AppColors.terra.withOpacity(0.6)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: bothTouching ? 1.5 : 1.0,
        ),
        boxShadow: bothTouching
            ? [
                BoxShadow(
                  color: AppColors.terra.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padSize = Size(constraints.maxWidth, constraints.maxHeight);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (details) {
                if (space != null && user != null) {
                  setState(() {
                    _isTouching = true;
                    _myTouch = details.localPosition;
                  });
                  HapticFeedback.mediumImpact();
                  _startHeartbeat(isPartnerTouching);
                  _handleTouch(details.localPosition, padSize, stageProvider, space.id, user.id, true);
                }
              },
              onPanUpdate: (details) {
                if (space != null && user != null) {
                  setState(() {
                    _myTouch = details.localPosition;
                  });
                  _handleTouch(details.localPosition, padSize, stageProvider, space.id, user.id, true);
                }
              },
              onPanEnd: (_) {
                if (space != null && user != null) {
                  setState(() {
                    _isTouching = false;
                  });
                  _stopHeartbeat();
                  _handleTouch(_myTouch ?? Offset.zero, padSize, stageProvider, space.id, user.id, false);
                }
              },
              onPanCancel: () {
                if (space != null && user != null) {
                  setState(() {
                    _isTouching = false;
                  });
                  _stopHeartbeat();
                  _handleTouch(_myTouch ?? Offset.zero, padSize, stageProvider, space.id, user.id, false);
                }
              },
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Custom Painter for Smooth Haptic & Touch Auras
                      CustomPaint(
                        size: padSize,
                        painter: _TouchPadAuraPainter(
                          isTouching: _isTouching,
                          myTouch: _myTouch,
                          partnerTouch: partnerTouch != null
                              ? Offset(partnerTouch.x * padSize.width, partnerTouch.y * padSize.height)
                              : null,
                          pulseValue: _pulseController.value,
                          isDark: isDark,
                        ),
                      ),

                      // Information UI Overlay
                      if (!_isTouching && !isPartnerTouching)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Transform.scale(
                                scale: 1.0 + (_pulseController.value * 0.05),
                                child: const Icon(
                                  Icons.fingerprint,
                                  size: 42,
                                  color: AppColors.sageLight,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Synchronized Touch Pad',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkInk : AppColors.lightInk,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hold your thumb here to feel your partner\'s presence ✦',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_isTouching && !isPartnerTouching)
                        Positioned(
                          bottom: 14,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'Holding space... Waiting for partner\'s thumb ✦',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (!_isTouching && isPartnerTouching)
                        Positioned(
                          bottom: 14,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.terra.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.terra.withOpacity(0.4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Partner is touching the pad! Place thumb to meet ✨',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (bothTouching)
                        Positioned(
                          bottom: 14,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.terra,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 12,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.favorite, color: Colors.white, size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'Touching together right now 💖 Connected',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TouchPadAuraPainter extends CustomPainter {
  final bool isTouching;
  final Offset? myTouch;
  final Offset? partnerTouch;
  final double pulseValue;
  final bool isDark;

  _TouchPadAuraPainter({
    required this.isTouching,
    required this.myTouch,
    required this.partnerTouch,
    required this.pulseValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. If both are touching: Draw an ethereal connecting bridge
    if (isTouching && myTouch != null && partnerTouch != null) {
      final bridgePaint = Paint()
        ..color = AppColors.terra.withOpacity(0.45 + (pulseValue * 0.2))
        ..strokeWidth = 10 + (pulseValue * 6)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

      canvas.drawLine(myTouch!, partnerTouch!, bridgePaint);
    }

    // 2. My Touch Aura
    if (isTouching && myTouch != null) {
      final baseRadius = 38.0 + (pulseValue * 10);

      // Outer Glow
      final outerGlowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.terra.withOpacity(0.5),
            AppColors.terra.withOpacity(0.15),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: myTouch!, radius: baseRadius * 1.6));
      canvas.drawCircle(myTouch!, baseRadius * 1.6, outerGlowPaint);

      // Core Aura
      final corePaint = Paint()
        ..color = AppColors.terra.withOpacity(0.8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(myTouch!, 22, corePaint);

      // Inner Sparkle Ring
      final ringPaint = Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(myTouch!, 14 + (pulseValue * 4), ringPaint);
    }

    // 3. Partner's Touch Aura
    if (partnerTouch != null) {
      final pRadius = 38.0 + ((1.0 - pulseValue) * 10);

      final pGlowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFE89A6B).withOpacity(0.55),
            const Color(0xFFE89A6B).withOpacity(0.18),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: partnerTouch!, radius: pRadius * 1.6));
      canvas.drawCircle(partnerTouch!, pRadius * 1.6, pGlowPaint);

      final pCorePaint = Paint()
        ..color = const Color(0xFFE89A6B).withOpacity(0.85)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(partnerTouch!, 22, pCorePaint);

      final pRingPaint = Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(partnerTouch!, 14 + ((1.0 - pulseValue) * 4), pRingPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TouchPadAuraPainter oldDelegate) {
    return oldDelegate.isTouching != isTouching ||
        oldDelegate.myTouch != myTouch ||
        oldDelegate.partnerTouch != partnerTouch ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.isDark != isDark;
  }
}
