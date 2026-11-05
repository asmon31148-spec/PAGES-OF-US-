import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/audio_provider.dart';
import '../../../core/services/youtube_music_service.dart';
import '../../../core/services/music_download_service.dart';
import '../screens/now_playing_screen.dart';
import '../widgets/glass/glass_ambient_background.dart';
import '../widgets/glass/glass_card.dart';
import '../theme/glass_tokens.dart';

/// Full-Screen Music Discovery Screen with Curated Recommendations & 3-Dot Menu
class YoutubeMusicSearchSheet extends StatefulWidget {
  final String? initialQuery;
  const YoutubeMusicSearchSheet({super.key, this.initialQuery});

  static Future<void> show(BuildContext context, {String? initialQuery}) {
    HapticFeedback.lightImpact();
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YoutubeMusicSearchSheet(initialQuery: initialQuery),
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
    '✨ Top Hits',
    'Arijit Singh',
    'Ed Sheeran',
    'Taylor Swift',
    'Atif Aslam',
    'Coke Studio',
    'Romantic Bollywood',
    'Midnight Lo-Fi',
    'Shreya Ghoshal',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    } else {
      // Load diverse top hits by default
      _performSearch('Top Romantic Songs');
    }
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
    await audio.playYoutubeTrack(track);
    if (audio.lastPlayError != null && context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(audio.lastPlayError!, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF2E1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      audio.clearPlayError();
    }
  }

