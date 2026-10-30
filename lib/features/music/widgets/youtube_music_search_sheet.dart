import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/audio_provider.dart';
import '../../../core/services/youtube_music_service.dart';
import '../../../core/services/music_download_service.dart';

/// YouTube Music Search & Discovery Sheet (Echo Music style)
class YoutubeMusicSearchSheet extends StatefulWidget {
  const YoutubeMusicSearchSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const YoutubeMusicSearchSheet(),
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
    // Default initial query
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

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final downloader = context.watch<MusicDownloadService>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0C140F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Stream & download any song in the world ✦',
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
          const SizedBox(height: 14),

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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
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
                                  style: const TextStyle(
                                    color: Colors.white,
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
                                    // Download Button / Status
                                    if (isDownloaded)
                                      const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.sage,
                                          size: 22,
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

                                    // Play Button
                                    IconButton(
                                      icon: const Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: Color(0xFFA3E635),
                                        size: 32,
                                      ),
                                      onPressed: () async {
                                        HapticFeedback.mediumImpact();
                                        Navigator.pop(context);
                                        await audio.playYoutubeTrack(track);
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  HapticFeedback.mediumImpact();
                                  Navigator.pop(context);
                                  await audio.playYoutubeTrack(track);
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
