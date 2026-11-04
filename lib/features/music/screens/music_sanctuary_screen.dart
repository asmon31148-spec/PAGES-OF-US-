import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../providers/audio_provider.dart';
import '../../../providers/auth_provider.dart';
import '../models/music_models.dart';
import 'playlist_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/music_download_service.dart';
import '../widgets/youtube_music_search_sheet.dart';
import '../widgets/lyrics_sheet.dart';
import 'listen_together_screen.dart';
import 'now_playing_screen.dart';
import '../widgets/music_interactive_scrubber.dart';
import '../theme/glass_tokens.dart';
import '../widgets/glass/glass_ambient_background.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_mini_player.dart';
import '../widgets/glass/glass_sheet.dart';

class MusicSanctuaryScreen extends StatefulWidget {
  const MusicSanctuaryScreen({super.key});

  @override
  State<MusicSanctuaryScreen> createState() => _MusicSanctuaryScreenState();
}

class _MusicSanctuaryScreenState extends State<MusicSanctuaryScreen> {
  int _activeTabIndex = 0; // 0: Songs, 1: Playlists, 2: Offline, 3: Atmosphere
  String _sortMode = 'recent'; // 'recent', 'title', 'artist', 'offline'

  static final List<Map<String, dynamic>> _curatedMixes = [
    {
      'title': 'Late Night Lofi',
      'subtitle': 'Soft beats & chill vibes',
      'query': 'Late Night Lofi chill beats',
      'icon': Icons.nightlight_round,
      'gradient': [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      'badge': 'Cozy',
    },
    {
      'title': 'Romantic Sanctuary',
      'subtitle': 'Acoustic Bollywood & love',
      'query': 'Romantic Bollywood Acoustic Love Songs',
      'icon': Icons.favorite_rounded,
      'gradient': [const Color(0xFFEC4899), const Color(0xFFF43F5E)],
      'badge': 'For Two',
    },
    {
      'title': 'Monsoon Melodies',
      'subtitle': 'Rain drops & peaceful acoustic',
      'query': 'Monsoon acoustic relaxing songs',
      'icon': Icons.water_drop_rounded,
      'gradient': [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)],
      'badge': 'Peaceful',
    },
    {
      'title': 'Warm Soul & Indie',
      'subtitle': 'Gentle guitars & slow melodies',
      'query': 'Indie acoustic soul ballads',
      'icon': Icons.album_rounded,
      'gradient': [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      'badge': 'Melodic',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final currentSong = audioProvider.currentSong;

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
        bottomNavigationBar: const SafeArea(
          top: false,
          child: GlassMiniPlayer(),
        ),
        body: GlassAmbientBackground(
          imageUrl: currentSong.thumbnailUrl,
          fallbackColor: currentSong.coverColor,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Back (<), Title, Headphones, Search (🔍), Add (+)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      GlassButton(
                        onTap: () => Navigator.pop(context),
                        width: 40,
                        height: 40,
                        isCircle: true,
                        child: const Center(
                          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _activeTabIndex == 3
                              ? 'Atmosphere'
                              : (_activeTabIndex == 2
                                  ? 'Downloaded'
                                  : (_activeTabIndex == 1 ? 'Playlists' : 'Music Sanctuary')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GlassButton(
                        width: 40,
                        height: 40,
                        isCircle: true,
                        onTap: () {
                          audioProvider.toggleBackgroundPlayback();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                audioProvider.allowBackgroundPlayback
                                    ? 'Background playback enabled'
                                    : 'Background playback disabled',
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Center(
                          child: Icon(
                            audioProvider.allowBackgroundPlayback
                                ? Icons.headphones_rounded
                                : Icons.headphones_outlined,
                            color: audioProvider.allowBackgroundPlayback
                                ? GlassTokens.accent
                                : Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GlassButton(
                        width: 40,
                        height: 40,
                        isCircle: true,
                        onTap: () => YoutubeMusicSearchSheet.show(context),
                        child: const Center(
                          child: Icon(Icons.search_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GlassButton(
                        width: 40,
                        height: 40,
                        isCircle: true,
                        tintColor: GlassTokens.accent.withOpacity(0.35),
                        borderColor: GlassTokens.accent.withOpacity(0.7),
                        onTap: () => _showAddSongDialog(context),
                        child: const Center(
                          child: Icon(Icons.add_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),

                // Segmented Pill: Songs | Playlists | Offline | Atmosphere
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white12),
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
        ),
      ),
    );
  }

  Widget _buildTabPill(String title, int index) {
    final isSelected = _activeTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeTabIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? GlassTokens.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : GlassTokens.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: SONGS VIEW (Apple iOS 26 Liquid Glass)
  // -------------------------------------------------------------
  Widget _buildSongsView(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final authProvider = context.watch<AuthProvider>();
    final partner = authProvider.partner;
    final partnerName = (partner?.nickname.isNotEmpty ?? false) ? partner!.nickname : 'Partner';
    final songs = audioProvider.songs;
    final playlists = audioProvider.playlists;

    var displaySongs = List<SongItem>.from(songs);
    if (_sortMode == 'title') {
      displaySongs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_sortMode == 'artist') {
      displaySongs.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
    } else if (_sortMode == 'offline') {
      displaySongs = displaySongs.where((s) => s.isLocal || MusicDownloadService.instance.isDownloaded(s.id)).toList();
    }

    final recentSongs = songs.take(8).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Listen Together Elevated Glass Hero Card
          GlassCard(
            enableBlur: false,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE07A5F), Color(0xFFF97316)],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.people_alt_rounded, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Listen Together',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF86EFAC).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF86EFAC)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Shared synced room with $partnerName',
                        style: const TextStyle(fontSize: 11.5, color: GlassTokens.textSecondary),
                      ),
                    ],
                  ),
                ),
                GlassButton(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ListenTogetherScreen()),
                    );
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Curated For You & Zoobiii (Recommended Albums & Mixes)
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 16, color: GlassTokens.accent),
              const SizedBox(width: 6),
              Text(
                'Curated for You & $partnerName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _curatedMixes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final mix = _curatedMixes[index];
                final gradient = mix['gradient'] as List<Color>;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    YoutubeMusicSearchSheet.show(context, initialQuery: mix['query'] as String);
                  },
                  child: Container(
                    width: 154,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          gradient[0].withOpacity(0.32),
                          gradient[1].withOpacity(0.12),
                        ],
                      ),
                      border: Border.all(color: gradient[0].withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: gradient[0].withOpacity(0.5),
                              ),
                              child: Icon(mix['icon'] as IconData, color: Colors.white, size: 18),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                mix['badge'] as String,
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          mix['title'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mix['subtitle'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: GlassTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // 3. Recently Played Horizontal Carousel (if songs exist)
          if (recentSongs.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.history_rounded, size: 16, color: GlassTokens.accent),
                SizedBox(width: 6),
                Text(
                  'Recently Played',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: recentSongs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final song = recentSongs[index];
                  final originalIndex = songs.indexOf(song);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      audioProvider.selectSong(originalIndex);
                    },
                    child: SizedBox(
                      width: 106,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: song.thumbnailUrl != null && song.thumbnailUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: song.thumbnailUrl!,
                                    width: 106,
                                    height: 106,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 106,
                                      height: 106,
                                      color: song.coverColor,
                                      child: const Icon(Icons.music_note, color: Colors.black87, size: 32),
                                    ),
                                  )
                                : Container(
                                    width: 106,
                                    height: 106,
                                    color: song.coverColor,
                                    child: const Icon(Icons.music_note, color: Colors.black87, size: 32),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: GlassTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 3. Playlists for Two Section
          if (playlists.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.queue_music_rounded, size: 16, color: GlassTokens.accent),
                const SizedBox(width: 6),
                const Text(
                  'Your Playlists',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _activeTabIndex = 1),
                  child: const Text(
                    'See all',
                    style: TextStyle(fontSize: 12, color: GlassTokens.accent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 124,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: playlists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final pl = playlists[index];
                  return SizedBox(
                    width: 175,
                    child: GlassCard(
                      enableBlur: false,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: pl.coverColor.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Icon(Icons.music_note, color: pl.coverColor, size: 18),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pl.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '${pl.songCount} songs',
                                      style: const TextStyle(fontSize: 10.5, color: GlassTokens.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: GlassButton(
                                  onTap: () => audioProvider.playPlaylist(pl),
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: const Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                                        SizedBox(width: 2),
                                        Text('Play', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: GlassButton(
                                  onTap: () {
                                    audioProvider.queuePlaylist(pl);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Queued "${pl.title}" (${pl.songCount} tracks) ✦'),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: const Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.playlist_add_rounded, size: 14, color: GlassTokens.accent),
                                        SizedBox(width: 2),
                                        Text('Queue', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 4. All Songs / Library Header & Sort
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'All Songs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${displaySongs.length}',
                      style: const TextStyle(fontSize: 11, color: GlassTokens.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _showSortBottomSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sortMode == 'title'
                            ? 'Title (A-Z)'
                            : _sortMode == 'artist'
                                ? 'Artist'
                                : _sortMode == 'offline'
                                    ? 'Offline Only'
                                    : 'Recent',
                        style: const TextStyle(fontSize: 11, color: GlassTokens.accent, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.sort_rounded, size: 13, color: GlassTokens.accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (displaySongs.isEmpty)
            GlassCard(
              enableBlur: false,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.music_off_outlined, color: Colors.white.withOpacity(0.25), size: 40),
                    const SizedBox(height: 12),
                    Text(
                      _sortMode == 'offline' ? 'No offline songs downloaded yet' : 'No songs in library',
                      style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _sortMode == 'offline'
                          ? 'Tap search above to find songs and download them'
                          : 'Search songs or upload audio files to start listening',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displaySongs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final song = displaySongs[i];
                final originalIndex = songs.indexOf(song);
                final isCurrent = originalIndex == audioProvider.currentSongIndex;
                final isOffline = song.isLocal || MusicDownloadService.instance.isDownloaded(song.id);

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    audioProvider.selectSong(originalIndex);
                  },
                  child: GlassCard(
                    enableBlur: false,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    borderColor: isCurrent ? GlassTokens.accent.withOpacity(0.7) : null,
                    tintColor: isCurrent ? GlassTokens.accent.withOpacity(0.12) : null,
                    child: Row(
                      children: [
                        ClipRRect(
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
                                    child: Icon(
                                      isCurrent && audioProvider.isSongPlaying ? Icons.equalizer_rounded : Icons.music_note_rounded,
                                      color: Colors.black87,
                                      size: 20,
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 44,
                                  height: 44,
                                  color: song.coverColor,
                                  child: Icon(
                                    isCurrent && audioProvider.isSongPlaying ? Icons.equalizer_rounded : Icons.music_note_rounded,
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? GlassTokens.accent : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (isOffline) ...[
                                    const Icon(Icons.offline_pin_rounded, size: 12, color: GlassTokens.accent),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      '${song.artist} · ${song.durationFormatted}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: GlassTokens.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70, size: 20),
                          onPressed: () => _showSongOptions(context, song),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
  // -------------------------------------------------------------
  // TAB: DOWNLOADED VIEW (Offline Music Player - Liquid Glass)
  // -------------------------------------------------------------
  Widget _buildDownloadedView(BuildContext context) {
    final downloader = context.watch<MusicDownloadService>();
    final audio = context.watch<AudioProvider>();
    final tracks = downloader.downloadedTracks;

    if (tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💾', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 16),
                const Text(
                  'No Downloaded Music Yet 🍃',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Search any song and tap download to listen offline anywhere with zero data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: GlassTokens.textSecondary, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 20),
                GlassButton(
                  onTap: () => YoutubeMusicSearchSheet.show(context),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: GlassTokens.accent),
                      SizedBox(width: 8),
                      Text('Explore Music', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FutureBuilder<double>(
      future: downloader.getTotalStorageUsedMb(),
      builder: (context, snapshot) {
        final sizeMb = snapshot.data ?? 0.0;
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Storage Header Banner
            GlassCard(
              enableBlur: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.download_done_rounded, color: GlassTokens.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${tracks.length} songs offline • ${sizeMb.toStringAsFixed(1)} MB',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  GlassButton(
                    onTap: () => YoutubeMusicSearchSheet.show(context),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: const Text('+ Download More', style: TextStyle(fontSize: 11.5, color: GlassTokens.accent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Downloaded Songs List
            ...tracks.map((track) {
              final isCurrent = audio.currentSong.id == track.id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  enableBlur: false,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  borderColor: isCurrent ? GlassTokens.accent.withOpacity(0.7) : null,
                  tintColor: isCurrent ? GlassTokens.accent.withOpacity(0.12) : null,
                  child: Row(
                    children: [
                      ClipRRect(
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent ? GlassTokens.accent : Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${track.artist}  •  ${track.durationFormatted}  •  Offline ✓',
                              style: const TextStyle(color: GlassTokens.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isCurrent && audio.isSongPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                              color: GlassTokens.accent,
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
                                  SnackBar(
                                    content: Text('Removed "${track.title}" from downloads'),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
  // -------------------------------------------------------------
  // TAB 2: PLAYLISTS VIEW (Liquid Glass)
  // -------------------------------------------------------------
  Widget _buildPlaylistsView(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final playlists = audioProvider.playlists;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Playlists',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              GlassButton(
                onTap: () => _showCreatePlaylistDialog(context),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: GlassTokens.accent),
                    SizedBox(width: 4),
                    Text('New Playlist', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (playlists.isEmpty)
            const GlassCard(
              padding: EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.playlist_play_rounded, size: 40, color: Colors.white24),
                    SizedBox(height: 10),
                    Text('No playlists yet', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Create your first playlist to group favorite tracks for both of you.', style: TextStyle(color: GlassTokens.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: playlists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final pl = playlists[i];
                final songCount = audioProvider.songs.where((s) => pl.songIds.contains(s.id)).length;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(playlist: pl),
                      ),
                    );
                  },
                  child: GlassCard(
                    enableBlur: false,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: pl.coverColor.withOpacity(0.35),
                            border: Border.all(color: pl.coverColor.withOpacity(0.6), width: 1.2),
                          ),
                          child: Center(
                            child: Icon(Icons.music_note_rounded, color: pl.coverColor, size: 24),
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$songCount ${songCount == 1 ? "song" : "songs"}',
                                style: const TextStyle(fontSize: 12, color: GlassTokens.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GlassButton(
                              onTap: () => audioProvider.playPlaylist(pl),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow_rounded, size: 15, color: Colors.white),
                                  SizedBox(width: 2),
                                  Text('Play', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            GlassButton(
                              onTap: () {
                                audioProvider.queuePlaylist(pl);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Queued "${pl.title}" ($songCount songs) to upcoming queue ✦'),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.playlist_add_rounded, size: 15, color: GlassTokens.accent),
                                  SizedBox(width: 2),
                                  Text('Queue', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                            ? const Color(0xFFE07A5F)
                            : (isAutoMix ? const Color(0xFF334155) : const Color(0xFF18281E)),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isAutoMix ? '✦ Auto mix' : p,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xFFE07A5F) : const Color(0xFFE2E8F0),
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
          GlassCard(
            enableBlur: false,
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(24),
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
                          color: Color(0xFFE07A5F),
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
                    activeTrackColor: const Color(0xFFE07A5F),
                    inactiveTrackColor: const Color(0xFF1E2F23),
                    thumbColor: Colors.white,
                    overlayColor: const Color(0xFFE07A5F).withOpacity(0.2),
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

              return GlassCard(
                enableBlur: false,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                borderRadius: BorderRadius.circular(20),
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
                              activeTrackColor: const Color(0xFFE07A5F),
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

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    Color? bgColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor ?? const Color(0xFF111E16),
          border: Border.all(color: const Color(0xFF1E2F23)),
        ),
        child: Center(
          child: Icon(icon, color: iconColor ?? Colors.white, size: 18),
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
                        'Add Music to Sanctuary',
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
                  const SizedBox(height: 18),

                  // 1. PRIMARY OPTION: Search on YouTube Music
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      YoutubeMusicSearchSheet.show(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1610),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD97706).withOpacity(0.4), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFD97706),
                            ),
                            child: const Center(
                              child: Icon(Icons.search_rounded, color: Colors.black, size: 22),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Search Music Catalog',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Stream & cache millions of songs, lo-fi & ballads',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFD97706), size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. SECONDARY OPTION: Pick from Device Storage
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
                                    coverColor: const Color(0xFFE07A5F),
                                    isLocal: true,
                                    addedBy: 'You',
                                  );

                                  if (ctx.mounted) {
                                    final provider = ctx.read<AudioProvider>();
                                    provider.addCustomSong(newSong);
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Added "$cleanTitle" to your sanctuary ✦',
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                        backgroundColor: const Color(0xFF1E212B),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        duration: const Duration(seconds: 2),
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
                        border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.5), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE07A5F),
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
                                  'Import MP3, M4A, WAV, AAC from your phone',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFE07A5F), size: 14),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSortBottomSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    GlassSheet.show(
      context,
      title: 'Sort Library',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSortOption(context, 'Recently Added', 'recent', Icons.history_rounded),
          _buildSortOption(context, 'Title (A-Z)', 'title', Icons.sort_by_alpha_rounded),
          _buildSortOption(context, 'Artist (A-Z)', 'artist', Icons.person_outline_rounded),
          _buildSortOption(context, 'Offline Downloaded Only', 'offline', Icons.offline_pin_outlined),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSortOption(BuildContext ctx, String label, String key, IconData icon) {
    final isSelected = _sortMode == key;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: isSelected ? GlassTokens.accent : const Color(0xFF94A3B8), size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? GlassTokens.accent : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_rounded, color: GlassTokens.accent, size: 20) : null,
      onTap: () {
        setState(() => _sortMode = key);
        Navigator.pop(ctx);
      },
    );
  }
  void _showCreatePlaylistDialog(BuildContext context, {String? initialSongId}) {
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
            color: Color(0xFF13151B),
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
                  hintText: 'Playlist Name (e.g. Calm Nights, Stargazing)',
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
                      final songIds = initialSongId != null && initialSongId.isNotEmpty ? [initialSongId] : <String>[];
                      audio.createPlaylist(title, songIds);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Created playlist "$title" ✦', style: const TextStyle(color: Colors.white)),
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
    HapticFeedback.lightImpact();
    final audio = context.read<AudioProvider>();

    GlassSheet.show(
      context,
      title: song.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_circle_outline_rounded, color: GlassTokens.accent),
            title: const Text('Play Next', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Insert right after current track', style: TextStyle(color: GlassTokens.textSecondary, fontSize: 11)),
            onTap: () {
              audio.playNext(song);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Playing "${song.title}" next ✦'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded, color: GlassTokens.accent),
            title: const Text('Add to Shared Queue', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Append to upcoming songs on both phones', style: TextStyle(color: GlassTokens.textSecondary, fontSize: 11)),
            onTap: () {
              audio.queueSongItem(song);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added "${song.title}" to shared queue ✦'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded, color: Colors.white70),
            title: const Text('Add to Playlist', style: TextStyle(color: Colors.white, fontSize: 14)),
            onTap: () {
              Navigator.pop(context);
              _showAddToPlaylistPicker(context, song);
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_outline_rounded, color: Color(0xFF86EFAC)),
            title: const Text('Listen Together with Partner', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Start sync session with this song', style: TextStyle(color: GlassTokens.textSecondary, fontSize: 11)),
            onTap: () {
              Navigator.pop(context);
              final auth = context.read<AuthProvider>();
              if (auth.space != null) {
                audio.startListenTogether(
                  auth.space!.id,
                  userId: auth.user?.id,
                  nickname: auth.user?.nickname,
                );
              }
              final idx = audio.songs.indexOf(song);
              if (idx != -1) audio.selectSong(idx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ListenTogetherScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF87171)),
            title: const Text('Remove from Library', style: TextStyle(color: Color(0xFFF87171), fontSize: 14)),
            subtitle: const Text('De-clutter your song list', style: TextStyle(color: GlassTokens.textSecondary, fontSize: 11)),
            onTap: () {
              audio.removeSong(song.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed "${song.title}" from library ✦'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  void _showAddToPlaylistPicker(BuildContext context, SongItem song) {
    HapticFeedback.lightImpact();
    final audio = context.read<AudioProvider>();
    final playlists = audio.playlists;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.72,
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Color(0xFF13151B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                          song.title,
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
                  _showCreatePlaylistDialog(context, initialSongId: song.id);
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
                      final contains = pl.songIds.contains(song.id);
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
                          audio.addSongToPlaylist(pl.id, song.id);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added "${song.title}" to ${pl.title} ✦', style: const TextStyle(color: Colors.white)),
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
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFE07A5F)),
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
