import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
  // 36-bar realistic human speech pitch waveform curve (Instagram / WhatsApp style)
  static const List<double> _waveformHeights = [
    8, 12, 22, 16, 10, 18, 28, 36, 26, 16, 22, 34, 40, 28, 18, 12,
    16, 26, 32, 22, 14, 20, 30, 24, 16, 10, 18, 28, 20, 14, 22, 16,
    12, 20, 14, 8,
  ];

  bool _isDragging = false;
  double _dragFraction = 0.0;
  final GlobalKey _waveformKey = GlobalKey();

  String _resolveAudioUrl() {
    if (widget.memory.voiceUrl != null && widget.memory.voiceUrl!.isNotEmpty) {
      return widget.memory.voiceUrl!;
    }
    return widget.memory.mediaUrl;
  }

  void _handlePlayToggle(MemoriesProvider provider) {
    final url = _resolveAudioUrl();
    if (url.isEmpty) return;

    HapticFeedback.lightImpact();
    provider.playVoiceWhisper(
      widget.memory.id,
      url,
      ambientAudio: widget.audioProvider,
    );
  }

  void _seekToFraction(MemoriesProvider provider, double fraction) {
    Duration dur = provider.voiceDuration;
    if (dur.inMilliseconds == 0) {
      dur = const Duration(seconds: 15);
    }
    final targetMs = (fraction * dur.inMilliseconds).toInt();
    provider.seekVoiceWhisper(Duration(milliseconds: targetMs));
  }

  void _updateDragPosition(Offset localPosition, MemoriesProvider provider) {
    final RenderBox? renderBox = _waveformKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final width = renderBox.size.width;
      if (width > 0) {
        final fraction = (localPosition.dx / width).clamp(0.0, 1.0);
        setState(() {
          _dragFraction = fraction;
        });
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final memoriesProvider = context.watch<MemoriesProvider>();
    final isPlaying = memoriesProvider.playingVoiceId == widget.memory.id &&
        memoriesProvider.isVoicePlaying;

    Duration duration = Duration.zero;
    if (memoriesProvider.playingVoiceId == widget.memory.id &&
        memoriesProvider.voiceDuration.inMilliseconds > 0) {
      duration = memoriesProvider.voiceDuration;
    } else {
      duration = const Duration(seconds: 15); // Default visual estimation
    }

    final cardBg = widget.isDark ? const Color(0xFF141C18) : const Color(0xFFF3F5F3);
    final activeColor = AppColors.terra;
    final inactiveColor = widget.isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.black.withOpacity(0.16);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
          // Header Badge Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: activeColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlaying ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                      size: 13,
                      color: activeColor,
                    ),
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
              if (isPlaying)
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Playing whisper...',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: activeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Main WhatsApp / Instagram style player row
          Row(
            children: [
              // Speed Toggle Pill (WhatsApp style: 1x, 1.5x, 2x)
              GestureDetector(
                onTap: () => memoriesProvider.togglePlaybackSpeed(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.isDark ? Colors.white12 : Colors.black12,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    memoriesProvider.playbackSpeed == 1.0
                        ? '1x'
                        : (memoriesProvider.playbackSpeed == 1.5 ? '1.5x' : '2x'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPlaying ? activeColor : (widget.isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Play/Pause button
              GestureDetector(
                onTap: () => _handlePlayToggle(memoriesProvider),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeColor,
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(isPlaying ? 0.45 : 0.25),
                        blurRadius: isPlaying ? 12 : 6,
                        spreadRadius: isPlaying ? 1.5 : 0,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Interactive Waveform & Smooth Timestamps (60 FPS Isolated ValueListenable)
              Expanded(
                child: ValueListenableBuilder<Duration>(
                  valueListenable: widget.memoriesProvider.voicePositionNotifier,
                  builder: (context, livePos, _) {
                    final position = isPlaying ? livePos : Duration.zero;
                    final double progressFraction = _isDragging
                        ? _dragFraction
                        : (duration.inMilliseconds > 0
                            ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                            : 0.0);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Waveform scrubber container
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: (details) {
                            setState(() => _isDragging = true);
                            _updateDragPosition(details.localPosition, memoriesProvider);
                          },
                          onHorizontalDragUpdate: (details) {
                            _updateDragPosition(details.localPosition, memoriesProvider);
                          },
                          onHorizontalDragEnd: (details) {
                            setState(() => _isDragging = false);
                            _seekToFraction(memoriesProvider, _dragFraction);
                            HapticFeedback.selectionClick();
                          },
                          onTapDown: (details) {
                            final RenderBox? renderBox = _waveformKey.currentContext?.findRenderObject() as RenderBox?;
                            if (renderBox != null) {
                              final fraction = (details.localPosition.dx / renderBox.size.width).clamp(0.0, 1.0);
                              _seekToFraction(memoriesProvider, fraction);
                              HapticFeedback.selectionClick();
                            }
                          },
                          child: Container(
                            key: _waveformKey,
                            height: 46,
                            alignment: Alignment.center,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final totalWidth = constraints.maxWidth;
                                final thumbX = (progressFraction * totalWidth).clamp(0.0, totalWidth);

                                return Stack(
                                  alignment: Alignment.centerLeft,
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Pitch Waveform Bars
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: List.generate(_waveformHeights.length, (idx) {
                                        final barFraction = (idx + 0.5) / _waveformHeights.length;
                                        final isPlayed = barFraction <= progressFraction;

                                        return AnimatedContainer(
                                          duration: const Duration(milliseconds: 60),
                                          width: 3.2,
                                          height: _waveformHeights[idx],
                                          decoration: BoxDecoration(
                                            color: isPlayed ? activeColor : inactiveColor,
                                            borderRadius: BorderRadius.circular(3),
                                            boxShadow: isPlayed && isPlaying
                                                ? [
                                                    BoxShadow(
                                                      color: activeColor.withOpacity(0.35),
                                                      blurRadius: 3,
                                                      spreadRadius: 0.5,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        );
                                      }),
                                    ),

                                    // Active WhatsApp-style Scrubber Thumb Dot
                                    Positioned(
                                      left: (thumbX - 5).clamp(0.0, totalWidth - 10),
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: activeColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: activeColor.withOpacity(0.6),
                                              blurRadius: 5,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),

                        // WhatsApp Timestamps row: Running Time (left) / Total Duration (right)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPlaying
                                    ? activeColor
                                    : (widget.isDark ? Colors.white70 : Colors.black87),
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
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
