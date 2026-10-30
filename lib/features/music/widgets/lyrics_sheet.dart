import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/audio_provider.dart';
import '../../../core/services/lrc_lyrics_service.dart';

/// Real-Time Synchronized Lyrics Sheet (Echo Music / Apple Music style)
class LyricsSheet extends StatefulWidget {
  final String title;
  final String artist;
  final int durationSeconds;

  const LyricsSheet({
    super.key,
    required this.title,
    required this.artist,
    required this.durationSeconds,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String artist,
    required int durationSeconds,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LyricsSheet(
        title: title,
        artist: artist,
        durationSeconds: durationSeconds,
      ),
    );
  }

  @override
  State<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> {
  final ScrollController _scrollController = ScrollController();
  List<LyricLine> _lyrics = [];
  bool _isLoading = true;
  int _activeLineIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    final lines = await LrcLyricsService.instance.fetchLyrics(
      title: widget.title,
      artist: widget.artist,
      durationSeconds: widget.durationSeconds,
    );
    if (mounted) {
      setState(() {
        _lyrics = lines;
        _isLoading = false;
      });
    }
  }

  void _syncActiveLine(Duration currentPos) {
    if (_lyrics.isEmpty) return;

    int activeIdx = -1;
    for (int i = 0; i < _lyrics.length; i++) {
      if (currentPos >= _lyrics[i].timestamp) {
        activeIdx = i;
      } else {
        break;
      }
    }

    if (activeIdx != _activeLineIndex) {
      _activeLineIndex = activeIdx;
      if (activeIdx >= 0 && _scrollController.hasClients) {
        // Auto-scroll to center active line
        const itemHeight = 44.0;
        final targetOffset = (activeIdx * itemHeight) - 160.0;
        _scrollController.animateTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    _syncActiveLine(audio.songPosition);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF07100B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header: Title + Artist + Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.artist} • Synced Lyrics ✦',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Lyrics Body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                        SizedBox(height: 12),
                        Text(
                          'Fetching synchronized lyrics...',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : _lyrics.isEmpty
                    ? const Center(
                        child: Text(
                          'No lyrics found for this song 🍃\nEnjoy the melody.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _lyrics.length,
                        itemBuilder: (context, idx) {
                          final line = _lyrics[idx];
                          final isActive = idx == _activeLineIndex;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              audio.seekSong(line.timestamp);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                line.text,
                                style: TextStyle(
                                  fontSize: isActive ? 22 : 16,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                  color: isActive
                                      ? const Color(0xFFFDE047) // Glowing warm yellow/gold
                                      : (idx < _activeLineIndex ? Colors.white38 : Colors.white60),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
