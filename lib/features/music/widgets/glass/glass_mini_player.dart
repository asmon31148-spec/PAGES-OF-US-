import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../providers/audio_provider.dart';
import '../../theme/glass_tokens.dart';
import '../../screens/now_playing_screen.dart';

/// Floating Apple iOS 26 Liquid Glass Mini Player
class GlassMiniPlayer extends StatelessWidget {
  const GlassMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    if (audio.songs.isEmpty) return const SizedBox.shrink();
    final song = audio.currentSong;
    if (song.id == 'empty') return const SizedBox.shrink();

    final dur = audio.songDuration;
    final pos = audio.songPosition;
    final progress = (dur.inMilliseconds > 0)
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const NowPlayingScreen(),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GlassTokens.radiusCard),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GlassTokens.radiusCard),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: GlassTokens.blurNormal, sigmaY: GlassTokens.blurNormal),
              child: Container(
                decoration: BoxDecoration(
                  gradient: GlassTokens.glassGradient,
                  borderRadius: BorderRadius.circular(GlassTokens.radiusCard),
                  border: Border.all(color: GlassTokens.glassBorder, width: 1.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Content Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          // Album Art
                          Hero(
                            tag: 'album_art_${song.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: song.thumbnailUrl != null && song.thumbnailUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: song.thumbnailUrl!,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        width: 44,
                                        height: 44,
                                        color: song.coverColor,
                                        child: const Icon(Icons.music_note, color: Colors.white70, size: 22),
                                      ),
                                    )
                                  : Container(
                                      width: 44,
                                      height: 44,
                                      color: song.coverColor,
                                      child: const Icon(Icons.music_note, color: Colors.white70, size: 22),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Title and Artist
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Play / Pause Button
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              audio.togglePlay();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                audio.isSongPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Next Song Button
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              audio.nextSong();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.skip_next_rounded,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tiny Progress Bar at bottom of mini player
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(GlassTokens.radiusCard)),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(GlassTokens.accentTerra),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
