import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
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

  // Controls visibility inside the video card
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _callService.listenForCalls(roomCode: widget.roomCode, myUid: widget.myUid);
    _startControlsHideTimer();
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

  /// 1. Incoming Call Prompt Banner
  Widget _buildRingingBanner() {
    final callerName = _callService.callerNameNotifier.value.isNotEmpty
        ? _callService.callerNameNotifier.value
        : widget.partnerName;

    return Positioned(
      top: widget.isLandscape ? 16 : 44,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F).withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.terra.withOpacity(0.8), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.terra.withOpacity(0.3),
                backgroundImage: widget.partnerAvatarUrl != null && widget.partnerAvatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(widget.partnerAvatarUrl!)
                    : null,
                child: widget.partnerAvatarUrl == null || widget.partnerAvatarUrl!.isEmpty
                    ? Text(
                        callerName.isNotEmpty ? callerName[0].toUpperCase() : 'P',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.terra),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      callerName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Incoming video call 📹',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              // Decline Button
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _callService.declineCall();
                },
                icon: const Icon(Icons.call_end_rounded, color: Colors.redAccent, size: 26),
                tooltip: 'Decline',
              ),
              const SizedBox(width: 4),
              // Answer Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _callService.answerCall(
                    roomCode: widget.roomCode,
                    myUid: widget.myUid,
                    myName: widget.myName,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981), // Emerald green
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
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
                  height: 33, // 16:10 mini thumbnail
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

              // 5. Bottom Controls Bar on the video box (End call, mute, video on/off)
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
                              color: Color(0xFFEF4444), // Red
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

  /// 4. Maximized View (Expands vertically and horizontally like live chat)
  Widget _buildMaximizedView() {
    final screenSize = MediaQuery.of(context).size;

    if (widget.isLandscape) {
      // Landscape: Expands as a vertical column on the right side (top to down almost)
      final panelWidth = math.min(320.0, screenSize.width * 0.38);

      return Positioned(
        top: 12,
        bottom: 12,
        right: 12,
        width: panelWidth,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414).withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.terra.withOpacity(0.6), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(-4, 0)),
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
                        widget.partnerName,
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
                    const SizedBox(width: 10),
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

              // Partner video (Large)
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _callService.isPartnerCameraOff,
                      builder: (context, isCameraOff, _) {
                        if (isCameraOff || _callService.remoteRenderer.srcObject == null) {
                          return _buildPartnerAvatarPlaceholder(compact: false);
                        }
                        return RTCVideoView(
                          _callService.remoteRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        );
                      },
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.white12),

              // My camera (Secondary section)
              Expanded(
                flex: 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _callService.isCameraOff,
                      builder: (context, isCameraOff, _) {
                        if (isCameraOff || _callService.localRenderer.srcObject == null) {
                          return Container(
                            color: const Color(0xFF1C1C1E),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videocam_off_rounded, size: 24, color: Colors.white38),
                                  SizedBox(height: 4),
                                  Text('Camera is off', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              ),
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
                    // "You" label
                    Positioned(
                      top: 6,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('You', style: TextStyle(fontSize: 10, color: Colors.white70)),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Call Action Controls
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
      // Portrait: Expands vertically to half screen
      final height = screenSize.height * 0.48;

      return Positioned(
        top: 60,
        left: 12,
        right: 12,
        height: height,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414).withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.terra.withOpacity(0.6), width: 1.5),
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
                        widget.partnerName,
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

              // Partner video + local PiP
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _callService.isPartnerCameraOff,
                      builder: (context, isCameraOff, _) {
                        if (isCameraOff || _callService.remoteRenderer.srcObject == null) {
                          return _buildPartnerAvatarPlaceholder(compact: false);
                        }
                        return RTCVideoView(
                          _callService.remoteRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        );
                      },
                    ),

                    // Local user PiP
                    Positioned(
                      bottom: 12,
                      right: 12,
                      width: 90,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _callService.isCameraOff,
                          builder: (context, isCameraOff, _) {
                            if (isCameraOff || _callService.localRenderer.srcObject == null) {
                              return const Center(
                                child: Icon(Icons.videocam_off_rounded, size: 18, color: Colors.white54),
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
