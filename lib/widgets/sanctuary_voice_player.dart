import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/services/voice_playback_service.dart';
import '../core/theme/app_colors.dart';
import '../providers/audio_provider.dart';

/// WhatsApp / Telegram style interactive Voice Note Player
/// Renders a circular Coral/Terra play/pause button, an interactive vertical-bar
/// speech waveform with active/inactive progress fill, and smooth running / total timers.
class SanctuaryVoicePlayer extends StatefulWidget {
  final String id;
  final String audioUrl;
  final int? durationSeconds;
  final bool isDark;
  final AudioProvider? ambientAudio;
  final VoidCallback? onPlayStarted;
  final VoidCallback? onPlaybackCompleted;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const SanctuaryVoicePlayer({
    super.key,
    required this.id,
    required this.audioUrl,
    this.durationSeconds,
    this.isDark = true,
    this.ambientAudio,
    this.onPlayStarted,
    this.onPlaybackCompleted,
    this.margin,
    this.padding,
  });

  @override
  State<SanctuaryVoicePlayer> createState() => _SanctuaryVoicePlayerState();
}

class _SanctuaryVoicePlayerState extends State<SanctuaryVoicePlayer> {
  // Realistic natural speech pitch waveform amplitudes (32 bars)
  static const List<double> _waveformAmplitudes = [
    0.28, 0.45, 0.75, 0.55, 0.35, 0.65, 0.90, 1.00,
    0.78, 0.48, 0.68, 0.95, 0.82, 0.58, 0.38, 0.28,
    0.48, 0.72, 0.88, 0.62, 0.38, 0.52, 0.78, 0.68,
    0.44, 0.28, 0.52, 0.78, 0.58, 0.38, 0.62, 0.32,
  ];

  bool _isDragging = false;
  double _dragFraction = 0.0;
  final GlobalKey _waveformKey = GlobalKey();

  void _handleToggle(VoicePlaybackService service) {
    if (widget.audioUrl.trim().isEmpty) return;
    HapticFeedback.lightImpact();

    final wasPlaying = service.isPlaying && service.activeId == widget.id;
    if (!wasPlaying && widget.onPlayStarted != null) {
      widget.onPlayStarted!();
    }

    service.togglePlay(
      id: widget.id,
      url: widget.audioUrl,
      durationSeconds: widget.durationSeconds,
      ambientAudio: widget.ambientAudio,
    );
  }

  void _seekToFraction(VoicePlaybackService service, double fraction) {
    if (service.activeId != widget.id) {
      _handleToggle(service);
      return;
    }

    Duration dur = service.duration;
    if (dur.inMilliseconds == 0 && widget.durationSeconds != null && widget.durationSeconds! > 0) {
      dur = Duration(seconds: widget.durationSeconds!);
    }
    if (dur.inMilliseconds == 0) {
      dur = const Duration(seconds: 30);
    }

    final targetMs = (fraction * dur.inMilliseconds).toInt();
    service.seek(Duration(milliseconds: targetMs));
  }

  void _updateDragPosition(Offset localPosition) {
    final RenderBox? renderBox = _waveformKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.size.width > 0) {
      final fraction = (localPosition.dx / renderBox.size.width).clamp(0.0, 1.0);
      setState(() {
        _dragFraction = fraction;
      });
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final service = VoicePlaybackService.instance;

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final isActive = service.activeId == widget.id;
        final isPlaying = isActive && service.isPlaying;
        final isPaused = isActive && service.isPaused;
        final isBuffering = isActive && service.isBuffering;

        Duration totalDuration = Duration.zero;
        if (isActive && service.duration.inMilliseconds > 0) {
          totalDuration = service.duration;
        } else if (widget.durationSeconds != null && widget.durationSeconds! > 0) {
          totalDuration = Duration(seconds: widget.durationSeconds!);
        } else {
          totalDuration = const Duration(seconds: 30);
        }

        final cardBg = widget.isDark
            ? const Color(0xFF1E2222)
            : const Color(0xFFF1F3F1);
        final borderColor = widget.isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.06);

