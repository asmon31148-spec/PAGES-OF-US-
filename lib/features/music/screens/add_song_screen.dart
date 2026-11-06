import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/audio_provider.dart';
import '../models/music_models.dart';
import '../theme/glass_tokens.dart';
import '../widgets/glass/glass_ambient_background.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/youtube_music_search_sheet.dart';

/// Full-screen Add Song to Playlist screen matching the Music Sanctuary design language.
/// Fully scrollable history list, live filtering, and YouTube music search.
class AddSongScreen extends StatefulWidget {
  final PlaylistItem playlist;

  const AddSongScreen({
    super.key,
    required this.playlist,
  });

  @override
  State<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends State<AddSongScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final currentSong = audioProvider.currentSong;

    // Filter out songs that are already in the playlist
    final availableSongs = audioProvider.songs.where((s) {
      final isAlreadyIn = widget.playlist.songIds.contains(s.id) ||
          (s.youtubeId != null && widget.playlist.songIds.contains(s.youtubeId));
      if (isAlreadyIn) return false;

      if (_filterQuery.isEmpty) return true;
      final q = _filterQuery.toLowerCase();
      return s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Dynamic Music Sanctuary Ambient Background
          GlassAmbientBackground(
            activeColor: currentSong?.coverColor ?? GlassTokens.accent,
            isDark: true,
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      GlassButton(
                        onTap: () => Navigator.pop(context),
                        width: 40,
                        height: 40,
                        isCircle: true,
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add to ${widget.playlist.title}',
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
                              'Tap + to add songs to your playlist ✦',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withOpacity(0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // YouTube Music Discover Button
                      GlassButton(
                        onTap: () => YoutubeMusicSearchSheet.show(context),
                        width: 40,
                        height: 40,
                        isCircle: true,
                        tintColor: GlassTokens.accent.withOpacity(0.25),
                        borderColor: GlassTokens.accent.withOpacity(0.6),
                        child: const Icon(Icons.travel_explore_rounded, size: 20, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Live Filter Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _filterQuery = val.trim()),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Filter your listened songs by title or artist...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.40), fontSize: 12.5),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.white60),
                        suffixIcon: _filterQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white60),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _filterQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),

                // Discover Online Banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GlassButton(
                    onTap: () => YoutubeMusicSearchSheet.show(context),
                    tintColor: GlassTokens.accent.withOpacity(0.20),
                    borderColor: GlassTokens.accent.withOpacity(0.50),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: GlassTokens.accent.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Search & Stream Online Songs',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Find any track on YouTube Music & add directly',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: GlassTokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.white70),
                      ],
                    ),
                  ),
                ),

                // Header for Listened History
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'LISTENED HISTORY & LIBRARY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: GlassTokens.textSecondary,
                        ),
                      ),
                      Text(
                        '${availableSongs.length} songs',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Available Songs List
                Expanded(
                  child: availableSongs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.music_note_rounded,
                                  size: 48,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _filterQuery.isNotEmpty
                                      ? 'No matching songs found'
                                      : 'All library songs are already in this playlist ✦',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: GlassTokens.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                          itemCount: availableSongs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final song = availableSongs[index];

                            return GlassCard(
                              enableBlur: true,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          song.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: GlassTokens.textSecondary,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_rounded,
                                      color: GlassTokens.accent,
                                      size: 26,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      audioProvider.addSongToPlaylist(widget.playlist.id, song.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Added "${song.title}" to ${widget.playlist.title} ✦'),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
