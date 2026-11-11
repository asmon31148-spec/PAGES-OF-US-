import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/watch_call_service.dart';

enum SyncStatus {
  inSync,
  syncing,
  partnerOffline,
}

class WatchControlsOverlay extends StatefulWidget {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final SyncStatus syncStatus;
  final String movieTitle;
  final bool isFullscreen;
  final bool isChatVisible;
  final VoidCallback onTogglePlay;
  final Function(Duration newPosition) onSeek;
  final VoidCallback onSkipBack10;
  final VoidCallback onSkipForward10;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onToggleChat;
  final VoidCallback onLeave;
  final VoidCallback? onToggleAspectRatio;
  final String aspectRatioLabel;
  final VoidCallback? onSpeedUpStart;
  final VoidCallback? onSpeedUpEnd;
  final bool hasUnreadMessages;
  final VoidCallback? onStartCall;
  final bool isCallActive;
  final bool isWebViewMode;
  final bool isWebTouchThrough;
  final VoidCallback? onToggleWebTouchThrough;
  final String? qualityLabel;
  final VoidCallback? onSelectQuality;

  const WatchControlsOverlay({
    super.key,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.syncStatus,
    required this.movieTitle,
    required this.isFullscreen,
    required this.isChatVisible,
    required this.onTogglePlay,
    required this.onSeek,
    required this.onSkipBack10,
    required this.onSkipForward10,
    required this.onToggleFullscreen,
    required this.onToggleChat,
    required this.onLeave,
    this.onToggleAspectRatio,
    this.aspectRatioLabel = 'Fit',
    this.onSpeedUpStart,
    this.onSpeedUpEnd,
    this.hasUnreadMessages = false,
    this.onStartCall,
    this.isCallActive = false,
    this.isWebViewMode = false,
    this.isWebTouchThrough = false,
    this.onToggleWebTouchThrough,
    this.qualityLabel,
    this.onSelectQuality,
  });

  @override
  State<WatchControlsOverlay> createState() => WatchControlsOverlayState();
}

