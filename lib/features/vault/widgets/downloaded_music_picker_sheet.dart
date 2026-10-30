import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/youtube_music_service.dart';
import '../../../core/services/music_download_service.dart';

/// Bottom sheet allowing user to select a downloaded YouTube song as Vault Theme Music
class DownloadedMusicPickerSheet extends StatelessWidget {
  const DownloadedMusicPickerSheet({super.key});

  static Future<YoutubeTrack?> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<YoutubeTrack>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DownloadedMusicPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloader = context.watch<MusicDownloadService>();
    final tracks = downloader.downloadedTracks;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF141916),
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

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🎵', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Vault Theme Music',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Plays automatically when opening this Vault ✦',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Body
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.music_off_rounded, color: Colors.white38, size: 30),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No Downloaded Music Yet 🍃',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Search any song in the Music tab and tap ⬇ Download to add it here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: tracks.length,
                    separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E2D22), height: 1),
                    itemBuilder: (context, idx) {
                      final track = tracks[idx];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: track.thumbnailUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: track.thumbnailUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    color: const Color(0xFF1E2D22),
                                    child: const Icon(Icons.music_note, color: Colors.white24),
                                  ),
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  color: const Color(0xFF1E2D22),
                                  child: const Icon(Icons.music_note, color: Colors.white24),
                                ),
                        ),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${track.artist}  •  ${track.durationFormatted}',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
                          ),
                          child: const Text(
                            'Select',
                            style: TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context, track);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