  void _showTrackOptions(BuildContext context, YoutubeTrack track) {
    HapticFeedback.lightImpact();
    final audio = context.read<AudioProvider>();
    final downloader = context.read<MusicDownloadService>();
    final isDownloaded = downloader.isDownloaded(track.id);
    final downloadProg = downloader.getDownloadProgress(track.id);
    final isDownloading = downloadProg != null && downloadProg < 1.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF13151B).withOpacity(0.88),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.25), width: 1.2),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Track header
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: track.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: track.thumbnailUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            color: const Color(0xFF20232E),
                            child: const Icon(Icons.music_note, color: Colors.white24),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${track.artist}  •  ${track.durationFormatted}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF222634), height: 1),
              const SizedBox(height: 8),

              // Option 1: Add to Playlist
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.playlist_add_rounded, color: Color(0xFFE07A5F), size: 24),
                title: const Text('Add to Playlist', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Save to your custom playlists', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToPlaylistSheet(context, track);
                },
              ),

              // Option 2: Queue Next
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.queue_music_rounded, color: Color(0xFFE9C46A), size: 24),
                title: const Text('Play Next in Queue', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Add to your and partner\'s upcoming queue', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                onTap: () {
                  HapticFeedback.mediumImpact();
                  audio.queueYoutubeTrack(track);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Queued "${track.title}" next ✦', style: const TextStyle(color: Colors.white)),
                      backgroundColor: const Color(0xFF1E212B),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),

              // Option 3: Download Offline
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(
                  isDownloaded ? Icons.check_circle_rounded : Icons.download_rounded,
                  color: isDownloaded ? const Color(0xFF81B29A) : const Color(0xFF94A3B8),
                  size: 24,
                ),
                title: Text(
                  isDownloaded ? 'Downloaded to Sanctuary' : (isDownloading ? 'Downloading...' : 'Download Offline'),
                  style: TextStyle(
                    color: isDownloaded ? const Color(0xFF81B29A) : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  isDownloaded ? 'Available anytime without internet' : 'Save for offline streaming',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                onTap: isDownloaded || isDownloading
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Downloading "${track.title}"...', style: const TextStyle(color: Colors.white)),
                            backgroundColor: const Color(0xFF1E212B),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        final ok = await downloader.downloadTrack(track);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok ? 'Saved "${track.title}" offline! 🎵' : 'Could not download "${track.title}".',
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: const Color(0xFF1E212B),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  void _showCreatePlaylistForTrackDialog(BuildContext context, YoutubeTrack track) {
    final titleCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF13151B).withOpacity(0.88),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.25), width: 1.2),
                ),
              ),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Playlist',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Playlist Name (e.g. Calm Nights, Acoustic)',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF0F1115),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    if (title.isNotEmpty) {
                      final audio = context.read<AudioProvider>();
                      final plId = 'pl_${DateTime.now().millisecondsSinceEpoch}';
                      audio.createPlaylist(title, []);
                      audio.addYoutubeTrackToPlaylist(plId, track);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Created "$title" and added "${track.title}" ✦', style: const TextStyle(color: Colors.white)),
                          backgroundColor: const Color(0xFF1E212B),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE07A5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Create Playlist & Add ✦', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  void _showAddToPlaylistSheet(BuildContext context, YoutubeTrack track) {
    HapticFeedback.lightImpact();
    final audio = context.read<AudioProvider>();
    final playlists = audio.playlists;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.72,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF13151B).withOpacity(0.88),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.25), width: 1.2),
              ),
            ),
            child: SafeArea(
              child: Column(
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
                            fontSize: 18,
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
                    child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // + Create New Playlist Action Button
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreatePlaylistForTrackDialog(context, track);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE07A5F).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.add_circle_outline_rounded, color: Color(0xFFE07A5F), size: 22),
                      SizedBox(width: 12),
                      Text(
                        'Create New Playlist',
                        style: TextStyle(
                          color: Color(0xFFE07A5F),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No playlists yet. Go to Playlists tab to create one!',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: playlists.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final pl = playlists[i];
                      final contains = pl.songIds.contains(track.id);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        tileColor: const Color(0xFF1B1D26),
                        leading: Container(
                          width: 40,
                          height: 40,
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
                          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${pl.songIds.length} songs',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                        trailing: contains
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF81B29A), size: 22)
                            : const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFE07A5F), size: 22),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          audio.addYoutubeTrackToPlaylist(pl.id, track);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added "${track.title}" to ${pl.title} ✦', style: const TextStyle(color: Colors.white)),
                              backgroundColor: const Color(0xFF1E212B),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final currentSong = audio.currentSong;
    final isPlaying = audio.isSongPlaying;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassAmbientBackground(
        fallbackColor: const Color(0xFFE07A5F),
        child: SafeArea(
          child: Column(
            children: [
              // Top App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.20)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFE07A5F).withOpacity(0.35),
                            const Color(0xFFE07A5F).withOpacity(0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.5)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🎵', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Music Discovery',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Stream & queue any track in your sanctuary ✦',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.20)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Search Input Bar (Apple Liquid Glass Pill)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.14),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: false,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        onChanged: _onSearchChanged,
                        onSubmitted: _performSearch,
                        decoration: InputDecoration(
                          hintText: 'Search songs, artists, or paste link...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFE07A5F), size: 22),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: Colors.white70, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quick Vibe Chips (Liquid Glass frosted pills)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickVibes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final vibe = _quickVibes[idx];
                    final isTopHits = vibe.startsWith('✨');
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final query = isTopHits ? 'Top Romantic Songs' : vibe;
                        _searchController.text = query;
                        _performSearch(query);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isTopHits
                                ? [
                                    const Color(0xFFE07A5F).withOpacity(0.32),
                                    const Color(0xFFE07A5F).withOpacity(0.12),
                                  ]
                                : [
                                    Colors.white.withOpacity(0.12),
                                    Colors.white.withOpacity(0.04),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isTopHits
                                ? const Color(0xFFE07A5F).withOpacity(0.6)
                                : Colors.white.withOpacity(0.24),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          vibe,
                          style: TextStyle(
                            fontSize: 12,
                            color: isTopHits ? Colors.white : const Color(0xFFEDEAE5),
                            fontWeight: isTopHits ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Search Results / Loading / Empty
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFE07A5F)),
                            SizedBox(height: 12),
                            Text(
                              'Searching music catalog...',
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
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                itemCount: _searchResults.length,
                                itemBuilder: (context, idx) {
                                  final track = _searchResults[idx];
                                  final isThisPlaying = (currentSong.id == track.id || currentSong.youtubeId == track.id) && isPlaying;
                                  final isThisBuffering = audio.isSongBuffering && audio.bufferingSongTitle == track.title;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: isThisPlaying
                                            ? [
                                                const Color(0xFFE07A5F).withOpacity(0.22),
                                                const Color(0xFFE07A5F).withOpacity(0.08),
                                              ]
                                            : [
                                                Colors.white.withOpacity(0.08),
                                                Colors.white.withOpacity(0.02),
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isThisPlaying
                                            ? const Color(0xFFE07A5F).withOpacity(0.55)
                                            : Colors.white.withOpacity(0.14),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.18),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          leading: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: track.thumbnailUrl.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: track.thumbnailUrl,
                                                    width: 48,
                                                    height: 48,
                                                    fit: BoxFit.cover,
                                                    placeholder: (_, __) => Container(
                                                      color: Colors.white.withOpacity(0.06),
                                                      child: const Icon(Icons.music_note, color: Colors.white24),
                                                    ),
                                                    errorWidget: (_, __, ___) => Container(
                                                      color: Colors.white.withOpacity(0.06),
                                                      child: const Icon(Icons.music_note, color: Colors.white24),
                                                    ),
                                                  )
                                                : Container(
                                                    width: 48,
                                                    height: 48,
                                                    color: Colors.white.withOpacity(0.06),
                                                    child: const Icon(Icons.music_note, color: Colors.white24),
                                                  ),
                                          ),
                                          title: Text(
                                            track.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isThisPlaying ? const Color(0xFFE07A5F) : Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${track.artist}  •  ${track.durationFormatted}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 12,
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Play / Pause Button with Liquid Glass Pill
                                              if (isThisBuffering)
                                                const Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child: SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Color(0xFFE07A5F),
                                                    ),
                                                  ),
                                                )
                                              else
                                                Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        const Color(0xFFE07A5F).withOpacity(0.85),
                                                        const Color(0xFFD4694E),
                                                      ],
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFFE07A5F).withOpacity(0.4),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: IconButton(
                                                    padding: EdgeInsets.zero,
                                                    icon: Icon(
                                                      isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                      color: Colors.white,
                                                      size: 22,
                                                    ),
                                                    onPressed: () {
                                                      if (isThisPlaying) {
                                                        audio.pauseSong();
                                                      } else {
                                                        _playTrack(context, audio, track);
                                                      }
                                                    },
                                                  ),
                                                ),

                                              const SizedBox(width: 4),

                                              // 3-Dot More Menu
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.more_vert_rounded,
                                                  color: Colors.white70,
                                                  size: 20,
                                                ),
                                                tooltip: 'More Options',
                                                onPressed: () => _showTrackOptions(context, track),
                                              ),
                                            ],
                                          ),
                                          onTap: () => _playTrack(context, audio, track),
                                        ),
                                      );
                                },
                              ),
              ),

              // Persistent Floating Apple Liquid Glass Mini-Bar at bottom
              if (currentSong.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: GestureDetector(
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF161922).withOpacity(0.88),
                                const Color(0xFF0F1116).withOpacity(0.92),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withOpacity(0.24), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: currentSong.thumbnailUrl != null && currentSong.thumbnailUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: currentSong.thumbnailUrl!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 40,
                                        height: 40,
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
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFE07A5F),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE07A5F).withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    audio.toggleSongPlay();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
