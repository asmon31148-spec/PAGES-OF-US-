import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/audio_provider.dart';
import '../../../providers/auth_provider.dart';
import '../models/music_models.dart';
import '../widgets/music_interactive_scrubber.dart';
import '../widgets/youtube_music_search_sheet.dart';

class ListenTogetherScreen extends StatefulWidget {
  const ListenTogetherScreen({super.key});

  @override
  State<ListenTogetherScreen> createState() => _ListenTogetherScreenState();
}

class _ListenTogetherScreenState extends State<ListenTogetherScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final space = auth.space;
    if (space != null) {
      context.read<AudioProvider>().startListenTogether(
            space.id,
            userId: auth.user?.id,
            nickname: auth.user?.nickname,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final partner = authProvider.partner;
    final space = authProvider.space;

    final myName = (user?.nickname.isNotEmpty ?? false) ? user!.nickname : 'You';
    final partnerName = (partner?.nickname.isNotEmpty ?? false) ? partner!.nickname : 'Partner';
    final myInitial = myName.isNotEmpty ? myName[0].toUpperCase() : '♥';
    final partnerInitial = partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '♥';

    final pairCode = (space?.pairCode != null && space!.pairCode.isNotEmpty) ? space.pairCode : 'SANCTUARY';

    final currentSong = audioProvider.currentSong;
    final isPlaying = audioProvider.isSongPlaying;
    final dur = audioProvider.songDuration;

    // Real upcoming queue from sanctuary songs
    final songs = audioProvider.songs;
    final currentIndex = audioProvider.currentSongIndex;
    final queueSongs = <SongItem>[];
    if (songs.isNotEmpty) {
      for (int i = 1; i < songs.length; i++) {
        final idx = (currentIndex + i) % songs.length;
        queueSongs.add(songs[idx]);
      }
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
            // Ambient Warm Glow top-right
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
              bottom: false,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF111E16),
                              border: Border.all(color: const Color(0xFF1E2F23)),
                            ),
                            child: const Center(
                              child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'Listen together',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => YoutubeMusicSearchSheet.show(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF18281E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF243B2C)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_rounded, size: 14, color: Color(0xFFA3E635)),
                                SizedBox(width: 4),
                                Text(
                                  'Find Song',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFA3E635),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 10,
                        bottom: bottomPadding + 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Connection Status Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111E16),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFF18281E)),
                            ),
                            child: Column(
                              children: [
                                // Avatar circles with synced link
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildAvatarCircle(myInitial, const Color(0xFF86EFAC), Colors.black87),
                                    const SizedBox(width: 8),
                                    Text(
                                      '- - - - - - - -',
                                      style: TextStyle(
                                        color: const Color(0xFF86EFAC).withOpacity(0.8),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildAvatarCircle(partnerInitial, const Color(0xFFF97316), Colors.white),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Listening with $partnerName',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFFA3E635),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isPlaying ? 'In sync · Realtime audio stream ✦' : 'In sync · Ready to play',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Code copy pill
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Clipboard.setData(ClipboardData(text: pairCode));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Sync code copied to clipboard ✦'),
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0B140F),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFF1E2F23)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Code  ',
                                          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
                                        ),
                                        Text(
                                          pairCode,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF94A3B8)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. Synchronized Now Playing Card (Real dynamic track data)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111E16),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFF18281E)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                                  child: Icon(Icons.music_note_rounded, color: Colors.black87, size: 24),
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
                                                child: Icon(Icons.music_note_rounded, color: Colors.black87, size: 24),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            audioProvider.isSongBuffering
                                                ? (audioProvider.bufferingSongTitle ?? currentSong.title)
                                                : currentSong.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            audioProvider.isSongBuffering
                                                ? 'Buffering audio...'
                                                : (isPlaying
                                                    ? '${currentSong.artist} • Playing together ✦'
                                                    : '${currentSong.artist} • Paused on both phones'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isPlaying ? const Color(0xFFA3E635) : const Color(0xFF94A3B8),
                                              fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Smooth Interactive Music Scrubber
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

                                // Transport controls
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 26),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        audioProvider.prevSong();
                                      },
                                    ),
                                    const SizedBox(width: 18),
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        audioProvider.toggleSongPlay();
                                      },
                                      child: Container(
                                        width: 52,
                                        height: 52,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFFA3E635),
                                        ),
                                        child: Center(
                                          child: audioProvider.isSongBuffering
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    color: Colors.black,
                                                  ),
                                                )
                                              : Icon(
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
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        audioProvider.nextSong();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 3. "Who controls playback"
                          const Text(
                            'Who controls playback',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111E16),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFF18281E)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      audioProvider.setListenController('both');
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: audioProvider.listenController == 'both'
                                            ? const Color(0xFFA3E635)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Both of us',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: audioProvider.listenController == 'both'
                                                ? Colors.black
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      audioProvider.setListenController('me');
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: audioProvider.listenController == 'me'
                                            ? const Color(0xFFA3E635)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Only me',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: audioProvider.listenController == 'me'
                                                ? Colors.black
                                                : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 4. "Up next · shared" (Real dynamic queue)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Up next · shared',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (queueSongs.isNotEmpty)
                                Text(
                                  '${queueSongs.length} upcoming',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (queueSongs.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111E16),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF18281E)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.queue_music_rounded, color: Colors.white24, size: 32),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No other songs in queue',
                                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Search songs from YouTube Music to build your shared queue',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    onPressed: () => YoutubeMusicSearchSheet.show(context),
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: const Text('Add Songs'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFA3E635),
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...queueSongs.map((song) {
                              final originalIndex = songs.indexOf(song);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111E16),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF18281E)),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: song.thumbnailUrl != null && song.thumbnailUrl!.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: song.thumbnailUrl!,
                                            width: 42,
                                            height: 42,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => Container(
                                              width: 42,
                                              height: 42,
                                              color: song.coverColor,
                                              child: const Icon(Icons.music_note, color: Colors.black87, size: 20),
                                            ),
                                          )
                                        : Container(
                                            width: 42,
                                            height: 42,
                                            color: song.coverColor,
                                            child: const Icon(Icons.music_note, color: Colors.black87, size: 20),
                                          ),
                                  ),
                                  title: Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${song.artist} · ${song.durationFormatted}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.play_circle_outline_rounded, color: Color(0xFFA3E635), size: 26),
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      audioProvider.selectSong(originalIndex);
                                    },
                                  ),
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    audioProvider.selectSong(originalIndex);
                                  },
                                ),
                              );
                            }),

                          const SizedBox(height: 28),

                          // End session button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                audioProvider.endListenTogether();
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: Color(0xFFF87171)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: const Text(
                                'End session',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF87171),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
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

  Widget _buildAvatarCircle(String label, Color bg, Color textColor) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: Center(
        child: Text(
          label,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
      ),
    );
  }
}
