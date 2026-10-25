import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/audio_provider.dart';
import '../models/music_models.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final PlaylistItem playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final allSongs = audioProvider.songs;
    final playlistSongs = allSongs.where((s) => playlist.songIds.contains(s.id)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF07100B),
      body: Stack(
        children: [
          // Ambient Warm/Amber Radial Glow top right
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
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
              children: [
                // Top Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCircleIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      _buildCircleIconButton(
                        icon: Icons.more_horiz_rounded,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        // Large Hero Artwork Squircle
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2DD4BF), Color(0xFF0F766E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2DD4BF).withOpacity(0.25),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.music_note_rounded,
                              size: 56,
                              color: Color(0xFF07100B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Title & Subtitle
                        Text(
                          playlist.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${playlistSongs.length} songs · ${playlistSongs.length * 4} min',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons: Play (Lime capsule), Shuffle, Add
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (playlistSongs.isNotEmpty) {
                                    final idx = allSongs.indexWhere(
                                      (s) => s.id == playlistSongs.first.id,
                                    );
                                    if (idx != -1) audioProvider.selectSong(idx);
                                  }
                                },
                                icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                                label: const Text(
                                  'Play',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFA3E635),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildCircleIconButton(
                              icon: Icons.shuffle_rounded,
                              onTap: () => audioProvider.toggleShuffle(),
                            ),
                            const SizedBox(width: 8),
                            _buildCircleIconButton(
                              icon: Icons.add_rounded,
                              onTap: () => _showAddSongToPlaylistDialog(context, audioProvider),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Songs Section Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Songs',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Swipe left to remove',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Song list with dismissible swipe to remove
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: playlistSongs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final song = playlistSongs[i];
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
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                                    Text('Remove', style: TextStyle(fontSize: 10, color: Colors.white)),
                                  ],
                                ),
                              ),
                              onDismissed: (_) {
                                audioProvider.removeSongFromPlaylist(playlist.id, song.id);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111E16),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF18281E)),
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
                                      child: const Center(
                                        child: Icon(Icons.music_note_rounded, color: Colors.black87, size: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            song.title,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
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
                                    const Icon(Icons.more_horiz_rounded, color: Color(0xFF64748B), size: 18),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),

                        // Delete playlist button
                        TextButton(
                          onPressed: () {
                            audioProvider.deletePlaylist(playlist.id);
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Delete playlist',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF87171),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  void _showAddSongToPlaylistDialog(BuildContext context, AudioProvider provider) {
    final availableSongs = provider.songs.where((s) => !playlist.songIds.contains(s.id)).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
                  const Text(
                    'Add to this Playlist',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (availableSongs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'All sanctuary songs are already in this playlist ✦',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: availableSongs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final song = availableSongs[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      tileColor: const Color(0xFF07100B),
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: song.coverColor,
                        ),
                        child: const Center(
                          child: Icon(Icons.music_note_rounded, color: Colors.black87, size: 18),
                        ),
                      ),
                      title: Text(song.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(song.artist, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      trailing: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFA3E635), size: 22),
                      onTap: () {
                        provider.addSongToPlaylist(playlist.id, song.id);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added "${song.title}" to ${playlist.title} ✦'),
                            backgroundColor: const Color(0xFF15261C),
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
}