        const terraColor = AppColors.terra; // #E07A5F
        final inactiveBarColor = widget.isDark
            ? const Color(0xFF3E3636)
            : const Color(0xFFD6CBC8);

        return Container(
          margin: widget.margin,
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(widget.isDark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Circular Terra Play/Pause Button
              GestureDetector(
                onTap: () => _handleToggle(service),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: terraColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: terraColor.withOpacity(isPlaying ? 0.45 : 0.25),
                        blurRadius: isPlaying ? 10 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isBuffering
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Color(0xFF2B1410),
                            ),
                          )
                        : Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: isPlaying ? 24 : 28,
                            color: const Color(0xFF2B1410), // Matching dark contrast from screenshot
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // 2. Waveform & Dynamic Timestamps
              Expanded(
                child: ValueListenableBuilder<Duration>(
                  valueListenable: service.positionNotifier,
                  builder: (context, livePosition, _) {
                    final currentPos = isActive
                        ? (_isDragging
                            ? Duration(milliseconds: (_dragFraction * totalDuration.inMilliseconds).toInt())
                            : livePosition)
                        : Duration.zero;

                    final double progress = _isDragging
                        ? _dragFraction
                        : (totalDuration.inMilliseconds > 0 && isActive
                            ? (currentPos.inMilliseconds / totalDuration.inMilliseconds).clamp(0.0, 1.0)
                            : 0.0);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Interactive Waveform Area
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: (details) {
                            setState(() => _isDragging = true);
                            _updateDragPosition(details.localPosition);
                          },
                          onHorizontalDragUpdate: (details) {
                            _updateDragPosition(details.localPosition);
                          },
                          onHorizontalDragEnd: (details) {
                            setState(() => _isDragging = false);
                            _seekToFraction(service, _dragFraction);
                            HapticFeedback.selectionClick();
                          },
                          onTapDown: (details) {
                            final RenderBox? renderBox =
                                _waveformKey.currentContext?.findRenderObject() as RenderBox?;
                            if (renderBox != null && renderBox.size.width > 0) {
                              final fraction =
                                  (details.localPosition.dx / renderBox.size.width).clamp(0.0, 1.0);
                              _seekToFraction(service, fraction);
                              HapticFeedback.selectionClick();
                            }
                          },
                          child: Container(
                            key: _waveformKey,
                            height: 32,
                            alignment: Alignment.center,
                            child: CustomPaint(
                              size: const Size(double.infinity, 32),
                              painter: _SpeechWaveformPainter(
                                amplitudes: _waveformAmplitudes,
                                progressFraction: progress,
                                activeColor: terraColor,
                                inactiveColor: inactiveBarColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Timestamp Row: Elapsed (Left) / Total (Right)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(currentPos),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isPlaying
                                    ? terraColor
                                    : (widget.isDark ? Colors.white70 : Colors.black87),
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              _formatDuration(totalDuration),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: widget.isDark ? Colors.white38 : Colors.black45,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom GPU-accelerated painter for drawing vertical rounded audio bars
class _SpeechWaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final double progressFraction;
  final Color activeColor;
  final Color inactiveColor;

  _SpeechWaveformPainter({
    required this.amplitudes,
    required this.progressFraction,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final barCount = amplitudes.length;
    const barWidth = 3.0;
    const minHeight = 6.0;
    final maxHeight = size.height - 4.0;

    final availableWidth = size.width;
    final totalBarWidth = barCount * barWidth;
    final spacing = (availableWidth - totalBarWidth) / (barCount - 1);

    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final x = (i * (barWidth + spacing)) + (barWidth / 2);
      final height = minHeight + (amplitudes[i] * (maxHeight - minHeight));
      final halfH = height / 2;

      final barProgress = i / (barCount - 1);
      final paint = (barProgress <= progressFraction) ? activePaint : inactivePaint;

      canvas.drawLine(
        Offset(x, centerY - halfH),
        Offset(x, centerY + halfH),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeechWaveformPainter oldDelegate) {
    return oldDelegate.progressFraction != progressFraction ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
