import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/audio_provider.dart';
import '../../../core/services/music_download_service.dart';
import '../../../core/services/youtube_music_service.dart';
import '../widgets/music_interactive_scrubber.dart';
import '../widgets/lyrics_sheet.dart';
import 'listen_together_screen.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final downloader = context.watch<MusicDownloadService>();
    final currentSong = audioProvider.currentSong;
    final isPlaying = audioProvider.isPlaying;
    final isBuffering = audioProvider.isSongBuffering;
    final dur = audioProvider.songDuration;

    final isDownloaded = currentSong.isLocal || downloader.isDownloaded(currentSong.id);
    final downloadProg = downloader.getDownloadProgress(currentSong.id);
    final isDownloading = downloadProg != null && downloadProg < 1.0;

    final coverColor = currentSong.coverColor;

    return Scaffold(
      backgroundColor: const Color(0xFF0C130E),
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient Radial Aura Glow behind the album artwork
            Positioned(
              top: -60,
              left: 0,
              right: 0,
              height: 420,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.9,
                    colors: [
                      coverColor.withOpacity(0.28),
                      const Color(0xFF0C130E).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Main Player Column
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  // 1. Top Bar: Dismiss Chevron, Header Source Label, Queue Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          const Text(
                            'PLAYING FROM SANCTUARY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: Color(0xFFE07A5F),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentSong.isLocal
                                ? 'Offline Storage'
                                : (currentSong.addedBy.isNotEmpty ? currentSong.addedBy : 'YouTube Music'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _showQueueBottomSheet(context, audioProvider),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Icon(
                            Icons.queue_music_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // 2. Large High-Definition Album Artwork Hero
                  Center(
                    child: Container(
                      width: 290,
                      height: 290,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: coverColor.withOpacity(0.35),
                            blurRadius: 36,
                            spreadRadius: 2,
                            offset: const Offset(0, 14),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: currentSong.thumbnailUrl != null && currentSong.thumbnailUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: currentSong.thumbnailUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: coverColor,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => _buildFallbackVinyl(coverColor),
                              )
                            : _buildFallbackVinyl(coverColor),
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),

                  // 3. Track Details Row & Quick Actions (Download + Lyrics)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBuffering
                                  ? (audioProvider.bufferingSongTitle ?? currentSong.title)
                                  : currentSong.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentSong.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.65),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Lyrics Pill Button
                      GestureDetector(
                        onTap: () {
                          LyricsSheet.show(
                            context,
                            title: currentSong.title,
                            artist: currentSong.artist,
                            durationSeconds: currentSong.durationSeconds,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B2C20),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF2E4D38)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic_external_on_rounded, size: 14, color: Color(0xFFFDE047)),
                              SizedBox(width: 4),
                              Text(
                                'Lyrics',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFFDE047),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Download Offline Button
                      GestureDetector(
                        onTap: () async {
                          if (isDownloaded) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('"${currentSong.title}" is saved in offline storage ✦'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          if (isDownloading) return;

                          // Trigger explicit manual download
                          final track = YoutubeTrack(
                            id: currentSong.id,
                            title: currentSong.title,
                            artist: currentSong.artist,
                            durationSeconds: currentSong.durationSeconds,
                            thumbnailUrl: currentSong.thumbnailUrl ?? '',
                            audioStreamUrl: currentSong.audioUrl,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Downloading "${currentSong.title}"...'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          final ok = await downloader.downloadTrack(track);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Downloaded "${currentSong.title}" for offline playback!'
                                      : 'Download failed. Please try again.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF261E1B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDownloaded ? const Color(0xFFE07A5F) : const Color(0xFF4A342E),
                            ),
                          ),
                          child: Center(
                            child: isDownloading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      value: downloadProg,
                                      strokeWidth: 2,
                                      color: const Color(0xFFE07A5F),
                                    ),
                                  )
                                : Icon(
                                    isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                                    color: isDownloaded ? const Color(0xFFE07A5F) : Colors.white70,
                                    size: 18,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 4. Interactive Music Scrubber with Live Timestamp Display
                  ValueListenableBuilder<Duration>(
                    valueListenable: audioProvider.songPositionNotifier,
                    builder: (context, livePos, _) {
                      return MusicInteractiveScrubber(
                        position: livePos,
                        duration: dur,
                        onSeek: (target) => audioProvider.seekSong(target),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // 5. Main Transport Controls: Shuffle, Prev, Play/Pause, Next, Repeat
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Shuffle Button
                      IconButton(
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: audioProvider.isShuffle ? const Color(0xFFE07A5F) : Colors.white38,
                          size: 24,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          audioProvider.toggleShuffle();
                        },
                      ),

                      // Previous Button
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          audioProvider.prevSong();
                        },
                      ),

                      // Large Circular Warm Terracotta Play/Pause Button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          audioProvider.toggleSongPlay();
                        },
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE07A5F),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE07A5F).withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: isBuffering
                                ? const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.8,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                          ),
                        ),
                      ),

                      // Next Button
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          audioProvider.nextSong();
                        },
                      ),

                      // Repeat Mode Button
                      IconButton(
                        icon: Icon(
                          audioProvider.isRepeatOne ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                          color: audioProvider.isRepeatOne ? const Color(0xFFE07A5F) : Colors.white38,
                          size: 24,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          audioProvider.toggleRepeat();
                        },
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // 6. Bottom Row: Listen Together with Partner Quick Launcher
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ListenTogetherScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF132218),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF203B2A)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFF97316),
                            ),
                            child: const Center(
                              child: Icon(Icons.people_outline_rounded, color: Colors.black, size: 16),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Listen together with your partner ✦',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackVinyl(Color coverColor) {
    return Container(
      color: coverColor,
      child: Center(
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.4),
            border: Border.all(color: Colors.white24, width: 2),
          ),
          child: const Center(
            child: Icon(Icons.music_note_rounded, color: Colors.white, size: 48),
          ),
        ),
      ),
    );
  }

  void _showQueueBottomSheet(BuildContext context, AudioProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final songs = provider.songs;
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.65,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF0F1B13),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Up Next In Queue',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded, color: Colors.white54, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: songs.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, idx) {
                    final song = songs[idx];
                    final isCurrent = idx == provider.currentSongIndex;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: song.thumbnailUrl != null && song.thumbnailUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: song.thumbnailUrl!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(width: 44, height: 44, color: song.coverColor),
                              )
                            : Container(width: 44, height: 44, color: song.coverColor),
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? const Color(0xFFE07A5F) : Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? const Color(0xFFE07A5F).withOpacity(0.7) : Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.graphic_eq_rounded, color: Color(0xFFE07A5F), size: 20)
                          : null,
                      onTap: () {
                        provider.selectSong(idx);
                        Navigator.pop(ctx);
                      },
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
