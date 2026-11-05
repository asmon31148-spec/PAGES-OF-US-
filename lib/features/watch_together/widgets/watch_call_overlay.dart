import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../services/watch_call_service.dart';

class WatchCallOverlay extends StatefulWidget {
  final String roomCode;
  final String myUid;
  final String myName;
  final String? partnerAvatarUrl;
  final String partnerName;
  final bool isLandscape;

  const WatchCallOverlay({
    super.key,
    required this.roomCode,
    required this.myUid,
    required this.myName,
    this.partnerAvatarUrl,
    required this.partnerName,
    this.isLandscape = false,
  });

  @override
  State<WatchCallOverlay> createState() => _WatchCallOverlayState();
}

class _WatchCallOverlayState extends State<WatchCallOverlay> {
  final WatchCallService _callService = WatchCallService.instance;

  // Draggable PiP position (null until initialized on first layout)
  Offset? _pipPosition;

  // Maximize / Minimize state
  bool _isMaximized = false;

  // Swap video in maximized view (so user can toggle who is in full height vs PiP)
  bool _isSwappedInMaximized = false;

  // Controls visibility inside the video card
  bool _showControls = true;
  Timer? _hideControlsTimer;

  // Ringing haptic feedback timer
  Timer? _ringingHapticTimer;

  @override
  void initState() {
    super.initState();
    _callService.listenForCalls(roomCode: widget.roomCode, myUid: widget.myUid);
    _callService.callStatus.addListener(_onCallStatusChanged);
    _startControlsHideTimer();
  }

