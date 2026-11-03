import 'dart:async';
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

  // Draggable widescreen bar position — starts near bottom, user can drag freely
  Offset _pipPosition = const Offset(16, 300);
  bool _showControls = false;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _callService.listenForCalls(roomCode: widget.roomCode, myUid: widget.myUid);
  }

  void _toggleControls() {
    HapticFeedback.selectionClick();
    setState(() {
      _showControls = !_showControls;
    });

    _hideControlsTimer?.cancel();
    if (_showControls) {
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
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
          return _buildConnectedPip();
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
      top: widget.isLandscape ? 16 : 32,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.terra.withOpacity(0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.terra.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
      top: widget.isLandscape ? 16 : 32,
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

  /// 3. Draggable Connected Widescreen Facecam Bar (Techno Gamerz-style 16:9 streamer overlay)
  Widget _buildConnectedPip() {
    final screenSize = MediaQuery.of(context).size;

    // 16:9 widescreen bar — full width in portrait, 42% width in landscape
    final barWidth = widget.isLandscape
        ? screenSize.width * 0.42
        : screenSize.width - 32.0;
    final barHeight = barWidth * 9.0 / 16.0;

    final clampedX = _pipPosition.dx.clamp(0.0, screenSize.width - barWidth);
    final clampedY = _pipPosition.dy.clamp(0.0, screenSize.height - barHeight - 8.0);

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _pipPosition += details.delta;
          });
        },
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Main widescreen partner video bar
            Container(
              width: barWidth,
              height: barHeight,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.terra.withOpacity(0.8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: ValueListenableBuilder<bool>(
                valueListenable: _callService.isPartnerCameraOff,
                builder: (context, isCameraOff, _) {
                  if (isCameraOff || _callService.remoteRenderer.srcObject == null) {
                    return _buildPartnerAvatarPlaceholder();
                  }
                  return RTCVideoView(
                    _callService.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  );
                },
              ),
            ),

            // Partner name label — bottom left
            Positioned(
              bottom: 6,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.partnerName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // My local camera — bottom-right inset (small 16:9 mini thumbnail)
            Positioned(
              bottom: 6,
              right: 8,
              child: Container(
                width: 72,
                height: 41, // 72 * 9/16
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white70, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _callService.isCameraOff,
                  builder: (context, isCameraOff, _) {
                    if (isCameraOff || _callService.localRenderer.srcObject == null) {
                      return const Icon(Icons.videocam_off_rounded, size: 16, color: Colors.white54);
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

            // Partner mic muted badge — top left
            Positioned(
              top: 6,
              left: 6,
              child: ValueListenableBuilder<bool>(
                valueListenable: _callService.isPartnerMicMuted,
                builder: (context, isMuted, _) {
                  if (!isMuted) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_off_rounded, color: Colors.redAccent, size: 12),
                  );
                },
              ),
            ),

            // Toggled Controls Overlay (tap to show — Mute, Camera, Flip, Hangup)
            if (_showControls)
              Container(
                width: barWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(12),
                ),
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
                            size: 22,
                          ),
                        );
                      },
                    ),
                    // Camera Toggle
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
                            size: 22,
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
                      child: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 22),
                    ),
                    // End Call
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _callService.endCall();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 18),
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

  Widget _buildPartnerAvatarPlaceholder() {
    return Container(
      color: const Color(0xFF1F1F1F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.terra.withOpacity(0.3),
              backgroundImage: widget.partnerAvatarUrl != null && widget.partnerAvatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(widget.partnerAvatarUrl!)
                  : null,
              child: widget.partnerAvatarUrl == null || widget.partnerAvatarUrl!.isEmpty
                  ? Text(
                      widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : 'P',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.terra),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              widget.partnerName,
              style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
