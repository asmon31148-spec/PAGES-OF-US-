import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/drawing_stroke.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';

enum TouchSanctuaryMode { thumbKiss, glowTrace, heartPulse }

class TouchSanctuaryScreen extends StatefulWidget {
  final TouchSanctuaryMode initialMode;

  const TouchSanctuaryScreen({
    super.key,
    this.initialMode = TouchSanctuaryMode.thumbKiss,
  });

  @override
  State<TouchSanctuaryScreen> createState() => _TouchSanctuaryScreenState();
}

class _TouchSanctuaryScreenState extends State<TouchSanctuaryScreen>
    with TickerProviderStateMixin {
  late TouchSanctuaryMode _currentMode;

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _collisionController;
  late AnimationController _waveController;
  late final AudioPlayer _audioPlayer;

  // Mode 1: Thumb Kiss state
  bool _isMyThumbDown = false;
  Offset? _myThumbPoint;
  Timer? _heartbeatTimer;
  bool _isColliding = false;

  // Mode 2: Glow Trace state
  String _selectedTool = 'pen'; // 'pen', 'stardust', 'eraser'
  Color _selectedColor = const Color(0xFFE2847A);
  double _selectedWidth = 3.5;
  List<StrokePoint>? _activePoints;
  Offset? _eraserTouchPoint;

  // Mode 3: Heart Pulse state (Water ripple model)
  final List<_WaterRipple> _waterRipples = [];
  Timer? _waterDropSoundDebounce;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _audioPlayer = AudioPlayer();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _collisionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final effectiveSpaceId = auth.space?.id ?? auth.user?.spaceId;
      if (effectiveSpaceId != null && effectiveSpaceId.isNotEmpty && auth.user != null) {
        context.read<StageProvider>().initSpaceListeners(
              effectiveSpaceId,
              auth.user!.id,
              auth.partner?.id,
            );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    final effectiveSpaceId = auth.space?.id ?? auth.user?.spaceId;
    if (effectiveSpaceId != null && effectiveSpaceId.isNotEmpty && auth.user != null) {
      context.read<StageProvider>().initSpaceListeners(
            effectiveSpaceId,
            auth.user!.id,
            auth.partner?.id,
          );
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _waterDropSoundDebounce?.cancel();
    _pulseController.dispose();
    _collisionController.dispose();
    _waveController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Instant soft water droplet sound with native click and gentle chime
  Future<void> _playWaterDropSound() async {
    if (_waterDropSoundDebounce?.isActive ?? false) return;
    _waterDropSoundDebounce = Timer(const Duration(milliseconds: 90), () {});

    try {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(0.45);
      await _audioPlayer.play(
        AssetSource('audio/water_drop.wav'),
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {}
  }

  void _startContinuousHeartbeat() {
    if (_heartbeatTimer != null) return;
    HapticFeedback.mediumImpact();
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (_isColliding) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    });
  }

  void _stopContinuousHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isColliding = false;
  }

  int _lastTouchSendMs = 0;

  void _handleThumbMove(
    Offset local,
    Size size,
    StageProvider stageProvider,
    String spaceId,
    String userId,
    bool isDown, {
    bool force = false,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle network broadcast to ~35Hz to prevent socket flooding & WebSocket drops
    if (!force && isDown && (now - _lastTouchSendMs) < 28) {
      return;
    }
    _lastTouchSendMs = now;

    final nx = (local.dx / size.width).clamp(0.0, 1.0);
    final ny = (local.dy / size.height).clamp(0.0, 1.0);
    stageProvider.sendTouchPadEvent(spaceId, userId, nx, ny, isTouching: isDown);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final stageProvider = context.watch<StageProvider>();
    final user = authProvider.user;
    final space = authProvider.space;
    final partner = authProvider.partner;
    final effectiveSpaceId = space?.id ?? user?.spaceId ?? '';
    final partnerNickname = partner?.nickname?.isNotEmpty == true ? partner!.nickname! : 'Partner';

    final partnerTouch = stageProvider.partnerTouchPoint;
    final isPartnerTouching = stageProvider.isPartnerTouching;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF07060B),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF07060B),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Deep Cosmic Nebula Ambient Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 1.3,
                    colors: [
                      _getAmbientModeColor().withOpacity(0.18),
                      const Color(0xFF0C0A15),
                      const Color(0xFF07060B),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // Full-Screen Interactive Canvas (Zero Scroll Conflict!)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final padSize = Size(constraints.maxWidth, constraints.maxHeight);

                  switch (_currentMode) {
                    case TouchSanctuaryMode.thumbKiss:
                      return _buildFullScreenThumbKiss(
                        padSize: padSize,
                        stageProvider: stageProvider,
                        spaceId: effectiveSpaceId,
                        userId: user?.id ?? '',
                        partnerTouch: partnerTouch,
                        isPartnerTouching: isPartnerTouching,
                        partnerNickname: partnerNickname,
                      );

                    case TouchSanctuaryMode.glowTrace:
                      return _buildFullScreenGlowTrace(
                        padSize: padSize,
                        stageProvider: stageProvider,
                        spaceId: effectiveSpaceId,
                        userId: user?.id ?? '',
                        partnerNickname: partnerNickname,
                      );

                    case TouchSanctuaryMode.heartPulse:
                      return _buildFullScreenHeartPulse(
                        padSize: padSize,
                        stageProvider: stageProvider,
                        spaceId: effectiveSpaceId,
                        userId: user?.id ?? '',
                        partnerNickname: partnerNickname,
                      );
                  }
                },
              ),
            ),

            // Top Floating Header Bar (Guaranteed ZERO overlap)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: _buildTopHeader(
                  partnerNickname: partnerNickname,
                  isPartnerTouching: isPartnerTouching,
                ),
              ),
            ),

            // Bottom Tool Palette (Exclusively for Glow Trace mode)
            if (_currentMode == TouchSanctuaryMode.glowTrace)
              Positioned(
                left: 14,
                right: 14,
                bottom: 16,
                child: SafeArea(
                  bottom: true,
                  child: _buildGlowToolBar(
                    stageProvider: stageProvider,
                    spaceId: effectiveSpaceId,
                    userId: user?.id ?? '',
                  ),
                ),
              ),

            // Bottom Guidance Pill for Thumb-Kiss
            if (_currentMode == TouchSanctuaryMode.thumbKiss)
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: SafeArea(
                  bottom: true,
                  child: _buildThumbKissStatusPill(isPartnerTouching, partnerNickname),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getAmbientModeColor() {
    switch (_currentMode) {
      case TouchSanctuaryMode.thumbKiss:
        return const Color(0xFFFF2D55);
      case TouchSanctuaryMode.glowTrace:
        return _selectedColor;
      case TouchSanctuaryMode.heartPulse:
        return const Color(0xFFE11D48);
    }
  }

  // -------------------------------------------------------------
  // TOP FLOATING HEADER (Back Button + Mode Switcher + Presence)
  // -------------------------------------------------------------
  Widget _buildTopHeader({
    required String partnerNickname,
    required bool isPartnerTouching,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF14121E).withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Sleek Back Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 2. Center Mode Switcher (Guaranteed ZERO overflow across all screen sizes)
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeSegment(
                      mode: TouchSanctuaryMode.thumbKiss,
                      label: 'Kiss',
                      icon: Icons.fingerprint_rounded,
                      activeColor: const Color(0xFFFF4B72),
                    ),
                  ),
                  Expanded(
                    child: _buildModeSegment(
                      mode: TouchSanctuaryMode.glowTrace,
                      label: 'Draw',
                      icon: Icons.brush_rounded,
                      activeColor: const Color(0xFF00E5FF),
                    ),
                  ),
                  Expanded(
                    child: _buildModeSegment(
                      mode: TouchSanctuaryMode.heartPulse,
                      label: 'Pulse',
                      icon: Icons.favorite_rounded,
                      activeColor: const Color(0xFFF43F5E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 3. Compact Partner Live Presence Badge
          _buildPartnerPresenceBadge(partnerNickname, isPartnerTouching),
        ],
      ),
    );
  }

  Widget _buildModeSegment({
    required TouchSanctuaryMode mode,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _currentMode = mode;
          _isMyThumbDown = false;
          _myThumbPoint = null;
          _activePoints = null;
        });
        _stopContinuousHeartbeat();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : Colors.white60,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerPresenceBadge(String partnerNickname, bool isPartnerTouching) {
    final initial = partnerNickname.isNotEmpty ? partnerNickname[0].toUpperCase() : 'P';
    return Tooltip(
      message: isPartnerTouching ? '$partnerNickname is touching!' : '$partnerNickname connected',
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.08),
          border: Border.all(
            color: isPartnerTouching
                ? const Color(0xFF10B981)
                : Colors.white.withOpacity(0.12),
            width: isPartnerTouching ? 1.5 : 1.0,
          ),
          boxShadow: isPartnerTouching
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.5),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              initial,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isPartnerTouching ? const Color(0xFF6EE7B7) : Colors.white70,
              ),
            ),
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPartnerTouching
                      ? const Color(0xFF10B981)
                      : const Color(0xFF38BDF8),
                  border: Border.all(color: const Color(0xFF14121E), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: (isPartnerTouching
                              ? const Color(0xFF10B981)
                              : const Color(0xFF38BDF8))
                          .withOpacity(0.8),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // MODE 1: FULL-SCREEN THUMB-KISS (Physical Shockwaves & Sync)
  // -------------------------------------------------------------
  Widget _buildFullScreenThumbKiss({
    required Size padSize,
    required StageProvider stageProvider,
    required String spaceId,
    required String userId,
    required dynamic partnerTouch,
    required bool isPartnerTouching,
    required String partnerNickname,
  }) {
    Offset? partnerPixel;
    if (partnerTouch != null) {
      partnerPixel = Offset(partnerTouch.x * padSize.width, partnerTouch.y * padSize.height);
    }

    if (_isMyThumbDown && _myThumbPoint != null && partnerPixel != null) {
      final dist = (_myThumbPoint! - partnerPixel).distance;
      if (dist < 48.0) {
        if (!_isColliding) {
          _isColliding = true;
          _startContinuousHeartbeat();
        }
      } else {
        if (_isColliding) {
          _isColliding = false;
        }
      }
    } else {
      if (_isColliding) {
        _isColliding = false;
        _stopContinuousHeartbeat();
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (details) {
        setState(() {
          _isMyThumbDown = true;
          _myThumbPoint = details.localPosition;
        });
        HapticFeedback.lightImpact();
        if (spaceId.isNotEmpty && userId.isNotEmpty) {
          _handleThumbMove(details.localPosition, padSize, stageProvider, spaceId, userId, true, force: true);
        }
      },
      onPanUpdate: (details) {
        setState(() {
          _myThumbPoint = details.localPosition;
        });
        if (spaceId.isNotEmpty && userId.isNotEmpty) {
          _handleThumbMove(details.localPosition, padSize, stageProvider, spaceId, userId, true, force: false);
        }
      },
      onPanEnd: (_) {
        setState(() {
          _isMyThumbDown = false;
          _isColliding = false;
        });
        _stopContinuousHeartbeat();
        if (spaceId.isNotEmpty && userId.isNotEmpty) {
          _handleThumbMove(_myThumbPoint ?? Offset.zero, padSize, stageProvider, spaceId, userId, false, force: true);
        }
      },
      onPanCancel: () {
        setState(() {
          _isMyThumbDown = false;
          _isColliding = false;
        });
        _stopContinuousHeartbeat();
        if (spaceId.isNotEmpty && userId.isNotEmpty) {
          _handleThumbMove(_myThumbPoint ?? Offset.zero, padSize, stageProvider, spaceId, userId, false, force: true);
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _collisionController]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                size: padSize,
                painter: _FullScreenThumbKissPainter(
                  isMyThumbDown: _isMyThumbDown,
                  myThumb: _myThumbPoint,
                  partnerThumb: partnerPixel,
                  isColliding: _isColliding,
                  pulseVal: _pulseController.value,
                  collisionVal: _collisionController.value,
                ),
              ),

              // Sleek, refined Initial Prompt (When neither user is touching)
              if (!_isMyThumbDown && !isPartnerTouching)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFFF4B72).withOpacity(0.22),
                              const Color(0xFFFF4B72).withOpacity(0.04),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFFFF4B72).withOpacity(0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4B72).withOpacity(0.25 * _pulseController.value),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Transform.scale(
                          scale: 1.0 + (_pulseController.value * 0.08),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            size: 32,
                            color: Color(0xFFFF4B72),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Touch Anywhere to Connect',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Move freely across the screen with $partnerNickname ✦',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThumbKissStatusPill(bool isPartnerTouching, String partnerNickname) {
    String text;
    IconData icon;
    Color glowColor;

    if (_isColliding) {
      text = '✨ Pure Thumb Kiss! Colliding in Space ✨';
      icon = Icons.auto_awesome_rounded;
      glowColor = const Color(0xFFFF2D55);
    } else if (_isMyThumbDown && isPartnerTouching) {
      text = '$partnerNickname is here! Move closer to kiss ❤️';
      icon = Icons.favorite_rounded;
      glowColor = const Color(0xFFFF4B72);
    } else if (_isMyThumbDown) {
      text = 'Holding space... Waiting for $partnerNickname ✦';
      icon = Icons.hourglass_top_rounded;
      glowColor = Colors.white24;
    } else if (isPartnerTouching) {
      text = '$partnerNickname is touching the screen! Touch to connect ✦';
      icon = Icons.touch_app_rounded;
      glowColor = const Color(0xFF00E5FF);
    } else {
      text = 'Rest your thumb to feel physical touch ripples';
      icon = Icons.fingerprint_rounded;
      glowColor = Colors.white12;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF14121E).withOpacity(0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isColliding
                ? const Color(0xFFFF2D55)
                : (isPartnerTouching
                    ? const Color(0xFF00E5FF).withOpacity(0.5)
                    : Colors.white.withOpacity(0.1)),
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: _isColliding
                  ? Colors.white
                  : (isPartnerTouching ? const Color(0xFF38BDF8) : Colors.white70),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // MODE 2: FULL-SCREEN GLOW TRACE (Live Collaborative Drawing)
  // -------------------------------------------------------------
  Widget _buildFullScreenGlowTrace({
    required Size padSize,
    required StageProvider stageProvider,
    required String spaceId,
    required String userId,
    required String partnerNickname,
  }) {
    final strokes = stageProvider.drawingStrokes;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            final nx = (details.localPosition.dx / padSize.width).clamp(0.0, 1.0);
            final ny = (details.localPosition.dy / padSize.height).clamp(0.0, 1.0);
            if (_selectedTool == 'eraser') {
              setState(() {
                _eraserTouchPoint = details.localPosition;
              });
              if (spaceId.isNotEmpty && userId.isNotEmpty) {
                stageProvider.eraseStrokesNear(nx, ny, 0.045, spaceId, userId);
              }
              return;
            }
            final norm = StrokePoint(
              double.parse(nx.toStringAsFixed(4)),
              double.parse(ny.toStringAsFixed(4)),
            );
            setState(() {
              _activePoints = [norm];
            });
          },
          onPanUpdate: (details) {
            final nx = (details.localPosition.dx / padSize.width).clamp(0.0, 1.0);
            final ny = (details.localPosition.dy / padSize.height).clamp(0.0, 1.0);
            if (_selectedTool == 'eraser') {
              setState(() {
                _eraserTouchPoint = details.localPosition;
              });
              if (spaceId.isNotEmpty && userId.isNotEmpty) {
                stageProvider.eraseStrokesNear(nx, ny, 0.045, spaceId, userId);
              }
              return;
            }
            if (_activePoints != null && _activePoints!.isNotEmpty) {
              final last = _activePoints!.last;
              final dx = nx - last.x;
              final dy = ny - last.y;
              // Filter consecutive points within 0.005 distance (~2-3px) to prevent payload bloat
              if ((dx * dx + dy * dy) < 0.00003) {
                return;
              }
            }
            final norm = StrokePoint(
              double.parse(nx.toStringAsFixed(4)),
              double.parse(ny.toStringAsFixed(4)),
            );
            setState(() {
              _activePoints?.add(norm);
            });
          },
          onPanEnd: (_) {
            if (_selectedTool == 'eraser') {
              setState(() {
                _eraserTouchPoint = null;
              });
              return;
            }
            if (_activePoints != null && _activePoints!.isNotEmpty) {
              List<StrokePoint> optimizedPoints = _activePoints!;
              if (optimizedPoints.length > 100) {
                final step = (optimizedPoints.length / 100.0).ceil();
                final sampled = <StrokePoint>[];
                for (int i = 0; i < optimizedPoints.length; i += step) {
                  sampled.add(optimizedPoints[i]);
                }
                if (sampled.last != optimizedPoints.last) {
                  sampled.add(optimizedPoints.last);
                }
                optimizedPoints = sampled;
              }

              final newStroke = DrawingStroke(
                points: optimizedPoints,
                colorValue: _selectedColor.value,
                strokeWidth: _selectedWidth,
                tool: _selectedTool,
              );
              if (spaceId.isNotEmpty && userId.isNotEmpty) {
                stageProvider.addDrawingStroke(newStroke, spaceId, userId);
              }
            }
            setState(() {
              _activePoints = null;
            });
          },
          onPanCancel: () {
            setState(() {
              _eraserTouchPoint = null;
              _activePoints = null;
            });
          },
          child: CustomPaint(
            size: padSize,
            painter: _FullScreenGlowDrawingPainter(
              strokes: strokes,
              activePoints: _activePoints,
              activeColor: _selectedColor,
              activeWidth: _selectedWidth,
              activeTool: _selectedTool,
              eraserPoint: _eraserTouchPoint,
            ),
          ),
        ),

        // Pristine Hint when canvas has no strokes
        if (strokes.isEmpty && (_activePoints == null || _activePoints!.isEmpty))
          Center(
            child: IgnorePointer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 40,
                    color: const Color(0xFF00E5FF).withOpacity(0.35),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Full-Screen Glow Canvas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Draw glowing messages with $partnerNickname in real-time ✦',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGlowToolBar({
    required StageProvider stageProvider,
    required String spaceId,
    required String userId,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF14121E).withOpacity(0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Tool Selectors (Pen, Stardust, Eraser)
          _buildToolButton('pen', Icons.edit_rounded, 'Pen'),
          const SizedBox(width: 3),
          _buildToolButton('stardust', Icons.auto_awesome_rounded, 'Glow'),
          const SizedBox(width: 3),
          _buildToolButton('eraser', Icons.auto_fix_high_rounded, 'Eraser'),

          const SizedBox(width: 6),

          // 2. Middle Palette or Eraser guidance
          Expanded(
            child: _selectedTool == 'eraser'
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app_rounded, size: 12, color: Color(0xFFF43F5E)),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Rub to erase',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildColorPill(const Color(0xFFFF4B72)),
                      _buildColorPill(const Color(0xFF00E5FF)),
                      _buildColorPill(const Color(0xFFFBBF24)),
                      _buildColorPill(const Color(0xFF34D399)),
                      _buildColorPill(const Color(0xFFFFFFFF)),
                    ],
                  ),
          ),

          const SizedBox(width: 6),

          // 3. Clear Canvas Button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if (spaceId.isNotEmpty) {
                stageProvider.clearDrawing(spaceId, userId);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline_rounded, size: 14, color: Colors.white70),
                  SizedBox(width: 3),
                  Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(String tool, IconData icon, String label) {
    final isSelected = _selectedTool == tool;
    final activeColor = tool == 'eraser' ? const Color(0xFFF43F5E) : AppColors.terra;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedTool = tool;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 8 : 6, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? activeColor : Colors.white60,
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.white60,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildColorPill(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedColor = color;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2.5),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.8),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // MODE 3: FULL-SCREEN HEART PULSE (3D Ripples & Daily Counters)
  // -------------------------------------------------------------
  Widget _buildFullScreenHeartPulse({
    required Size padSize,
    required StageProvider stageProvider,
    required String spaceId,
    required String userId,
    required String partnerNickname,
  }) {
    final myCount = stageProvider.myDailyTouches;
    final partnerCount = stageProvider.partnerDailyTouches;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final now = DateTime.now().millisecondsSinceEpoch;
        setState(() {
          _waterRipples.removeWhere((r) => (now - r.startTimeMs) > 1300);
          if (_waterRipples.length >= 4) {
            _waterRipples.removeAt(0);
          }
          _waterRipples.add(_WaterRipple(
            position: details.localPosition,
            startTimeMs: now,
          ));
        });
        HapticFeedback.lightImpact();
        _playWaterDropSound();
        if (spaceId.isNotEmpty && userId.isNotEmpty) {
          stageProvider.incrementMyTouch(spaceId, userId, partnerNickname);
          stageProvider.sendPulse(spaceId, userId, 'Partner');
        }
      },
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                size: padSize,
                painter: _FullScreenWaterRipplePainter(
                  ripples: _waterRipples,
                ),
              ),

              // Floating 3D Heart Daily Counter Cards (Dynamic top clearance below the header bar)
              Positioned(
                top: MediaQuery.of(context).padding.top + 68,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildGlassHeartCard(
                        partnerNickname,
                        partnerCount,
                        const Color(0xFF38BDF8), // Sky Blue
                        Icons.favorite_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildGlassHeartCard(
                        'You',
                        myCount,
                        const Color(0xFFF43F5E), // Rose Pink
                        Icons.favorite_rounded,
                      ),
                    ),
                  ],
                ),
              ),

              // Center Pulse Hint
              if (_waterRipples.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF43F5E).withOpacity(0.12),
                          border: Border.all(
                            color: const Color(0xFFF43F5E).withOpacity(0.3),
                          ),
                        ),
                        child: Transform.scale(
                          scale: 1.0 + (_waveController.value * 0.12),
                          child: const Icon(
                            Icons.favorite_rounded,
                            size: 56,
                            color: Color(0xFFF43F5E),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Tap anywhere to send a gentle water wave',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Every touch ripples softly to $partnerNickname ✦',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlassHeartCard(String name, int count, Color accent, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF14121E).withOpacity(0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.15),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count touches',
                  style: TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// HARDWARE-ACCELERATED PAINTERS FOR FULL-SCREEN RESPONSIVENESS
// =============================================================================

class _WaterRipple {
  final Offset position;
  final int startTimeMs;

  _WaterRipple({
    required this.position,
    required this.startTimeMs,
  });
}

class _FullScreenThumbKissPainter extends CustomPainter {
  final bool isMyThumbDown;
  final Offset? myThumb;
  final Offset? partnerThumb;
  final bool isColliding;
  final double pulseVal;
  final double collisionVal;

  _FullScreenThumbKissPainter({
    required this.isMyThumbDown,
    required this.myThumb,
    required this.partnerThumb,
    required this.isColliding,
    required this.pulseVal,
    required this.collisionVal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dual Touch Luminous Filament (when both touch at the same time)
    if (isMyThumbDown && myThumb != null && partnerThumb != null) {
      final midPoint = Offset(
        (myThumb!.dx + partnerThumb!.dx) / 2,
        (myThumb!.dy + partnerThumb!.dy) / 2,
      );
      final dist = (myThumb! - partnerThumb!).distance;

      if (!isColliding) {
        // Soft glowing light thread connecting both thumbs
        final proximity = (1.0 - (dist / 400.0)).clamp(0.2, 1.0);

        final threadGlow = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
          ..color = const Color(0xFFFF4B72).withOpacity(0.4 * proximity);
        canvas.drawLine(myThumb!, partnerThumb!, threadGlow);

        final threadCore = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withOpacity(0.6 * proximity);
        canvas.drawLine(myThumb!, partnerThumb!, threadCore);

        // Subtle traveling light motes along the connection thread
        for (int i = 0; i < 2; i++) {
          final travel = (pulseVal + (i * 0.5)) % 1.0;
          final motePos = Offset(
            myThumb!.dx + (partnerThumb!.dx - myThumb!.dx) * travel,
            myThumb!.dy + (partnerThumb!.dy - myThumb!.dy) * travel,
          );
          final motePaint = Paint()..color = Colors.white.withOpacity(0.75 * proximity);
          canvas.drawCircle(motePos, 2.0, motePaint);
        }
      } else {
        // Colliding: Soft Heart Bloom between both thumbs
        _drawCollisionHeartBloom(canvas, midPoint);
      }
    }

    // 2. Render Partner's Thumb aura (Electric Cyan)
    if (partnerThumb != null) {
      _drawIntimateThumbAura(
        canvas: canvas,
        center: partnerThumb!,
        baseColor: const Color(0xFF00E5FF),
        pulseProgress: pulseVal,
      );
    }

    // 3. Render My Thumb aura (Coral Rose)
    if (isMyThumbDown && myThumb != null) {
      _drawIntimateThumbAura(
        canvas: canvas,
        center: myThumb!,
        baseColor: const Color(0xFFFF4B72),
        pulseProgress: pulseVal,
      );
    }
  }

  void _drawIntimateThumbAura({
    required Canvas canvas,
    required Offset center,
    required Color baseColor,
    required double pulseProgress,
  }) {
    // A. Soft ambient radial aura directly under thumb (max 38dp)
    final auraRadius = 24.0 + (pulseProgress * 8.0);
    final auraPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
      ..color = baseColor.withOpacity(0.5);
    canvas.drawCircle(center, auraRadius, auraPaint);

    // B. Single delicate breathing wave ring
    final ringRadius = 22.0 + (pulseProgress * 14.0);
    final ringAlpha = (1.0 - pulseProgress).clamp(0.0, 1.0);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = baseColor.withOpacity(ringAlpha * 0.45);
    canvas.drawCircle(center, ringRadius, ringPaint);

    // C. Luminous Shimmer Core
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          baseColor,
          baseColor.withOpacity(0.1),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 14.0));
    canvas.drawCircle(center, 14.0, corePaint);

    // D. Center Touch Anchor Dot
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 3.0, dotPaint);
  }

  void _drawCollisionHeartBloom(Canvas canvas, Offset midPoint) {
    final bloomRadius = 24.0 + (collisionVal * 16.0);
    final bloomAlpha = (1.0 - collisionVal * 0.4).clamp(0.0, 1.0);

    // Warm radial glow bloom
    final bloomPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16)
      ..color = const Color(0xFFFF2D55).withOpacity(0.5 * bloomAlpha);
    canvas.drawCircle(midPoint, bloomRadius, bloomPaint);

    // Golden halo ring
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * (1.0 - collisionVal)
      ..color = const Color(0xFFFFD700).withOpacity(bloomAlpha * 0.7);
    canvas.drawCircle(midPoint, bloomRadius * 1.1, haloPaint);

    // Mini glowing heart centered right where thumbs meet
    _drawMiniGlowingHeart(
      canvas,
      midPoint,
      14.0 + (collisionVal * 3.0),
      Colors.white.withOpacity(0.95),
    );

    // Delicate star sparks orbiting closely
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3) + (collisionVal * 0.9);
      final dist = 14.0 + (collisionVal * 16.0);
      final sparkOffset = Offset(
        midPoint.dx + math.cos(angle) * dist,
        midPoint.dy + math.sin(angle) * dist,
      );
      final sparkPaint = Paint()
        ..color = (i % 2 == 0 ? Colors.white : const Color(0xFFFFD700))
            .withOpacity(bloomAlpha * 0.85);
      canvas.drawCircle(sparkOffset, 2.0 * bloomAlpha, sparkPaint);
    }
  }

  void _drawMiniGlowingHeart(Canvas canvas, Offset center, double size, Color color) {
    final path = Path();
    final half = size / 2;

    path.moveTo(center.dx, center.dy + half * 0.5);
    path.cubicTo(
      center.dx + half * 1.2, center.dy - half * 0.3,
      center.dx + half * 0.8, center.dy - half * 1.1,
      center.dx, center.dy - half * 0.4,
    );
    path.cubicTo(
      center.dx - half * 0.8, center.dy - half * 1.1,
      center.dx - half * 1.2, center.dy - half * 0.3,
      center.dx, center.dy + half * 0.5,
    );
    path.close();

    final glow = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..color = const Color(0xFFFF2D55).withOpacity(0.6);
    canvas.drawPath(path, glow);

    final core = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawPath(path, core);
  }

  @override
  bool shouldRepaint(covariant _FullScreenThumbKissPainter old) => true;
}

