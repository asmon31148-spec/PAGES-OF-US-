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

enum TouchPadMode { thumbKiss, sparkTrace, heartPulse }

class StageLiveTouchPad extends StatefulWidget {
  const StageLiveTouchPad({super.key});

  @override
  State<StageLiveTouchPad> createState() => _StageLiveTouchPadState();
}

class _StageLiveTouchPadState extends State<StageLiveTouchPad>
    with TickerProviderStateMixin {
  TouchPadMode _currentMode = TouchPadMode.thumbKiss;

  // Controllers
  late AnimationController _pulseController;
  late AnimationController _collisionController;
  late AnimationController _waveController;
  late final AudioPlayer _audioPlayer;

  // Mode 1: Thumb Kiss state
  bool _isMyThumbDown = false;
  Offset? _myThumbPoint;
  Timer? _heartbeatTimer;
  bool _isColliding = false;

  // Mode 2: Spark Trace state
  String _selectedTool = 'pen'; // 'pen', 'stardust', 'eraser'
  Color _selectedColor = const Color(0xFFE2847A);
  final double _selectedWidth = 3.5;
  List<StrokePoint>? _activePoints;

  // Mode 3: Heart Pulse state
  final List<Offset> _3dWavePoints = [];
  Timer? _padToneDebounce;

  @override
  void initState() {
    super.initState();
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
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _padToneDebounce?.cancel();
    _pulseController.dispose();
    _collisionController.dispose();
    _waveController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Soft low pad ambient sound effect (volume 0.15)
  Future<void> _playLowPadTone() async {
    if (_padToneDebounce?.isActive ?? false) return;
    _padToneDebounce = Timer(const Duration(milliseconds: 400), () {});

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(0.15);
      await _audioPlayer.play(AssetSource('audio/breeze.mp3'));
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

  void _handleThumbMove(
    Offset local,
    Size size,
    StageProvider stageProvider,
    String spaceId,
    String userId,
    bool isDown,
  ) {
    final nx = (local.dx / size.width).clamp(0.0, 1.0);
    final ny = (local.dy / size.height).clamp(0.0, 1.0);
    stageProvider.sendTouchPadEvent(spaceId, userId, nx, ny, isTouching: isDown);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final authProvider = context.watch<AuthProvider>();
    final stageProvider = context.watch<StageProvider>();
    final user = authProvider.user;
    final space = authProvider.space;
    final partner = authProvider.partner;
    final partnerNickname = partner?.nickname?.isNotEmpty == true ? partner!.nickname! : 'Partner';

    final partnerTouch = stageProvider.partnerTouchPoint;
    final isPartnerTouching = stageProvider.isPartnerTouching;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 310,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16151A) : const Color(0xFFFAF7F5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            // Top Mode Switcher Bar
            _buildModeHeader(isDark),

            // Active Interactive Canvas
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final padSize = Size(constraints.maxWidth, constraints.maxHeight);

                  switch (_currentMode) {
                    case TouchPadMode.thumbKiss:
                      return _buildThumbKissPad(
                        padSize: padSize,
                        isDark: isDark,
                        stageProvider: stageProvider,
                        spaceId: space?.id ?? '',
                        userId: user?.id ?? '',
                        partnerTouch: partnerTouch,
                        isPartnerTouching: isPartnerTouching,
                      );

                    case TouchPadMode.sparkTrace:
                      return _buildSparkTraceCanvas(
                        padSize: padSize,
                        isDark: isDark,
                        stageProvider: stageProvider,
                        spaceId: space?.id ?? '',
                        userId: user?.id ?? '',
                      );

                    case TouchPadMode.heartPulse:
                      return _buildHeartPulseView(
                        padSize: padSize,
                        isDark: isDark,
                        stageProvider: stageProvider,
                        spaceId: space?.id ?? '',
                        userId: user?.id ?? '',
                        partnerNickname: partnerNickname,
                      );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // HEADER MODE SWITCHER
  // -------------------------------------------------------------
  Widget _buildModeHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder.withOpacity(0.5) : AppColors.lightBorder.withOpacity(0.6),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.terra,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TOUCH SANCTUARY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildModePill(
                mode: TouchPadMode.thumbKiss,
                label: 'Thumb-Kiss',
                icon: Icons.fingerprint_rounded,
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildModePill(
                mode: TouchPadMode.sparkTrace,
                label: 'Glow Trace',
                icon: Icons.brush_rounded,
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildModePill(
                mode: TouchPadMode.heartPulse,
                label: 'Miss U',
                icon: Icons.favorite_rounded,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModePill({
    required TouchPadMode mode,
    required String label,
    required IconData icon,
    required bool isDark,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.terra
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.terra.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? AppColors.darkInk : AppColors.lightInk),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // MODE 1: THUMB-KISS (Physical Shockwaves & True Live Sync)
  // -------------------------------------------------------------
  Widget _buildThumbKissPad({
    required Size padSize,
    required bool isDark,
    required StageProvider stageProvider,
    required String spaceId,
    required String userId,
    required dynamic partnerTouch,
    required bool isPartnerTouching,
  }) {
    // Collision check between my thumb and partner's thumb
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
        if (spaceId.isNotEmpty && userId.isNotEmpty) {
          setState(() {
            _isMyThumbDown = true;
            _myThumbPoint = details.localPosition;
          });
          HapticFeedback.lightImpact();
          _handleThumbMove(details.localPosition, padSize, stageProvider, spaceId, userId, true);
        }
      },
      onPanUpdate: (details) {
        if (spaceId.isNotEmpty && userId.isNotEmpty) {
          setState(() {
            _myThumbPoint = details.localPosition;
          });
          _handleThumbMove(details.localPosition, padSize, stageProvider, spaceId, userId, true);
        }
      },
      onPanEnd: (_) {
        if (spaceId.isNotEmpty && userId.isNotEmpty) {
          setState(() {
            _isMyThumbDown = false;
            _isColliding = false;
          });
          _stopContinuousHeartbeat();
          _handleThumbMove(_myThumbPoint ?? Offset.zero, padSize, stageProvider, spaceId, userId, false);
        }
      },
      onPanCancel: () {
        if (spaceId.isNotEmpty && userId.isNotEmpty) {
          setState(() {
            _isMyThumbDown = false;
            _isColliding = false;
          });
          _stopContinuousHeartbeat();
          _handleThumbMove(_myThumbPoint ?? Offset.zero, padSize, stageProvider, spaceId, userId, false);
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _collisionController]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Concentric Water & Shockwave Painter
              CustomPaint(
                size: padSize,
                painter: _ThumbKissPainter(
                  isMyThumbDown: _isMyThumbDown,
                  myThumb: _myThumbPoint,
                  partnerThumb: partnerPixel,
                  isColliding: _isColliding,
                  pulseVal: _pulseController.value,
                  collisionVal: _collisionController.value,
                  isDark: isDark,
                ),
              ),

              // Status Overlays (NO emojis, pure emotional resonant guidance)
              if (!_isMyThumbDown && !isPartnerTouching)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.terra.withOpacity(0.08),
                          border: Border.all(
                            color: AppColors.terra.withOpacity(0.2),
                          ),
                        ),
                        child: Transform.scale(
                          scale: 1.0 + (_pulseController.value * 0.08),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            size: 38,
                            color: AppColors.terra,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Rest thumb here to connect',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Partner moves freely in true live sync ✦',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isMyThumbDown && !isPartnerTouching)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Holding space... Move thumb anywhere ✦',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

              if (!_isMyThumbDown && isPartnerTouching)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.terra.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.terra.withOpacity(0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Text(
                        'Partner is touching the pad! Place thumb to meet ✦',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

              if (_isMyThumbDown && isPartnerTouching && !_isColliding)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF24222B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.terra.withOpacity(0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        'Both present • Bring thumbs together to touch ✦',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.lightInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

              if (_isColliding)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE2847A), Color(0xFFF472B6)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE2847A).withOpacity(0.5),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Text(
                        '✦ Thumbs Connected • Resonating in Unison ✦',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // MODE 2: SPARK TRACE (Live Smooth Glowing Drawing Canvas)
  // -------------------------------------------------------------
  Widget _buildSparkTraceCanvas({
    required Size padSize,
    required bool isDark,
    required StageProvider stageProvider,
    required String spaceId,
    required String userId,
  }) {
    final strokes = stageProvider.drawingStrokes;

    return Stack(
      children: [
        // Touch Drawing Gesture Surface
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            final nx = (details.localPosition.dx / padSize.width).clamp(0.0, 1.0);
            final ny = (details.localPosition.dy / padSize.height).clamp(0.0, 1.0);
            setState(() {
              _activePoints = [StrokePoint(nx, ny)];
            });
            HapticFeedback.selectionClick();
          },
          onPanUpdate: (details) {
            final nx = (details.localPosition.dx / padSize.width).clamp(0.0, 1.0);
            final ny = (details.localPosition.dy / padSize.height).clamp(0.0, 1.0);
            setState(() {
              _activePoints?.add(StrokePoint(nx, ny));
            });
          },
          onPanEnd: (_) {
            if (_activePoints != null && _activePoints!.isNotEmpty && spaceId.isNotEmpty) {
              final stroke = DrawingStroke(
                points: List.from(_activePoints!),
                colorValue: _selectedTool == 'eraser'
                    ? (isDark ? 0xFF16151A : 0xFFFAF7F5)
                    : _selectedColor.value,
                strokeWidth: _selectedTool == 'eraser' ? 14.0 : _selectedWidth,
                tool: _selectedTool,
                isPartner: false,
              );
              stageProvider.addDrawingStroke(stroke, spaceId, userId);
              setState(() {
                _activePoints = null;
              });
            }
          },
          child: CustomPaint(
            size: padSize,
            painter: _GlowDrawingPainter(
              strokes: strokes,
              activePoints: _activePoints,
              activeColor: _selectedTool == 'eraser'
                  ? (isDark ? const Color(0xFF16151A) : const Color(0xFFFAF7F5))
                  : _selectedColor,
              activeWidth: _selectedTool == 'eraser' ? 14.0 : _selectedWidth,
              activeTool: _selectedTool,
              isDark: isDark,
            ),
          ),
        ),

        // Hint when canvas is pristine empty
        if (strokes.isEmpty && (_activePoints == null || _activePoints!.isEmpty))
          Center(
            child: IgnorePointer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.gesture_rounded,
                    size: 32,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Draw together in real-time',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                  ),
                  Text(
                    'Strokes stay live for both of you ✦',
                    style: TextStyle(
                      fontSize: 10,
                      color: (isDark ? AppColors.darkSoft : AppColors.lightSoft).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Bottom Tool Bar (Glow Pen, Stardust, Eraser, Colors, Clear)
        Positioned(
          left: 10,
          right: 10,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF22202A).withOpacity(0.92) : Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // 1. Tool Selectors
                _buildDrawingToolButton('pen', Icons.edit_rounded, 'Glow Pen', isDark),
                const SizedBox(width: 4),
                _buildDrawingToolButton('stardust', Icons.auto_awesome_rounded, 'Stardust', isDark),
                const SizedBox(width: 4),
                _buildDrawingToolButton('eraser', Icons.cleaning_services_rounded, 'Eraser', isDark),

                const Spacer(),

                // 2. Color Palette (if not eraser)
                if (_selectedTool != 'eraser') ...[
                  _buildColorDot(const Color(0xFFE2847A)),
                  _buildColorDot(const Color(0xFFF59E0B)),
                  _buildColorDot(const Color(0xFF34D399)),
                  _buildColorDot(const Color(0xFFFFFFFF)),
                  const SizedBox(width: 8),
                ],

                // 3. Clear Canvas Button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (spaceId.isNotEmpty) {
                      stageProvider.clearDrawing(spaceId, userId);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 13,
                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawingToolButton(String tool, IconData icon, String tooltip, bool isDark) {
    final isSelected = _selectedTool == tool;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedTool = tool;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.terra.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppColors.terra, width: 1.2)
              : null,
        ),
        child: Icon(
          icon,
          size: 14,
          color: isSelected ? AppColors.terra : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedColor = color;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.black26,
            width: isSelected ? 2.0 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // MODE 3: HEART PULSE (3D Touch Wave, Low Pad Ambiance & Daily Miss U Counters)
  // -------------------------------------------------------------
  Widget _buildHeartPulseView({
    required Size padSize,
    required bool isDark,
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
        // Trigger 3D perspective touch waves at local point
        setState(() {
          _3dWavePoints.add(details.localPosition);
          if (_3dWavePoints.length > 6) {
            _3dWavePoints.removeAt(0);
          }
        });
        HapticFeedback.mediumImpact();
        _playLowPadTone();
        if (spaceId.isNotEmpty && userId.isNotEmpty) {
          stageProvider.incrementMyTouch(spaceId, userId, partnerNickname);
        }
      },
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // 3D Perspective Concentric Wave Painter
              CustomPaint(
                size: padSize,
                painter: _Perspective3DWavePainter(
                  wavePoints: _3dWavePoints,
                  waveProgress: _waveController.value,
                  isDark: isDark,
                ),
              ),

              // Two Translucent 3D Heart Glassmorphic Cards (Matching reference image)
              Positioned(
                top: 14,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    // Left Heart: Partner's Count
                    Expanded(
                      child: _buildHeartCard(
                        count: partnerCount,
                        subtitle: 'from $partnerNickname ♡',
                        gradientColors: isDark
                            ? [const Color(0xFF33293A), const Color(0xFF282332)]
                            : [const Color(0xFFFFF1F2), const Color(0xFFFFE4E6)],
                        accentColor: const Color(0xFFE2847A),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Right Heart: My Count
                    Expanded(
                      child: _buildHeartCard(
                        count: myCount,
                        subtitle: 'from Me',
                        gradientColors: isDark
                            ? [const Color(0xFF3D2534), const Color(0xFF2A1C25)]
                            : [const Color(0xFFFFE4EC), const Color(0xFFFCE7F3)],
                        accentColor: const Color(0xFFF472B6),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),

              // Floating Ambient Glowing Heart Particles
              Positioned(
                top: 36,
                left: (padSize.width / 2) - 10,
                child: Transform.translate(
                  offset: Offset(
                    math.sin(_waveController.value * 2 * math.pi) * 4,
                    math.cos(_waveController.value * 2 * math.pi) * 4,
                  ),
                  child: Icon(
                    Icons.favorite,
                    size: 18,
                    color: const Color(0xFFF472B6).withOpacity(0.55),
                  ),
                ),
              ),

              // Bottom Section: "Miss U" Pill Button + Midnight Reset Indicator
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _3dWavePoints.add(Offset(padSize.width / 2, padSize.height * 0.7));
                          if (_3dWavePoints.length > 6) {
                            _3dWavePoints.removeAt(0);
                          }
                        });
                        HapticFeedback.heavyImpact();
                        _playLowPadTone();
                        if (spaceId.isNotEmpty && userId.isNotEmpty) {
                          stageProvider.incrementMyTouch(spaceId, userId, partnerNickname);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFB7185), Color(0xFFF43F5E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF43F5E).withOpacity(0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Miss U',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Resets daily at 12:00 AM • Tap anywhere for 3D wave ✦',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
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

  Widget _buildHeartCard({
    required int count,
    required String subtitle,
    required List<Color> gradientColors,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background soft heart watermark
          Positioned(
            child: Icon(
              Icons.favorite_rounded,
              size: 78,
              color: accentColor.withOpacity(0.08),
            ),
          ),
          // Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF2D2327),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// CUSTOM PAINTER 1: THUMB-KISS SHOCKWAVES (No love emojis, pure physics)
// =========================================================================
class _ThumbKissPainter extends CustomPainter {
  final bool isMyThumbDown;
  final Offset? myThumb;
  final Offset? partnerThumb;
  final bool isColliding;
  final double pulseVal;
  final double collisionVal;
  final bool isDark;

  _ThumbKissPainter({
    required this.isMyThumbDown,
    required this.myThumb,
    required this.partnerThumb,
    required this.isColliding,
    required this.pulseVal,
    required this.collisionVal,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Resonant connecting beam if both are on pad but not yet touching
    if (isMyThumbDown && myThumb != null && partnerThumb != null && !isColliding) {
      final beamPaint = Paint()
        ..color = AppColors.terra.withOpacity(0.3 + (pulseVal * 0.2))
        ..strokeWidth = 6.0 + (pulseVal * 4.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawLine(myThumb!, partnerThumb!, beamPaint);

      final coreBeam = Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(myThumb!, partnerThumb!, coreBeam);
    }

    // 2. My Thumb Waves
    if (isMyThumbDown && myThumb != null) {
      _drawConcentricShockwaves(
        canvas,
        center: myThumb!,
        baseColor: const Color(0xFFE2847A),
        pulse: pulseVal,
      );
    }

    // 3. Partner's Thumb Waves
    if (partnerThumb != null) {
      _drawConcentricShockwaves(
        canvas,
        center: partnerThumb!,
        baseColor: const Color(0xFFF59E0B),
        pulse: 1.0 - pulseVal,
      );
    }

    // 4. Intense Luminous Shockwaves When Thumbs Meet / Collide
    if (isColliding && myThumb != null && partnerThumb != null) {
      final midPoint = Offset(
        (myThumb!.dx + partnerThumb!.dx) / 2,
        (myThumb!.dy + partnerThumb!.dy) / 2,
      );

      // Expanding luminous rings
      for (int i = 0; i < 4; i++) {
        final progress = (collisionVal + (i * 0.25)) % 1.0;
        final radius = 20.0 + (progress * 70.0);
        final opacity = (1.0 - progress).clamp(0.0, 1.0);

        final shockPaint = Paint()
          ..color = const Color(0xFFF472B6).withOpacity(opacity * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * (1.0 - (progress * 0.5))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

        canvas.drawCircle(midPoint, radius, shockPaint);
      }

      // Center luminous plasma core
      final corePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white,
            const Color(0xFFF472B6).withOpacity(0.8),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: midPoint, radius: 26));
      canvas.drawCircle(midPoint, 26, corePaint);
    }
  }

  void _drawConcentricShockwaves(
    Canvas canvas, {
    required Offset center,
    required Color baseColor,
    required double pulse,
  }) {
    // 3 Concentric Expanding Sound/Water Waves
    for (int i = 1; i <= 3; i++) {
      final radius = 22.0 + (i * 12.0) + (pulse * 8.0);
      final wavePaint = Paint()
        ..color = baseColor.withOpacity(0.4 / i)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(center, radius, wavePaint);
    }

    // Glowing core
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          baseColor.withOpacity(0.7),
          baseColor.withOpacity(0.2),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 32));
    canvas.drawCircle(center, 32, glowPaint);

    // Inner physical thumb point
    final corePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 12, corePaint);

    // Sleek white center pip
    final pipPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, pipPaint);
  }

  @override
  bool shouldRepaint(covariant _ThumbKissPainter old) => true;
}

// =========================================================================
// CUSTOM PAINTER 2: SPARK TRACE / GLOW DRAWING
// =========================================================================
class _GlowDrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final List<StrokePoint>? activePoints;
  final Color activeColor;
  final double activeWidth;
  final String activeTool;
  final bool isDark;

  _GlowDrawingPainter({
    required this.strokes,
    required this.activePoints,
    required this.activeColor,
    required this.activeWidth,
    required this.activeTool,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw all persisted committed strokes
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;

      final color = Color(stroke.colorValue);
      final path = Path();
      final p0 = stroke.points.first;
      path.moveTo(p0.x * size.width, p0.y * size.height);

      for (int i = 1; i < stroke.points.length; i++) {
        final p = stroke.points[i];
        path.lineTo(p.x * size.width, p.y * size.height);
      }

      _renderStrokePath(canvas, path, stroke.points, size, color, stroke.strokeWidth, stroke.tool);
    }

    // 2. Draw live currently active stroke
    if (activePoints != null && activePoints!.length >= 2) {
      final path = Path();
      final p0 = activePoints!.first;
      path.moveTo(p0.x * size.width, p0.y * size.height);

      for (int i = 1; i < activePoints!.length; i++) {
        final p = activePoints![i];
        path.lineTo(p.x * size.width, p.y * size.height);
      }

      _renderStrokePath(canvas, path, activePoints!, size, activeColor, activeWidth, activeTool);
    }
  }

  void _renderStrokePath(
    Canvas canvas,
    Path path,
    List<StrokePoint> points,
    Size size,
    Color color,
    double width,
    String tool,
  ) {
    if (tool == 'stardust') {
      // Stardust brush: soft shimmering body + sparkles
      final glowPaint = Paint()
        ..color = color.withOpacity(0.4)
        ..strokeWidth = width * 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawPath(path, glowPaint);

      final corePaint = Paint()
        ..color = color.withOpacity(0.85)
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, corePaint);

      // Stardust points
      for (int i = 0; i < points.length; i += 3) {
        final pt = Offset(points[i].x * size.width, points[i].y * size.height);
        final starPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pt, 1.8, starPaint);
      }
    } else {
      // Glow Pen: smooth solid neon line with soft outer blur
      final glowPaint = Paint()
        ..color = color.withOpacity(0.5)
        ..strokeWidth = width + 5.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawPath(path, glowPaint);

      final corePaint = Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowDrawingPainter old) => true;
}

// =========================================================================
// CUSTOM PAINTER 3: 3D PERSPECTIVE TOUCH WAVE (Low pad ambiance mode)
// =========================================================================
class _Perspective3DWavePainter extends CustomPainter {
  final List<Offset> wavePoints;
  final double waveProgress;
  final bool isDark;

  _Perspective3DWavePainter({
    required this.wavePoints,
    required this.waveProgress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (wavePoints.isEmpty) return;

    for (final center in wavePoints) {
      // Draw 3 concentric perspective flattened ellipses representing 3D ground ripples
      for (int i = 0; i < 3; i++) {
        final progress = (waveProgress + (i * 0.33)) % 1.0;
        final radius = 24.0 + (progress * 80.0);
        final opacity = (1.0 - progress).clamp(0.0, 1.0);

        final wavePaint = Paint()
          ..color = const Color(0xFFF472B6).withOpacity(opacity * 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * (1.0 - (progress * 0.4))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

        // Perspective oval flattening (2.4 : 1.1 aspect ratio gives authentic 3D tilt)
        final rect = Rect.fromCenter(
          center: center,
          width: radius * 2.4,
          height: radius * 1.1,
        );
        canvas.drawOval(rect, wavePaint);
      }

      // Soft center glowing pulse
      final centerGlow = Paint()
        ..color = const Color(0xFFF472B6).withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, 12, centerGlow);
    }
  }

  @override
  bool shouldRepaint(covariant _Perspective3DWavePainter old) => true;
}
