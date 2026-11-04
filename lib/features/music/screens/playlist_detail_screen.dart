import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/audio_provider.dart';
import '../models/music_models.dart';
import '../widgets/youtube_music_search_sheet.dart';
import '../theme/glass_tokens.dart';
import '../widgets/glass/glass_ambient_background.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_mini_player.dart';
import '../widgets/glass/glass_sheet.dart';

/// Apple iOS 26 Liquid Glass Playlist Detail View
class PlaylistDetailScreen extends StatelessWidget {
  final PlaylistItem playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final allSongs = audioProvider.songs;
    final playlistSongs = allSongs.where((s) => playlist.songIds.contains(s.id)).toList();

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
          fallbackColor: playlist.coverColor,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 1. Top Header
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          playlist.title,
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
                      const SizedBox(width: 8),
                      GlassButton(
                        onTap: () => _showAddSongToPlaylistDialog(context, audioProvider),
                        width: 40,
                        height: 40,
                        isCircle: true,
                        tintColor: GlassTokens.accent.withOpacity(0.35),
                        borderColor: GlassTokens.accent.withOpacity(0.7),
                        child: const Center(
                          child: Icon(Icons.add_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Main Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        // Playlist Hero Glass Card
                        GlassCard(
                          enableBlur: false,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    colors: [
                                      playlist.coverColor.withOpacity(0.7),
                                      playlist.coverColor.withOpacity(0.3),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: playlist.coverColor.withOpacity(0.35),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(Icons.music_note_rounded, size: 44, color: playlist.coverColor),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                playlist.title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${playlistSongs.length} ${playlistSongs.length == 1 ? "track" : "tracks"} · Playlist',
                                style: const TextStyle(fontSize: 12, color: GlassTokens.textSecondary),
                              ),
                              const SizedBox(height: 18),

                              // Action Buttons: Play All & Queue
                              Row(
                                children: [
                                  Expanded(
                                    child: GlassButton(
                                      onTap: () {
                                        if (playlistSongs.isNotEmpty) {
                                          audioProvider.playPlaylist(playlist);
                                        }
                                      },
                                      tintColor: GlassTokens.accent.withOpacity(0.4),
                                      borderColor: GlassTokens.accent.withOpacity(0.8),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                          SizedBox(width: 6),
                                          Text(
                                            'Play All',
                                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GlassButton(
                                      onTap: () {
                                        if (playlistSongs.isNotEmpty) {
                                          audioProvider.queuePlaylist(playlist);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Queued "${playlist.title}" ✦'),
                                              duration: const Duration(seconds: 2),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.playlist_add_rounded, color: GlassTokens.accent, size: 18),
                                          SizedBox(width: 6),
                                          Text(
                                            'Queue',
                                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section Header: Songs
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tracks',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              'Swipe to remove',
                              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Songs list
                        if (playlistSongs.isEmpty)
                          GlassCard(
                            enableBlur: false,
                            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.music_off_outlined, color: Colors.white24, size: 36),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'No songs in this playlist',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Search and add your favorite tracks to build this playlist together.',
                                    style: TextStyle(color: GlassTokens.textSecondary, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  GlassButton(
                                    onTap: () => _showAddSongToPlaylistDialog(context, audioProvider),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_rounded, size: 16, color: GlassTokens.accent),
                                        SizedBox(width: 6),
                                        Text('Add Songs', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: playlistSongs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final song = playlistSongs[i];
                              final isCurrent = audioProvider.currentSong.id == song.id;

                              return Dismissible(
                                key: Key('${playlist.id}_${song.id}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF87171),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                                ),
                                onDismissed: (_) {
                                  audioProvider.removeSongFromPlaylist(playlist.id, song.id);
                                },
                                child: GestureDetector(
                                  onTap: () {
                                    final originalIdx = allSongs.indexWhere((s) => s.id == song.id);
                                    if (originalIdx != -1) audioProvider.selectSong(originalIdx);
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
                                                    child: const Icon(Icons.music_note, color: Colors.black87, size: 20),
                                                  ),
                                                )
                                              : Container(
                                                  width: 44,
                                                  height: 44,
                                                  color: song.coverColor,
                                                  child: const Icon(Icons.music_note, color: Colors.black87, size: 20),
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
                                              Text(
                                                '${song.artist} · ${song.durationFormatted}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11.5, color: GlassTokens.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white38, size: 20),
                                          onPressed: () {
                                            audioProvider.removeSongFromPlaylist(playlist.id, song.id);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 28),

                        // Delete playlist button
                        GlassButton(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            audioProvider.deletePlaylist(playlist.id);
                            Navigator.pop(context);
                          },
                          tintColor: Colors.red.withOpacity(0.12),
                          borderColor: const Color(0xFFF87171).withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: const Center(
                            child: Text(
                              'Delete Playlist',
                              style: TextStyle(
                                color: Color(0xFFF87171),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddSongToPlaylistDialog(BuildContext context, AudioProvider provider) {
    final availableSongs = provider.songs.where((s) => !playlist.songIds.contains(s.id)).toList();

    GlassSheet.show(
      context,
      title: 'Add to ${playlist.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & Discover button
          GlassButton(
            onTap: () {
              Navigator.pop(context);
              YoutubeMusicSearchSheet.show(context);
            },
            tintColor: GlassTokens.accent.withOpacity(0.25),
            borderColor: GlassTokens.accent.withOpacity(0.6),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_rounded, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Search & Discover Songs',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'FROM YOUR LIBRARY',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: GlassTokens.textSecondary),
          ),
          const SizedBox(height: 8),
          availableSongs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'All library songs are already in this playlist ✦',
                      style: TextStyle(color: GlassTokens.textSecondary, fontSize: 13),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: availableSongs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final song = availableSongs[i];
                    return GlassCard(
                      enableBlur: false,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: song.thumbnailUrl != null && song.thumbnailUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: song.thumbnailUrl!,
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 38,
                                      height: 38,
                                      color: song.coverColor,
                                      child: const Icon(Icons.music_note, color: Colors.black87, size: 18),
                                    ),
                                  )
                                : Container(
                                    width: 38,
                                    height: 38,
                                    color: song.coverColor,
                                    child: const Icon(Icons.music_note, color: Colors.black87, size: 18),
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
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: GlassTokens.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: GlassTokens.accent, size: 22),
                            onPressed: () {
                              provider.addSongToPlaylist(playlist.id, song.id);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added "${song.title}" to ${playlist.title} ✦'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
