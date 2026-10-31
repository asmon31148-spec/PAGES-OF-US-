import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/audio_provider.dart';
import '../../../core/services/youtube_music_service.dart';
import '../../../core/services/music_download_service.dart';
import '../screens/now_playing_screen.dart';

/// Full-Screen YouTube Music Search & Discovery Screen
class YoutubeMusicSearchSheet extends StatefulWidget {
  const YoutubeMusicSearchSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const YoutubeMusicSearchSheet(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<YoutubeMusicSearchSheet> createState() => _YoutubeMusicSearchSheetState();
}

class _YoutubeMusicSearchSheetState extends State<YoutubeMusicSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<YoutubeTrack> _searchResults = [];
  String? _errorMessage;

  final List<String> _quickVibes = [
    'Romantic Acoustic',
    'Arijit Singh',
    'Ed Sheeran',
    'Lo-Fi Midnight',
    'Taylor Swift',
    'Coke Studio',
  ];

  @override
  void initState() {
    super.initState();
    _performSearch('Romantic Acoustic');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _performSearch(query.trim());
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await YoutubeMusicService.instance.search(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load tracks. Check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  void _playTrack(BuildContext context, AudioProvider audio, YoutubeTrack track) async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    // Play directly without popping/redirecting!
    await audio.playYoutubeTrack(track);
    if (audio.lastPlayError != null && context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(audio.lastPlayError!),
          backgroundColor: const Color(0xFF2E1A1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      audio.clearPlayError();
    }
  }

  void _showAddToPlaylistSheet(BuildContext context, YoutubeTrack track) {
    HapticFeedback.lightImpact();
    final audio = context.read<AudioProvider>();
    final playlists = audio.playlists;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Color(0xFF111E16),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add to Playlist',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No playlists yet. Create one in Music Sanctuary!',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: playlists.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final pl = playlists[i];
                    final contains = pl.songIds.contains(track.id);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      tileColor: const Color(0xFF07100B),
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: pl.coverColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(Icons.music_note_rounded, color: pl.coverColor, size: 20),
                        ),
                      ),
                      title: Text(
                        pl.title,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${pl.songIds.length} songs',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                      trailing: contains
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.sage, size: 22)
                          : const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFA3E635), size: 22),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        audio.addYoutubeTrackToPlaylist(pl.id, track);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added "${track.title}" to ${pl.title} ✨'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final downloader = context.watch<MusicDownloadService>();
    final currentSong = audio.currentSong;
    final isPlaying = audio.isSongPlaying;

    return Scaffold(
      backgroundColor: const Color(0xFF0C140F),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🎵', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YouTube Music Discovery',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Stream & queue any song in the world ✦',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
            ),

            // Search Input Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: _onSearchChanged,
                onSubmitted: _performSearch,
                decoration: InputDecoration(
                  hintText: 'Search songs, artists, or paste link...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFA3E635), size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF142018),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Quick Vibe Chips
            SizedBox(
              height: 34,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _quickVibes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final vibe = _quickVibes[idx];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _searchController.text = vibe;
                      _performSearch(vibe);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16251B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF243B2C)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        vibe,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Search Results / Loading / Empty
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFA3E635)),
                          SizedBox(height: 12),
                          Text(
                            'Searching YouTube Music...',
                            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                        )
                      : _searchResults.isEmpty
                          ? const Center(
                              child: Text(
                                'No tracks found. Try another search.',
                                style: TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Color(0xFF18281E),
                                height: 1,
                              ),
                              itemBuilder: (context, idx) {
                                final track = _searchResults[idx];
                                final isDownloaded = downloader.isDownloaded(track.id);
                                final downloadProg = downloader.getDownloadProgress(track.id);
                                final isDownloading = downloadProg != null && downloadProg < 1.0;
                                final isThisPlaying = (currentSong.id == track.id || currentSong.youtubeId == track.id) && isPlaying;
                                final isThisBuffering = audio.isSongBuffering && audio.bufferingSongTitle == track.title;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: track.thumbnailUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: track.thumbnailUrl,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(
                                              color: const Color(0xFF1E2D22),
                                              child: const Icon(Icons.music_note, color: Colors.white24),
                                            ),
                                            errorWidget: (_, __, ___) => Container(
                                              color: const Color(0xFF1E2D22),
                                              child: const Icon(Icons.music_note, color: Colors.white24),
                                            ),
                                          )
                                        : Container(
                                            width: 50,
                                            height: 50,
                                            color: const Color(0xFF1E2D22),
                                            child: const Icon(Icons.music_note, color: Colors.white24),
                                          ),
                                  ),
                                  title: Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isThisPlaying ? const Color(0xFFA3E635) : Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${track.artist}  •  ${track.durationFormatted}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Add to Playlist Button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.playlist_add_rounded,
                                          color: Color(0xFF94A3B8),
                                          size: 22,
                                        ),
                                        tooltip: 'Add to Playlist',
                                        onPressed: () => _showAddToPlaylistSheet(context, track),
                                      ),

                                      // Add to Queue Button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.queue_music_rounded,
                                          color: Color(0xFF94A3B8),
                                          size: 20,
                                        ),
                                        tooltip: 'Queue Next',
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          audio.queueYoutubeTrack(track);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Queued "${track.title}" next ✦'),
                                              behavior: SnackBarBehavior.floating,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),

                                      // Download Button / Status
                                      if (isDownloaded)
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.sage,
                                            size: 20,
                                          ),
                                        )
                                      else if (isDownloading)
                                        Padding(
                                          padding: const EdgeInsets.all(10.0),
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              value: downloadProg,
                                              strokeWidth: 2,
                                              color: const Color(0xFFA3E635),
                                            ),
                                          ),
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(
                                            Icons.download_rounded,
                                            color: Color(0xFF94A3B8),
                                            size: 20,
                                          ),
                                          tooltip: 'Download Offline',
                                          onPressed: () async {
                                            HapticFeedback.lightImpact();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Downloading "${track.title}"...'),
                                                duration: const Duration(seconds: 2),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                            final ok = await downloader.downloadTrack(track);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    ok
                                                        ? 'Saved "${track.title}" offline! 🎵'
                                                        : 'Could not download "${track.title}". Please try another track.',
                                                  ),
                                                  duration: const Duration(seconds: 2),
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          },
                                        ),

                                      // Play / Pause Button
                                      if (isThisBuffering)
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFFA3E635),
                                            ),
                                          ),
                                        )
                                      else
                                        IconButton(
                                          icon: Icon(
                                            isThisPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                            color: const Color(0xFFA3E635),
                                            size: 32,
                                          ),
                                          onPressed: () {
                                            if (isThisPlaying) {
                                              audio.pauseSong();
                                            } else {
                                              _playTrack(context, audio, track);
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                  onTap: () => _playTrack(context, audio, track),
                                );
                              },
                            ),
            ),

            // Persistent Mini-Bar at bottom when a song is loaded
            if (currentSong.title.isNotEmpty)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NowPlayingScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF142018),
                    border: Border(
                      top: BorderSide(color: Color(0xFF1E2F23)),
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: currentSong.thumbnailUrl != null && currentSong.thumbnailUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: currentSong.thumbnailUrl!,
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 38,
                                height: 38,
                                color: currentSong.coverColor,
                                child: const Icon(Icons.music_note, color: Colors.black87, size: 20),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSong.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              currentSong.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: const Color(0xFFA3E635),
                          size: 26,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          audio.toggleSongPlay();
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
