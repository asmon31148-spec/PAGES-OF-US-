import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../providers/audio_provider.dart';
import '../models/music_models.dart';
import 'playlist_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/music_download_service.dart';
import '../widgets/youtube_music_search_sheet.dart';
import '../widgets/lyrics_sheet.dart';
import 'listen_together_screen.dart';
import '../widgets/music_interactive_scrubber.dart';

class MusicSanctuaryScreen extends StatefulWidget {
  const MusicSanctuaryScreen({super.key});

  @override
  State<MusicSanctuaryScreen> createState() => _MusicSanctuaryScreenState();
}

class _MusicSanctuaryScreenState extends State<MusicSanctuaryScreen> {
  int _activeTabIndex = 0; // 0: Songs, 1: Playlists, 2: Atmosphere

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF07100B),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF07100B),
      body: Stack(
        children: [
          // Ambient Warm Glow top-right (matching reference screenshots)
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD97706).withOpacity(0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Back (<), Title, Search (🔍), Add (+)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildCircleIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        _activeTabIndex == 3 ? 'Atmosphere' : (_activeTabIndex == 2 ? 'Downloaded' : 'Music'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      _buildCircleIconButton(
                        icon: Icons.search_rounded,
                        onTap: () => YoutubeMusicSearchSheet.show(context),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _showAddSongDialog(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFA3E635),
                          ),
                          child: const Center(
                            child: Icon(Icons.add_rounded, color: Colors.black, size: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Segmented Pill: Songs | Playlists | Atmosphere
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1A14), // Dark warm brown pill container
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        _buildTabPill('Songs', 0),
                        _buildTabPill('Playlists', 1),
                        _buildTabPill('Offline', 2),
                        _buildTabPill('Atmosphere', 3),
                      ],
                    ),
                  ),
                ),

                // Body content based on selected tab
                Expanded(
                  child: IndexedStack(
                    index: _activeTabIndex,
                    children: [
                      _buildSongsView(context),
                      _buildPlaylistsView(context),
                      _buildDownloadedView(context),
                      _buildAtmosphereView(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildTabPill(String title, int index) {
    final isSelected = _activeTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFA3E635) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.black : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: SONGS VIEW (Matches Image 1)
  // -------------------------------------------------------------
  Widget _buildSongsView(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final currentSong = audioProvider.currentSong;
    final isPlaying = audioProvider.isSongPlaying;
    final pos = audioProvider.songPosition;
    final dur = audioProvider.songDuration;
    final progress = dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
    final songs = audioProvider.songs;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Active Now Playing Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111E16),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF18281E)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: currentSong.thumbnailUrl != null && currentSong.thumbnailUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: currentSong.thumbnailUrl!,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 52,
                                height: 52,
                                color: currentSong.coverColor,
                                child: const Center(
                                  child: Icon(Icons.music_note_rounded, color: Colors.black87, size: 26),
                                ),
                              ),
                            )
                          : Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: currentSong.coverColor,
                              ),
                              child: const Center(
                                child: Icon(Icons.music_note_rounded, color: Colors.black87, size: 26),
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentSong.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentSong.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                          color: const Color(0xFF18281E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF243B2C)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mic_external_on_rounded, size: 14, color: Color(0xFFFDE047)),
                            SizedBox(width: 4),
                            Text('Lyrics', style: TextStyle(fontSize: 11, color: Color(0xFFFDE047), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Smooth Interactive Music Scrubber (Finger dragging to any sec)
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
                const SizedBox(height: 10),

                // Controls: Previous, Play/Pause (Lime circle), Next
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 26),
                      onPressed: () => audioProvider.prevSong(),
                    ),
                    const SizedBox(width: 18),
                    GestureDetector(
                      onTap: () => audioProvider.toggleSongPlay(),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFA3E635),
                        ),
                        child: Center(
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 26),
                      onPressed: () => audioProvider.nextSong(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Background Playback Switch (outside app listening toggle)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF111E16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF18281E)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: audioProvider.allowBackgroundPlayback
                        ? const Color(0xFFA3E635).withOpacity(0.2)
                        : const Color(0xFF1E2F23),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.headphones_rounded,
                      color: audioProvider.allowBackgroundPlayback
                          ? const Color(0xFFA3E635)
                          : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Play outside app',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        audioProvider.allowBackgroundPlayback
                            ? 'Plays in background with notification controls'
                            : 'Music pauses when you exit app',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: audioProvider.allowBackgroundPlayback
                              ? const Color(0xFFA3E635)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: audioProvider.allowBackgroundPlayback,
                  onChanged: (_) => audioProvider.toggleBackgroundPlayback(),
                  activeColor: const Color(0xFFA3E635),
                  activeTrackColor: const Color(0xFF223627),
                  inactiveThumbColor: const Color(0xFF64748B),
                  inactiveTrackColor: const Color(0xFF1E2F23),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Listen Together Banner Card
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ListenTogetherScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF111E16),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF18281E)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFFF97316),
                    ),
                    child: const Center(
                      child: Icon(Icons.people_outline_rounded, color: Colors.black87, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Listen together',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Sync songs with your partner',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Section: "Your songs"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your songs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${songs.length} songs · Sort',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (songs.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.music_off_outlined, color: Colors.white.withOpacity(0.25), size: 40),
                  const SizedBox(height: 12),
                  const Text('No songs in sanctuary', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Tap the + button above to upload custom music', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: songs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
              final song = songs[i];
              final isCurrent = i == audioProvider.currentSongIndex;

              return GestureDetector(
                onTap: () => audioProvider.selectSong(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111E16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent ? const Color(0xFFA3E635).withOpacity(0.6) : const Color(0xFF18281E),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: song.coverColor,
                        ),
                        child: Center(
                          child: Icon(
                            isCurrent && isPlaying ? Icons.equalizer_rounded : Icons.music_note_rounded,
                            color: Colors.black87,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isCurrent ? const Color(0xFFA3E635) : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${song.artist} · ${song.durationFormatted}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF64748B), size: 18),
                        onPressed: () => _showSongOptions(context, song),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // -------------------------------------------------------------
  // TAB: DOWNLOADED VIEW (Offline Music Player)
  // -------------------------------------------------------------
  Widget _buildDownloadedView(BuildContext context) {
    final downloader = context.watch<MusicDownloadService>();
    final audio = context.watch<AudioProvider>();
    final tracks = downloader.downloadedTracks;

    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFF111E16),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF18281E)),
              ),
              alignment: Alignment.center,
              child: const Text('💾', style: TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Downloaded Music Yet 🍃',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 36),
              child: Text(
                'Search any song on YouTube Music and tap ⬇ to listen offline anywhere with zero data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => YoutubeMusicSearchSheet.show(context),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Explore YouTube Music'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA3E635),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<double>(
      future: downloader.getTotalStorageUsedMb(),
      builder: (context, snapshot) {
        final sizeMb = snapshot.data ?? 0.0;
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // Storage Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF111E16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF18281E)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.download_done_rounded, color: Color(0xFFA3E635), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${tracks.length} songs offline • ${sizeMb.toStringAsFixed(1)} MB',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => YoutubeMusicSearchSheet.show(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFA3E635),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('+ Download More', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Downloaded Songs List
            ...tracks.map((track) {
              final isCurrent = audio.currentSong.id == track.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isCurrent ? const Color(0xFF16251B) : const Color(0xFF111E16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrent ? const Color(0xFFA3E635).withOpacity(0.5) : const Color(0xFF18281E),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: track.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: track.thumbnailUrl,
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 46,
                              height: 46,
                              color: const Color(0xFF1E2D22),
                              child: const Icon(Icons.music_note, color: Colors.white24),
                            ),
                          )
                        : Container(
                            width: 46,
                            height: 46,
                            color: const Color(0xFF1E2D22),
                            child: const Icon(Icons.music_note, color: Colors.white24),
                          ),
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? const Color(0xFFA3E635) : Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${track.artist}  •  ${track.durationFormatted}  •  Offline ✓',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isCurrent && audio.isSongPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                          color: const Color(0xFFA3E635),
                          size: 30,
                        ),
                        onPressed: () {
                          if (isCurrent && audio.isSongPlaying) {
                            audio.pauseSong();
                          } else {
                            audio.playYoutubeTrack(track);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          await downloader.deleteTrack(track.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Removed "${track.title}" from downloads')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    audio.playYoutubeTrack(track);
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // TAB 2: PLAYLISTS VIEW
  // -------------------------------------------------------------
  Widget _buildPlaylistsView(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final playlists = audioProvider.playlists;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Playlists',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              GestureDetector(
                onTap: () => _showCreatePlaylistDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111E16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E2F23)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.add_rounded, size: 14, color: Color(0xFFA3E635)),
                      SizedBox(width: 4),
                      Text('New Playlist', style: TextStyle(fontSize: 11, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: playlists.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final pl = playlists[i];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailScreen(playlist: pl),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111E16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF18281E)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: pl.coverColor,
                        ),
                        child: const Center(
                          child: Icon(Icons.music_note_rounded, color: Colors.black87, size: 26),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pl.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Builder(
                              builder: (context) {
                                final songCount = audioProvider.songs
                                    .where((s) => pl.songIds.contains(s.id))
                                    .length;
                                return Text(
                                  '$songCount ${songCount == 1 ? "song" : "songs"}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 14),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: ATMOSPHERE VIEW (Matches Image 3)
  // -------------------------------------------------------------
  Widget _buildAtmosphereView(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final stems = audioProvider.atmosphereStems;
    final isPlaying = audioProvider.isAtmospherePlaying;
    final presets = ['Auto mix', 'Soft', 'Calm', 'Peace', 'Deep sleep'];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle instruction
          const Text(
            'Mix your own calm. Stops when you leave the app.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),

          // Presets horizontal pills
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final p = presets[i];
                final isSelected = audioProvider.activePreset == p;
                final isAutoMix = p == 'Auto mix';

                return GestureDetector(
                  onTap: () => audioProvider.applyPreset(p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF223627)
                          : const Color(0xFF111E16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFA3E635)
                            : (isAutoMix ? const Color(0xFF334155) : const Color(0xFF18281E)),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isAutoMix ? '✦ Auto mix' : p,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xFFA3E635) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // "Your mix" Master Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111E16),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF18281E)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => audioProvider.toggleAtmospherePlay(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFA3E635),
                        ),
                        child: Center(
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your mix',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getActiveStemsLabel(stems),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2F23),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Master volume slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Master volume', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    Text(
                      '${(audioProvider.masterAtmosphereVolume * 100).round()}%',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFA3E635),
                    inactiveTrackColor: const Color(0xFF1E2F23),
                    thumbColor: Colors.white,
                    overlayColor: const Color(0xFFA3E635).withOpacity(0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: audioProvider.masterAtmosphereVolume,
                    onChanged: (val) => audioProvider.setMasterVolume(val),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: "Sounds"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Sounds',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                'Drag to set intensity',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stem Sliders List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final key = stems.keys.elementAt(i);
              final stem = stems[key]!;
              final isOff = stem.volume < 0.02;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF111E16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF18281E)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isOff ? const Color(0xFF15221A) : stem.iconColor,
                      ),
                      child: Center(
                        child: Icon(
                          stem.icon,
                          color: isOff ? const Color(0xFF475569) : Colors.black87,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                stem.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isOff ? const Color(0xFF94A3B8) : Colors.white,
                                ),
                              ),
                              Text(
                                isOff ? 'Off' : '${stem.percentage}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isOff ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFA3E635),
                              inactiveTrackColor: const Color(0xFF1E2F23),
                              thumbColor: Colors.white,
                              trackHeight: 3.5,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            ),
                            child: Slider(
                              value: stem.volume,
                              onChanged: (val) {
                                audioProvider.setStemVolume(key, val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _getActiveStemsLabel(Map<String, AtmosphereStem> stems) {
    final active = stems.values.where((s) => s.isActive).map((s) => s.title).toList();
    if (active.isEmpty) return 'None active';
    return active.join(' · ');
  }

  Widget _buildCircleIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF111E16),
          border: Border.all(color: const Color(0xFF1E2F23)),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _showAddSongDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final artistCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    bool isPickingFile = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFF111E16),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Song to Sanctuary',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // PRIMARY OPTION: Pick from Device Storage
                  GestureDetector(
                    onTap: isPickingFile
                        ? null
                        : () async {
                            setModalState(() => isPickingFile = true);
                            try {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'],
                              );
                              if (result != null && result.files.isNotEmpty) {
                                final file = result.files.first;
                                final path = file.path;
                                if (path != null) {
                                  String cleanTitle = file.name;
                                  final dot = cleanTitle.lastIndexOf('.');
                                  if (dot > 0) cleanTitle = cleanTitle.substring(0, dot);
                                  cleanTitle = cleanTitle.replaceAll('_', ' ').replaceAll('-', ' ');

                                  final newSong = SongItem(
                                    id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                                    title: cleanTitle,
                                    artist: 'From your device',
                                    durationSeconds: 180,
                                    audioUrl: path,
                                    coverColor: const Color(0xFFA3E635),
                                    isLocal: true,
                                    addedBy: 'You',
                                  );

                                  if (ctx.mounted) {
                                    final provider = ctx.read<AudioProvider>();
                                    provider.addCustomSong(newSong);
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added "$cleanTitle" to your sanctuary ✦'),
                                        backgroundColor: const Color(0xFF15261C),
                                      ),
                                    );
                                    // Start playing immediately!
                                    provider.selectSong(provider.songs.length - 1);
                                  }
                                }
                              }
                            } catch (e) {
                              debugPrint('File picker error: $e');
                            } finally {
                              if (ctx.mounted) {
                                setModalState(() => isPickingFile = false);
                              }
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16291C),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA3E635).withOpacity(0.5), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFA3E635),
                            ),
                            child: Center(
                              child: isPickingFile
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                    )
                                  : const Icon(Icons.folder_open_rounded, color: Colors.black, size: 22),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Choose from device storage',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Select MP3, M4A, WAV, AAC from your phone',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFA3E635), size: 14),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                  Row(
                    children: const [
                      Expanded(child: Divider(color: Color(0xFF1E2F23))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR STREAM FROM URL',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                      ),
                      Expanded(child: Divider(color: Color(0xFF1E2F23))),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Song Title (e.g. Our Sanctuary)',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF07100B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: artistCtrl,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Artist Name',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF07100B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: urlCtrl,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Audio Stream URL (mp3/ogg/m4a)',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFF07100B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        final artist = artistCtrl.text.trim();
                        final url = urlCtrl.text.trim();
                        if (title.isNotEmpty) {
                          final newSong = SongItem(
                            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                            title: title,
                            artist: artist.isEmpty ? 'Custom Track' : artist,
                            durationSeconds: 180,
                            audioUrl: url.isEmpty ? 'audio/lofi_sanctuary.mp3' : url,
                            coverColor: const Color(0xFF86EFAC),
                            isLocal: url.isEmpty,
                            addedBy: 'You',
                          );
                          ctx.read<AudioProvider>().addCustomSong(newSong);
                          Navigator.pop(ctx);
                          ctx.read<AudioProvider>().selectSong(ctx.read<AudioProvider>().songs.length - 1);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA3E635),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Add Stream ✦', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final titleCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF111E16),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  hintText: 'Playlist Name (e.g. Stargazing)',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF07100B),
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
                      context.read<AudioProvider>().createPlaylist(title, ['song_1', 'song_2']);
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA3E635),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Create Playlist ✦', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSongOptions(BuildContext context, SongItem song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF111E16),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: Color(0xFFA3E635)),
                title: const Text('Add to playlist', style: TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Added to Calm evenings ✦')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Colors.white),
                title: const Text('Share song with partner', style: TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shared with partner in sanctuary ✦')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF87171)),
                title: const Text('Delete from sanctuary', style: TextStyle(color: Color(0xFFF87171), fontSize: 13)),
                onTap: () {
                  context.read<AudioProvider>().deleteSong(song.id);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Permanently removed "${song.title}" ✦'),
                      backgroundColor: const Color(0xFF1E1A29),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSearchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final audio = ctx.watch<AudioProvider>();
            final allSongs = audio.songs;
            final filtered = searchQuery.isEmpty
                ? allSongs
                : allSongs
                    .where((s) =>
                        s.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                        s.artist.toLowerCase().contains(searchQuery.toLowerCase()))
                    .toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.7,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF141916),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Search Sanctuary Tracks',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search songs, moods, atmospheres...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFA3E635)),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => setModalState(() => searchQuery = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No tracks found', style: TextStyle(color: Colors.white54)),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              final song = filtered[idx];
                              return ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: song.coverColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.music_note_rounded, color: Colors.black87),
                                ),
                                title: Text(song.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text(song.artist, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                trailing: Text(song.durationFormatted, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                onTap: () {
                                  final globalIndex = audio.songs.indexWhere((s) => s.id == song.id);
                                  if (globalIndex != -1) {
                                    audio.selectSong(globalIndex);
                                    Navigator.pop(modalCtx);
                                  }
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
      },
    );
  }
}
