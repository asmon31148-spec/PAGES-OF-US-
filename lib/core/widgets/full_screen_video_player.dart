import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_colors.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String? subtitle;

  const FullScreenVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.title,
    this.subtitle,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';

  bool _showControls = true;
  bool _isLandscape = false;
  Timer? _controlsTimer;
  Timer? _positionTicker;

  // True Scrubber state
  bool _isDragging = false;
  double _dragPositionMs = 0.0;

  // Double tap feedback
  bool _showDoubleTapLeft = false;
  bool _showDoubleTapRight = false;
  Timer? _doubleTapFeedbackTimer;

  @override
  void initState() {
    super.initState();
    _initVideoController();
  }

  Future<void> _initVideoController() async {
    try {
      final url = widget.videoUrl.trim();
      if (url.startsWith('http://') || url.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else if (url.startsWith('assets/')) {
        _controller = VideoPlayerController.asset(url);
      } else {
        final filePath = url.replaceFirst('file://', '');
        _controller = VideoPlayerController.file(File(filePath));
      }

      await _controller.initialize();
      if (!mounted) return;

      setState(() {
        _isInitialized = true;
        _hasError = false;
      });

      await _controller.play();
      _startControlsTimer();
      _startPositionTicker();
      _controller.addListener(_videoListener);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Unable to play video: $e';
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted || _isDragging) return;
    setState(() {});
  }

  void _startPositionTicker() {
    _positionTicker?.cancel();
    _positionTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted && _isInitialized && _controller.value.isPlaying && !_isDragging) {
        setState(() {});
      }
    });
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (_controller.value.isPlaying && !_isDragging) {
      _controlsTimer = Timer(const Duration(milliseconds: 3500), () {
        if (mounted && _controller.value.isPlaying && !_isDragging) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startControlsTimer();
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
        _controlsTimer?.cancel();
      } else {
        _controller.play();
        _startControlsTimer();
      }
    });
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);

    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _seekRelative(int seconds) {
    if (!_isInitialized) return;

    final current = _controller.value.position;
    final total = _controller.value.duration;
    final target = current + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > total ? total : target);

    _controller.seekTo(clamped);
    _startControlsTimer();

    // Trigger visual feedback animation
    setState(() {
      if (seconds < 0) {
        _showDoubleTapLeft = true;
        _showDoubleTapRight = false;
      } else {
        _showDoubleTapRight = true;
        _showDoubleTapLeft = false;
      }
    });

    _doubleTapFeedbackTimer?.cancel();
    _doubleTapFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _showDoubleTapLeft = false;
          _showDoubleTapRight = false;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    if (duration < Duration.zero) duration = Duration.zero;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _positionTicker?.cancel();
    _doubleTapFeedbackTimer?.cancel();
    if (_isInitialized) {
      _controller.removeListener(_videoListener);
      _controller.dispose();
    }
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Duration duration = Duration.zero;
    Duration position = Duration.zero;

    if (_isInitialized) {
      duration = _controller.value.duration;
      position = _isDragging
          ? Duration(milliseconds: _dragPositionMs.toInt())
          : _controller.value.position;
    }

    final durationMs = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 0.0;
    final positionMs = position.inMilliseconds.toDouble().clamp(0.0, durationMs > 0 ? durationMs : 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Ambient Background Glow
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    Color(0xFF231628),
                    Colors.black,
                  ],
                ),
              ),
            ),

            // 2. Video Player Surface
            Center(
              child: _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio > 0
                          ? _controller.value.aspectRatio
                          : 16 / 9,
                      child: VideoPlayer(_controller),
                    )
                  : _hasError
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFE57373), size: 48),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFD4AF37), strokeWidth: 2.5),
                            SizedBox(height: 16),
                            Text(
                              'Loading cinema...',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
            ),

            // 3. Double-tap gesture areas (left rewind 10s, right fast-forward 10s)
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () => _seekRelative(-10),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () => _seekRelative(10),
                    ),
                  ),
                ],
              ),
            ),

            // Double tap feedback overlays
            if (_showDoubleTapLeft)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(left: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fast_rewind_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 6),
                      Text('-10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              ),

            if (_showDoubleTapRight)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(right: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('+10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(width: 6),
                      Icon(Icons.fast_forward_rounded, color: Colors.white, size: 28),
                    ],
                  ),
                ),
              ),

            // 4. Controls Overlay
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  color: Colors.black.withOpacity(0.48),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Bar: Back button, Title & Subtitle, Fullscreen toggle
                        _buildTopBar(),

                        // Center: 3-Button Cinema Controls (-10s, Play/Pause, +10s)
                        if (_isInitialized) _buildCenterControls(),

                        // Bottom: True Interactive Scrubber & Timestamps
                        if (_isInitialized) _buildTruePlayBar(position, duration, positionMs, durationMs),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isLandscape ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
              color: Colors.white,
              size: 26,
            ),
            onPressed: _toggleOrientation,
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Rewind 10s button
        IconButton(
          iconSize: 34,
          icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
          onPressed: () => _seekRelative(-10),
        ),
        const SizedBox(width: 28),

        // Play / Pause glowing circle
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD4AF37),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withOpacity(0.55),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 38,
            ),
          ),
        ),
        const SizedBox(width: 28),

        // Forward 10s button
        IconButton(
          iconSize: 34,
          icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
          onPressed: () => _seekRelative(10),
        ),
      ],
    );
  }

  Widget _buildTruePlayBar(Duration position, Duration duration, double positionMs, double durationMs) {
    // Calculate buffered range
    double bufferedFraction = 0.0;
    if (durationMs > 0 && _controller.value.buffered.isNotEmpty) {
      final lastBuffered = _controller.value.buffered.last.end;
      bufferedFraction = (lastBuffered.inMilliseconds / durationMs).clamp(0.0, 1.0);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Interactive Custom Slider Track
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: const Color(0xFFD4AF37),
              inactiveTrackColor: Colors.white24,
              secondaryActiveTrackColor: Colors.white54,
              thumbColor: const Color(0xFFD4AF37),
              overlayColor: const Color(0xFFD4AF37).withOpacity(0.2),
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: _isDragging ? 8 : 6,
                elevation: 4,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: durationMs > 0 ? positionMs : 0.0,
              min: 0.0,
              max: durationMs > 0 ? durationMs : 1.0,
              secondaryTrackValue: durationMs > 0 ? bufferedFraction * durationMs : null,
              onChangeStart: (val) {
                _controlsTimer?.cancel();
                setState(() {
                  _isDragging = true;
                  _dragPositionMs = val;
                });
              },
              onChanged: (val) {
                setState(() {
                  _dragPositionMs = val;
                });
              },
              onChangeEnd: (val) async {
                final target = Duration(milliseconds: val.toInt());
                await _controller.seekTo(target);
                setState(() {
                  _isDragging = false;
                });
                _startControlsTimer();
              },
            ),
          ),

          // Timestamps row (Real current position and real duration)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  durationMs > 0 ? _formatDuration(duration) : '--:--',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
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
