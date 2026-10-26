import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/memory_item.dart';
import '../../../providers/memories_provider.dart';
import '../../../providers/audio_provider.dart';

class VoiceWhisperPlayerCard extends StatefulWidget {
  final MemoryItem memory;
  final bool isDark;
  final MemoriesProvider memoriesProvider;
  final AudioProvider? audioProvider;

  const VoiceWhisperPlayerCard({
    super.key,
    required this.memory,
    required this.isDark,
    required this.memoriesProvider,
    this.audioProvider,
  });

  @override
  State<VoiceWhisperPlayerCard> createState() => _VoiceWhisperPlayerCardState();
}

class _VoiceWhisperPlayerCardState extends State<VoiceWhisperPlayerCard> {
  // 32-bar natural speech waveform heights
  static const List<double> _waveformHeights = [
    8, 14, 24, 16, 10, 20, 32, 38, 28, 18, 26, 36, 42, 30, 20, 12,
    18, 28, 34, 24, 16, 22, 32, 26, 18, 12, 20, 30, 22, 16, 10, 6,
  ];

  bool _isDragging = false;
  double _dragFraction = 0.0;

  String _resolveAudioUrl() {
    if (widget.memory.voiceUrl != null && widget.memory.voiceUrl!.isNotEmpty) {
      return widget.memory.voiceUrl!;
    }
    return widget.memory.mediaUrl;
  }

  void _handlePlayToggle() {
    final url = _resolveAudioUrl();
    if (url.isEmpty) return;

    widget.memoriesProvider.playVoiceWhisper(
      widget.memory.id,
      url,
      ambientAudio: widget.audioProvider,
    );
  }

  void _seekToFraction(double fraction) {
    final dur = widget.memoriesProvider.voiceDuration;
    if (dur.inMilliseconds > 0) {
      final targetMs = (fraction * dur.inMilliseconds).toInt();
      widget.memoriesProvider.seekVoiceWhisper(Duration(milliseconds: targetMs));
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = widget.memoriesProvider.playingVoiceId == widget.memory.id &&
        widget.memoriesProvider.isVoicePlaying;

    final position = widget.memoriesProvider.playingVoiceId == widget.memory.id
        ? widget.memoriesProvider.voicePosition
        : Duration.zero;

    final duration = widget.memoriesProvider.playingVoiceId == widget.memory.id &&
            widget.memoriesProvider.voiceDuration.inMilliseconds > 0
        ? widget.memoriesProvider.voiceDuration
        : const Duration(seconds: 30); // Default estimate if not played yet

    final double progressFraction = _isDragging
        ? _dragFraction
        : (duration.inMilliseconds > 0
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0);

    final cardBg = widget.isDark ? const Color(0xFF161C19) : const Color(0xFFF2F4F2);
    final activeColor = AppColors.terra;
    final inactiveColor = widget.isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.15);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          bottom: BorderSide(
            color: widget.isDark ? Colors.white10 : Colors.black12,
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: activeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.graphic_eq_rounded, size: 12, color: activeColor),
                    const SizedBox(width: 4),
                    Text(
                      'VOICE NOTE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: activeColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isPlaying)
                Text(
                  'Playing...',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: activeColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Main WhatsApp/Instagram-style player row
          Row(
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: _handlePlayToggle,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeColor,
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Interactive Waveform & Timestamps
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Waveform scrubber
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (details) {
                        setState(() {
                          _isDragging = true;
                        });
                      },
                      onHorizontalDragUpdate: (details) {
                        final box = context.findRenderObject() as RenderBox?;
                        if (box != null) {
                          // calculate fraction based on waveform width
                          final localX = details.localPosition.dx;
                          final fraction = (localX / 200).clamp(0.0, 1.0);
                          setState(() {
                            _dragFraction = fraction;
                          });
                        }
                      },
                      onHorizontalDragEnd: (details) {
                        setState(() {
                          _isDragging = false;
                        });
                        _seekToFraction(_dragFraction);
                      },
                      onTapDown: (details) {
                        final box = context.findRenderObject() as RenderBox?;
                        if (box != null) {
                          final localX = details.localPosition.dx;
                          final fraction = (localX / 200).clamp(0.0, 1.0);
                          _seekToFraction(fraction);
                        }
                      },
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(_waveformHeights.length, (idx) {
                            final barFraction = (idx + 1) / _waveformHeights.length;
                            final isPlayed = barFraction <= progressFraction;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: 3.2,
                              height: _waveformHeights[idx],
                              decoration: BoxDecoration(
                                color: isPlayed ? activeColor : inactiveColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Timestamp row (current / total or remaining)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark ? Colors.white70 : Colors.black87,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: widget.isDark ? Colors.white38 : Colors.black45,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