class WatchControlsOverlayState extends State<WatchControlsOverlay> {
  bool _isVisible = true;
  Timer? _hideTimer;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void didUpdateWidget(covariant WatchControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying && _isVisible) {
      _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted && widget.isPlaying && _dragValue == null) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  void toggleVisibility() {
    setState(() {
      _isVisible = !_isVisible;
    });
    if (_isVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void showControls() {
    setState(() {
      _isVisible = true;
    });
    _startHideTimer();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggleVisibility,
        onLongPressStart: (_) => widget.onSpeedUpStart?.call(),
        onLongPressEnd: (_) => widget.onSpeedUpEnd?.call(),
        onLongPressCancel: () => widget.onSpeedUpEnd?.call(),
        child: const SizedBox.expand(),
      );
    }

    final totalMs = widget.duration.inMilliseconds.toDouble();
    final currentMs = _dragValue ?? widget.position.inMilliseconds.toDouble();
    final clampedMs = totalMs > 0 ? currentMs.clamp(0.0, totalMs) : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: toggleVisibility,
      onLongPressStart: (_) {
        setState(() {
          _isVisible = false;
        });
        _hideTimer?.cancel();
        widget.onSpeedUpStart?.call();
      },
      onLongPressEnd: (_) => widget.onSpeedUpEnd?.call(),
      onLongPressCancel: () => widget.onSpeedUpEnd?.call(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.32),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                child: Row(
                  children: [
                    // Leave Button
                    GestureDetector(
                      onTap: () {
                        _hideTimer?.cancel();
                        widget.onLeave();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.18)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Leave',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Title
                    Expanded(
                      child: Text(
                        widget.movieTitle.isNotEmpty ? widget.movieTitle : 'Movie Sanctuary',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Sync Status Chip
                    _buildSyncStatusChip(),

                    if (widget.isWebViewMode && widget.onToggleWebTouchThrough != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          _startHideTimer();
                          widget.onToggleWebTouchThrough!();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: const Icon(
                            Icons.touch_app_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(width: 6),

                    // Video Call / In-Call Indicator
                    if (widget.isCallActive) ...[
                      // In-call chip: 🟢 In call 00:12 (SS 3 Match)
                      ValueListenableBuilder<int>(
                        valueListenable: WatchCallService.instance.callDurationSeconds,
                        builder: (context, _, __) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'In call ${WatchCallService.instance.formattedCallDuration}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      // Red End Call Button (SS 3 Match)
                      GestureDetector(
                        onTap: () {
                          _startHideTimer();
                          WatchCallService.instance.endCall();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.call_end_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else if (widget.onStartCall != null) ...[
                      GestureDetector(
                        onTap: () {
                          _startHideTimer();
                          widget.onStartCall!();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.videocam_outlined,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Chat Toggle Icon
                    GestureDetector(
                      onTap: () {
                        _startHideTimer();
                        widget.onToggleChat();
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: widget.isChatVisible
                                  ? AppColors.terra.withOpacity(0.8)
                                  : Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Icon(
                              widget.isChatVisible
                                  ? Icons.chat_bubble_rounded
                                  : Icons.chat_bubble_outline_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                          if (!widget.isChatVisible && widget.hasUnreadMessages)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black, width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Center Action Buttons (Back 10s, Play/Pause, Forward 10s) + Live Chat pill
              Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // -10s
                      GestureDetector(
                        onTap: () {
                          _startHideTimer();
                          widget.onSkipBack10();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.48),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.18)),
                          ),
                          child: const Icon(
                            Icons.replay_10_rounded,
                            size: 26,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(width: 24),

                      // Play / Pause
                      GestureDetector(
                        onTap: () {
                          _startHideTimer();
                          widget.onTogglePlay();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.62),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.terra.withOpacity(0.9),
                              width: 1.8,
                            ),
                          ),
                          child: Icon(
                            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 34,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(width: 24),

                      // +10s
                      GestureDetector(
                        onTap: () {
                          _startHideTimer();
                          widget.onSkipForward10();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.48),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.18)),
                          ),
                          child: const Icon(
                            Icons.forward_10_rounded,
                            size: 26,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Floating Live Chat Pill on Right Edge (SS 3 Match)
                  if (!widget.isChatVisible && widget.isFullscreen)
                    Positioned(
                      right: 16,
                      child: GestureDetector(
                        onTap: () {
                          _startHideTimer();
                          widget.onToggleChat();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Live Chat',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Bottom Bar (Position, Slider, Duration, Fullscreen)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatDuration(Duration(milliseconds: clampedMs.toInt())),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppColors.terra,
                              inactiveTrackColor: Colors.white.withOpacity(0.25),
                              thumbColor: AppColors.terra,
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            ),
                            child: Slider(
                              value: clampedMs,
                              min: 0.0,
                              max: totalMs > 0 ? totalMs : 1.0,
                              onChangeStart: (_) {
                                _hideTimer?.cancel();
                              },
                              onChanged: (val) {
                                setState(() {
                                  _dragValue = val;
                                });
                              },
                              onChangeEnd: (val) {
                                setState(() {
                                  _dragValue = null;
                                });
                                widget.onSeek(Duration(milliseconds: val.toInt()));
                                _startHideTimer();
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(widget.duration),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        if (widget.onSelectQuality != null && widget.qualityLabel != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              _startHideTimer();
                              widget.onSelectQuality!();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white.withOpacity(0.24)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.high_quality_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text(
                                    widget.qualityLabel!,
                                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (widget.onToggleAspectRatio != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              _startHideTimer();
                              widget.onToggleAspectRatio!();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white.withOpacity(0.24)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.aspect_ratio_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text(
                                    widget.aspectRatioLabel,
                                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            _startHideTimer();
                            widget.onToggleFullscreen();
                          },
                          child: Icon(
                            widget.isFullscreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncStatusChip() {
    Color dotColor;
    String label;

    switch (widget.syncStatus) {
      case SyncStatus.inSync:
        dotColor = const Color(0xFF10B981); // Emerald green
        label = 'Synced';
        break;
      case SyncStatus.syncing:
        dotColor = const Color(0xFFF59E0B); // Amber orange
        label = 'Syncing';
        break;
      case SyncStatus.partnerOffline:
        dotColor = const Color(0xFFEF4444); // Red
        label = 'Offline';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }
}