class _FullScreenGlowDrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final List<StrokePoint>? activePoints;
  final Color activeColor;
  final double activeWidth;
  final String activeTool;
  final Offset? eraserPoint;

  _FullScreenGlowDrawingPainter({
    required this.strokes,
    required this.activePoints,
    required this.activeColor,
    required this.activeWidth,
    required this.activeTool,
    this.eraserPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, size, stroke.points, Color(stroke.colorValue), stroke.strokeWidth, stroke.tool);
    }

    if (activePoints != null && activePoints!.isNotEmpty) {
      _drawStroke(canvas, size, activePoints!, activeColor, activeWidth, activeTool);
    }

    // Render soft translucent eraser reticle
    if (eraserPoint != null) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withOpacity(0.85);
      canvas.drawCircle(eraserPoint!, 18.0, ringPaint);

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFF43F5E).withOpacity(0.18);
      canvas.drawCircle(eraserPoint!, 18.0, fillPaint);
    }
  }

  void _drawStroke(
    Canvas canvas,
    Size size,
    List<StrokePoint> points,
    Color color,
    double width,
    String tool,
  ) {
    if (points.isEmpty) return;

    final path = Path();
    final first = Offset(points.first.x * size.width, points.first.y * size.height);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < points.length; i++) {
      final curr = Offset(points[i].x * size.width, points[i].y * size.height);
      path.lineTo(curr.dx, curr.dy);
    }

    if (tool == 'stardust') {
      final sparkPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withOpacity(0.8);

      for (int i = 0; i < points.length; i += 2) {
        final p = Offset(points[i].x * size.width, points[i].y * size.height);
        canvas.drawCircle(p, width * 0.8, sparkPaint);
      }
    } else {
      // Glow Outer Layer
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width + 6.0
        ..color = color.withOpacity(0.35);
      canvas.drawPath(path, glowPaint);

      // Crisp Core Line
      final corePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = width
        ..color = color;
      canvas.drawPath(path, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FullScreenGlowDrawingPainter old) => true;
}