  @override
  void didUpdateWidget(WatchCallOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.myUid != widget.myUid || oldWidget.roomCode != widget.roomCode) {
      _callService.listenForCalls(roomCode: widget.roomCode, myUid: widget.myUid);
    }
  }

  void _onCallStatusChanged() {
    if (!mounted) return;
    if (_callService.callStatus.value == WatchCallStatus.ringing) {
      _startRingingHaptics();
    } else {
      _stopRingingHaptics();
    }
  }

  void _startRingingHaptics() {
    _ringingHapticTimer?.cancel();
    HapticFeedback.heavyImpact();
    _ringingHapticTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      HapticFeedback.heavyImpact();
    });
  }

  void _stopRingingHaptics() {
    _ringingHapticTimer?.cancel();
    _ringingHapticTimer = null;
  }

  void _startControlsHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    HapticFeedback.selectionClick();
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsHideTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _toggleMaximize() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isMaximized = !_isMaximized;
      _showControls = true;
    });
    _startControlsHideTimer();
  }

  @override
  void dispose() {
    _stopRingingHaptics();
    _callService.callStatus.removeListener(_onCallStatusChanged);
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WatchCallStatus>(
      valueListenable: _callService.callStatus,
      builder: (context, status, _) {
        if (status == WatchCallStatus.idle) {
          return const SizedBox.shrink();
        }

        if (status == WatchCallStatus.ringing) {
          return _buildRingingBanner();
        }

        if (status == WatchCallStatus.calling) {
          return _buildCallingIndicator();
        }

        if (status == WatchCallStatus.connected) {
          return _isMaximized ? _buildMaximizedView() : _buildCompactPip();
        }

        return const SizedBox.shrink();
      },
    );
  }

  /// 1. Incoming Call Prompt Banner (High-Visibility with Ringing Haptics)
  Widget _buildRingingBanner() {
    final callerName = _callService.callerNameNotifier.value.isNotEmpty
        ? _callService.callerNameNotifier.value
        : widget.partnerName;

    return Positioned(
      top: widget.isLandscape ? 16 : 48,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B).withOpacity(0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF10B981), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              const BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              // Pulsing green call icon & Avatar
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.terra.withOpacity(0.3),
                    backgroundImage: widget.partnerAvatarUrl != null && widget.partnerAvatarUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(widget.partnerAvatarUrl!)
                        : null,
                    child: widget.partnerAvatarUrl == null || widget.partnerAvatarUrl!.isEmpty
                        ? Text(
                            callerName.isNotEmpty ? callerName[0].toUpperCase() : 'P',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.terra, fontSize: 16),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      callerName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Incoming video call 📹',
                      style: TextStyle(fontSize: 12, color: Color(0xFF34D399), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              // Decline Button
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _stopRingingHaptics();
                  _callService.declineCall();
                },
                icon: const Icon(Icons.call_end_rounded, color: Colors.redAccent, size: 28),
                tooltip: 'Decline',
              ),
              const SizedBox(width: 6),
              // Answer Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _stopRingingHaptics();
                  _callService.answerCall(
                    roomCode: widget.roomCode,
                    myUid: widget.myUid,
                    myName: widget.myName,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981), // Emerald green
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 2. Outgoing Calling Indicator
  Widget _buildCallingIndicator() {
    return Positioned(
      top: widget.isLandscape ? 16 : 44,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.terra.withOpacity(0.6), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.terra),
            ),
            const SizedBox(width: 10),
            Text(
              'Calling ${widget.partnerName}...',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _callService.endCall();
              },
              child: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  /// 3. Compact Draggable Floating Card (SS 3 Reference Match)
  Widget _buildCompactPip() {
    final screenSize = MediaQuery.of(context).size;

    // Compact dimensions matching SS 3
    final cardWidth = widget.isLandscape ? 210.0 : 165.0;
    final cardHeight = widget.isLandscape ? 128.0 : 104.0;

    // Default position: top-right corner with margin
    final defaultX = screenSize.width - cardWidth - 16.0;
    final defaultY = widget.isLandscape ? 44.0 : 56.0;

    _pipPosition ??= Offset(defaultX, defaultY);

    final clampedX = _pipPosition!.dx.clamp(8.0, screenSize.width - cardWidth - 8.0);
    final clampedY = _pipPosition!.dy.clamp(8.0, screenSize.height - cardHeight - 8.0);

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _pipPosition = Offset(clampedX + details.delta.dx, clampedY + details.delta.dy);
          });
        },
        onTap: _toggleControls,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.65),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // 1. Main Partner Video Feed
              Positioned.fill(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _callService.isPartnerCameraOff,
                  builder: (context, isCameraOff, _) {
                    if (isCameraOff || _callService.remoteRenderer.srcObject == null) {
                      return _buildPartnerAvatarPlaceholder(compact: true);
                    }
                    return RTCVideoView(
                      _callService.remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    );
                  },
                ),
              ),

              // 2. Local User Video (Small PiP section for me)
              Positioned(
                bottom: _showControls ? 36 : 8,
                right: 8,
                child: Container(
                  width: 52,
                  height: 33,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _callService.isCameraOff,
                    builder: (context, isCameraOff, _) {
                      if (isCameraOff || _callService.localRenderer.srcObject == null) {
                        return Container(
                          color: Colors.black87,
                          child: const Center(
                            child: Icon(Icons.videocam_off_rounded, size: 14, color: Colors.white54),
                          ),
                        );
                      }
                      return RTCVideoView(
                        _callService.localRenderer,
                        mirror: true,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      );
                    },
                  ),
                ),
              ),

              // 3. Top Row: Mic Status (Left), 6-dot Drag indicator (Center), Maximize button (Right)
              Positioned(
                top: 6,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Mic Mute Button / Status indicator (SS 3 match)
                    ValueListenableBuilder<bool>(
                      valueListenable: _callService.isMicMuted,
                      builder: (context, isMuted, _) {
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _callService.toggleMic();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isMuted ? Colors.redAccent.withOpacity(0.85) : Colors.black.withOpacity(0.55),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),

                    // Subtle 6-dot Drag Handle (SS 3 match: ⠿)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.drag_indicator_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                    ),

                    // Maximize Button (SS 3 match)
                    GestureDetector(
                      onTap: _toggleMaximize,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.open_in_full_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Partner Name (bottom-left if controls hidden)
              if (!_showControls)
                Positioned(
                  bottom: 6,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.partnerName,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              // 5. Bottom Controls Bar on the video box
              if (_showControls)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mic Mute Toggle
                        ValueListenableBuilder<bool>(
                          valueListenable: _callService.isMicMuted,
                          builder: (context, muted, _) {
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _callService.toggleMic();
                              },
                              child: Icon(
                                muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                color: muted ? Colors.redAccent : Colors.white,
                                size: 16,
                              ),
                            );
                          },
                        ),
                        // Video Camera Toggle
                        ValueListenableBuilder<bool>(
                          valueListenable: _callService.isCameraOff,
                          builder: (context, cameraOff, _) {
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _callService.toggleCamera();
                              },
                              child: Icon(
                                cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                                color: cameraOff ? Colors.redAccent : Colors.white,
                                size: 16,
                              ),
                            );
                          },
                        ),
                        // Flip Camera
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _callService.switchCamera();
                          },
                          child: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 16),
                        ),
                        // End Call
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _callService.endCall();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 12),
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
    );
  }

  /// 4. Maximized View (Full Vertical Height in Natural Portrait Aspect Ratio)
  Widget _buildMaximizedView() {
    final screenSize = MediaQuery.of(context).size;

    if (widget.isLandscape) {
      // Landscape: Vertical column on right with full vertical space (no 3:2 letterbox squishing!)
      final panelWidth = math.min(300.0, screenSize.width * 0.35);

      return Positioned(
        top: 10,
        bottom: 10,
        right: 10,
        width: panelWidth,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414).withOpacity(0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.terra.withOpacity(0.65), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black87, blurRadius: 22, offset: Offset(-4, 0)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.black.withOpacity(0.6),
                child: Row(
                  children: [
                    const Icon(Icons.videocam_rounded, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isSwappedInMaximized ? 'You' : widget.partnerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Call Duration
                    ValueListenableBuilder<int>(
                      valueListenable: _callService.callDurationSeconds,
                      builder: (context, _, __) {
                        return Text(
                          _callService.formattedCallDuration,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // Swap Video Feeds button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _isSwappedInMaximized = !_isSwappedInMaximized;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.swap_horiz_rounded, size: 14, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Minimize button
                    GestureDetector(
                      onTap: _toggleMaximize,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_fullscreen_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // Full-Height Video Feed (Gives maximum vertical space without head/body cropping)
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Main Feed: Partner (or swapped You) taking 100% of vertical height
                    ValueListenableBuilder<bool>(
                      valueListenable: _isSwappedInMaximized
                          ? _callService.isCameraOff
                          : _callService.isPartnerCameraOff,
                      builder: (context, isOff, _) {
                        final renderer = _isSwappedInMaximized
                            ? _callService.localRenderer
                            : _callService.remoteRenderer;
                        if (isOff || renderer.srcObject == null) {
                          return _isSwappedInMaximized
                              ? Container(
                                  color: const Color(0xFF1C1C1E),
                                  child: const Center(
                                    child: Icon(Icons.videocam_off_rounded, size: 28, color: Colors.white38),
                                  ),
                                )
                              : _buildPartnerAvatarPlaceholder(compact: false);
                        }
                        return RTCVideoView(
                          renderer,
                          mirror: _isSwappedInMaximized,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        );
                      },
                    ),

                    // Floating Mini PiP (Tall portrait 72x112 aspect ratio, tapped to swap)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _isSwappedInMaximized = !_isSwappedInMaximized;
                          });
                        },
                        child: Container(
                          width: 72,
                          height: 112, // Tall portrait aspect ratio
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 8),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ValueListenableBuilder<bool>(
                                valueListenable: _isSwappedInMaximized
                                    ? _callService.isPartnerCameraOff
                                    : _callService.isCameraOff,
                                builder: (context, isOff, _) {
                                  final pipRenderer = _isSwappedInMaximized
                                      ? _callService.remoteRenderer
                                      : _callService.localRenderer;
                                  if (isOff || pipRenderer.srcObject == null) {
                                    return Container(
                                      color: const Color(0xFF1C1C1E),
                                      child: const Center(
                                        child: Icon(Icons.videocam_off_rounded, size: 16, color: Colors.white54),
                                      ),
                                    );
                                  }
                                  return RTCVideoView(
                                    pipRenderer,
                                    mirror: !_isSwappedInMaximized,
                                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                  );
                                },
                              ),
                              Positioned(
                                bottom: 4,
                                left: 5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _isSwappedInMaximized ? widget.partnerName : 'You',
                                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Call Action Controls
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                color: Colors.black.withOpacity(0.75),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mic
                    ValueListenableBuilder<bool>(
                      valueListenable: _callService.isMicMuted,
                      builder: (context, muted, _) {
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _callService.toggleMic();
                          },
                          child: CircleAvatar(
                            radius: 17,
                            backgroundColor: muted ? Colors.redAccent : Colors.white.withOpacity(0.2),
                            child: Icon(
                              muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    // Camera
                    ValueListenableBuilder<bool>(
                      valueListenable: _callService.isCameraOff,
                      builder: (context, cameraOff, _) {
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _callService.toggleCamera();
                          },
                          child: CircleAvatar(
                            radius: 17,
                            backgroundColor: cameraOff ? Colors.redAccent : Colors.white.withOpacity(0.2),
                            child: Icon(
                              cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    // Flip
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _callService.switchCamera();
                      },
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: const Icon(Icons.cameraswitch_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                    // Hangup
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _callService.endCall();
                      },
                      child: const CircleAvatar(
                        radius: 19,
                        backgroundColor: Color(0xFFEF4444),
                        child: Icon(Icons.call_end_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Portrait: Expands vertically
      final height = screenSize.height * 0.52;

      return Positioned(
        top: 60,
        left: 12,
        right: 12,
        height: height,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414).withOpacity(0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.terra.withOpacity(0.65), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 8)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: Colors.black.withOpacity(0.5),
                child: Row(
                  children: [
                    const Icon(Icons.videocam_rounded, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isSwappedInMaximized ? 'You' : widget.partnerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _callService.callDurationSeconds,
                      builder: (context, _, __) {
                        return Text(
                          _callService.formattedCallDuration,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _toggleMaximize,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_fullscreen_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // Full Height Partner Video + Local PiP
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _isSwappedInMaximized
                          ? _callService.isCameraOff
                          : _callService.isPartnerCameraOff,
                      builder: (context, isOff, _) {
                        final renderer = _isSwappedInMaximized
                            ? _callService.localRenderer
                            : _callService.remoteRenderer;
                        if (isOff || renderer.srcObject == null) {
                          return _isSwappedInMaximized
                              ? Container(
                                  color: const Color(0xFF1C1C1E),
                                  child: const Center(
                                    child: Icon(Icons.videocam_off_rounded, size: 28, color: Colors.white38),
                                  ),
                                )
                              : _buildPartnerAvatarPlaceholder(compact: false);
                        }
                        return RTCVideoView(
                          renderer,
                          mirror: _isSwappedInMaximized,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        );
                      },
                    ),

                    // Local user PiP
                    Positioned(
                      bottom: 12,
                      right: 12,
                      width: 80,
                      height: 120,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _isSwappedInMaximized = !_isSwappedInMaximized;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _isSwappedInMaximized
                                ? _callService.isPartnerCameraOff
                                : _callService.isCameraOff,
                            builder: (context, isOff, _) {
                              final pipRenderer = _isSwappedInMaximized
                                  ? _callService.remoteRenderer
                                  : _callService.localRenderer;
                              if (isOff || pipRenderer.srcObject == null) {
                                return const Center(
                                  child: Icon(Icons.videocam_off_rounded, size: 18, color: Colors.white54),
                                );
                              }
                              return RTCVideoView(
                                pipRenderer,
                                mirror: !_isSwappedInMaximized,
                                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Controls
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                color: Colors.black.withOpacity(0.7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mic
                    ValueListenableBuilder<bool>(
                      valueListenable: _callService.isMicMuted,
                      builder: (context, muted, _) {
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _callService.toggleMic();
                          },
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: muted ? Colors.redAccent : Colors.white.withOpacity(0.2),
                            child: Icon(
                              muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    // Video
                    ValueListenableBuilder<bool>(
                      valueListenable: _callService.isCameraOff,
                      builder: (context, cameraOff, _) {
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _callService.toggleCamera();
                          },
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: cameraOff ? Colors.redAccent : Colors.white.withOpacity(0.2),
                            child: Icon(
                              cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    // Flip
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _callService.switchCamera();
                      },
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: const Icon(Icons.cameraswitch_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                    // Hangup
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _callService.endCall();
                      },
                      child: const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFFEF4444),
                        child: Icon(Icons.call_end_rounded, size: 20, color: Colors.white),
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

  Widget _buildPartnerAvatarPlaceholder({required bool compact}) {
    return Container(
      color: const Color(0xFF1F1F1F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: compact ? 18 : 30,
              backgroundColor: AppColors.terra.withOpacity(0.3),
              backgroundImage: widget.partnerAvatarUrl != null && widget.partnerAvatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(widget.partnerAvatarUrl!)
                  : null,
              child: widget.partnerAvatarUrl == null || widget.partnerAvatarUrl!.isEmpty
                  ? Text(
                      widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : 'P',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.terra,
                        fontSize: compact ? 12 : 20,
                      ),
                    )
                  : null,
            ),
            SizedBox(height: compact ? 3 : 8),
            Text(
              widget.partnerName,
              style: TextStyle(
                fontSize: compact ? 9 : 13,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