class _FullScreenWaterRipplePainter extends CustomPainter {
  final List<_WaterRipple> ripples;

  _FullScreenWaterRipplePainter({
    required this.ripples,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final ripple in ripples) {
      final elapsed = (now - ripple.startTimeMs) / 1100.0;
      if (elapsed < 0.0 || elapsed > 1.0) continue;

      final progress = Curves.easeOutCubic.transform(elapsed);
      final fade = (1.0 - progress).clamp(0.0, 1.0);

      // 1. Primary water crest wave
      final r1 = 10.0 + progress * 135.0;
      final p1 = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.2 * fade).clamp(0.6, 2.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5)
        ..color = const Color(0xFFF43F5E).withOpacity(fade * 0.65);
      canvas.drawCircle(ripple.position, r1, p1);

      // 2. Secondary refraction wave following closely behind
      final subProgress = (progress - 0.12).clamp(0.0, 1.0);
      if (subProgress > 0) {
        final r2 = 6.0 + subProgress * 105.0;
        final subFade = (1.0 - subProgress).clamp(0.0, 1.0);
        final p2 = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1.4 * subFade).clamp(0.4, 2.0)
          ..color = const Color(0xFFFF8FA3).withOpacity(subFade * 0.38);
        canvas.drawCircle(ripple.position, r2, p2);
      }

      // 3. Delicate droplet impact epicenter
      if (progress < 0.35) {
        final dropAlpha = (1.0 - (progress / 0.35)).clamp(0.0, 1.0);
        final dropPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white.withOpacity(dropAlpha * 0.85);
        canvas.drawCircle(ripple.position, 3.5 * dropAlpha, dropPaint);

        final glowPaint = Paint()
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..color = const Color(0xFFF43F5E).withOpacity(dropAlpha * 0.5);
        canvas.drawCircle(ripple.position, 12.0 * dropAlpha, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FullScreenWaterRipplePainter old) => true;
}
