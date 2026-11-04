import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/audio_provider.dart';
import '../../../providers/auth_provider.dart';
import '../models/music_models.dart';
import '../widgets/music_interactive_scrubber.dart';
import '../widgets/youtube_music_search_sheet.dart';
import '../theme/glass_tokens.dart';
import '../widgets/glass/glass_ambient_background.dart';
import '../widgets/glass/glass_card.dart';
import '../widgets/glass/glass_button.dart';
import '../widgets/glass/glass_sheet.dart';

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

  void _showQueuePlaylistSheet(BuildContext context, AudioProvider audioProvider) {
    HapticFeedback.lightImpact();
    final playlists = audioProvider.playlists;

    GlassSheet.show(
      context,
      title: 'Queue a Playlist',
      child: playlists.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.playlist_play_rounded, size: 48, color: Colors.white24),
                    SizedBox(height: 12),
                    Text(
                      'No playlists created yet',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Create playlists in Music Sanctuary to queue them here for both of you.',
                      style: TextStyle(color: GlassTokens.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: playlists.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
              itemBuilder: (context, index) {
                final pl = playlists[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: pl.coverColor.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: pl.coverColor.withOpacity(0.6), width: 1.2),
                    ),
                    child: Center(
                      child: Icon(Icons.music_note_rounded, color: pl.coverColor, size: 22),
                    ),
                  ),
                  title: Text(
                    pl.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${pl.songCount} ${pl.songCount == 1 ? "track" : "tracks"}',
                    style: const TextStyle(color: GlassTokens.textSecondary, fontSize: 12),
                  ),
                  trailing: GlassButton(
                    onTap: () {
                      audioProvider.queuePlaylist(pl);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Queued "${pl.title}" (${pl.songCount} songs) to shared queue ✦'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.queue_music_rounded, color: GlassTokens.accent, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Queue All',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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

    // Upcoming queue
    final upcomingList = audioProvider.upcomingSongs;
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
        body: GlassAmbientBackground(
          imageUrl: currentSong.thumbnailUrl,
          fallbackColor: currentSong.coverColor,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 1. Top Glass Navigation Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      GlassButton(
                        onTap: () => Navigator.pop(context),
                        width: 38,
                        height: 38,
                        child: const Center(
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Listen Together',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              'Synchronized audio room',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: GlassTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GlassButton(
                        onTap: () => YoutubeMusicSearchSheet.show(context),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_rounded, size: 15, color: GlassTokens.accent),
                            SizedBox(width: 4),
                            Text(
                              'Find Song',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Main Scrollable View
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 8,
                      bottom: bottomPadding + 36,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Connection Status Glass Card
                        GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildAvatarCircle(myInitial, const Color(0xFF86EFAC), Colors.black87),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isPlaying ? GlassTokens.accent : const Color(0xFF86EFAC),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isPlaying ? 'STREAMING' : 'SYNCED',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _buildAvatarCircle(partnerInitial, const Color(0xFFF97316), Colors.white),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Listening with $partnerName',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isPlaying ? 'In sync · Realtime audio stream ✦' : 'In sync · Ready to play',
                                style: const TextStyle(fontSize: 12, color: GlassTokens.textSecondary),
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
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Code: ',
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
                                      const Icon(Icons.copy_rounded, size: 13, color: GlassTokens.textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Synchronized Now Playing Glass Card
                        GlassCard(
                          padding: const EdgeInsets.all(18),
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
                                            width: 58,
                                            height: 58,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => Container(
                                              width: 58,
                                              height: 58,
                                              color: currentSong.coverColor,
                                              child: const Center(
                                                child: Icon(Icons.music_note_rounded, color: Colors.black87, size: 26),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 58,
                                            height: 58,
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
                                          audioProvider.isSongBuffering
                                              ? (audioProvider.bufferingSongTitle ?? currentSong.title)
                                              : currentSong.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          audioProvider.isSongBuffering
                                              ? 'Buffering audio stream...'
                                              : (isPlaying
                                                  ? '${currentSong.artist} • Playing together ✦'
                                                  : '${currentSong.artist} • Paused on both phones'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isPlaying ? GlassTokens.accent : GlassTokens.textSecondary,
                                            fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Interactive Scrubber
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
                              const SizedBox(height: 12),

                              // Transport controls
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GlassButton(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      audioProvider.prevSong();
                                    },
                                    width: 44,
                                    height: 44,
                                    child: const Center(
                                      child: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 26),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  GlassButton(
                                    onTap: () {
                                      HapticFeedback.mediumImpact();
                                      audioProvider.toggleSongPlay();
                                    },
                                    width: 58,
                                    height: 58,
                                    tintColor: GlassTokens.accent.withOpacity(0.4),
                                    borderColor: GlassTokens.accent.withOpacity(0.7),
                                    child: Center(
                                      child: audioProvider.isSongBuffering
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Icon(
                                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: 32,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  GlassButton(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      audioProvider.nextSong();
                                    },
                                    width: 44,
                                    height: 44,
                                    child: const Center(
                                      child: Icon(Icons.skip_next_rounded, color: Colors.white, size: 26),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Playback controller mode
                        const Text(
                          'Who controls playback',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: GlassTokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white12),
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
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: audioProvider.listenController == 'both'
                                          ? GlassTokens.accent
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
                                              ? Colors.white
                                              : GlassTokens.textSecondary,
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
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: audioProvider.listenController == 'me'
                                          ? GlassTokens.accent
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
                                              ? Colors.white
                                              : GlassTokens.textSecondary,
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

                        // Up Next · Shared Queue Section Header
                        Row(
                          children: [
                            const Text(
                              'Shared Queue',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Text(
                                upcomingList.isEmpty ? '0' : '${upcomingList.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: GlassTokens.accent,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (upcomingList.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF18281E),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: const Text('Clear Queue?', style: TextStyle(color: Colors.white)),
                                      content: const Text(
                                        'This will remove all upcoming songs from the shared queue on both phones.',
                                        style: TextStyle(color: GlassTokens.textSecondary),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            audioProvider.clearUpcomingQueue();
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text('Clear', style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.clear_all_rounded, size: 14, color: Color(0xFFF87171)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Clear',
                                        style: TextStyle(color: Color(0xFFF87171), fontSize: 11.5, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Equal Width Action Buttons (Queue Playlist & Add Song)
                        Row(
                          children: [
                            Expanded(
                              child: GlassButton(
                                onTap: () => _showQueuePlaylistSheet(context, audioProvider),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.playlist_add_rounded, size: 16, color: GlassTokens.accent),
                                    SizedBox(width: 6),
                                    Text(
                                      'Queue Playlist',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GlassButton(
                                onTap: () => YoutubeMusicSearchSheet.show(context),
                                tintColor: GlassTokens.accent.withOpacity(0.2),
                                borderColor: GlassTokens.accent.withOpacity(0.6),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'Add Song',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Upcoming Tracks List or Empty State
                        if (upcomingList.isEmpty)
                          GlassCard(
                            enableBlur: false,
                            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.queue_music_rounded, color: Colors.white24, size: 36),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'No other tracks in queue',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Add tracks or queue an entire playlist for continuous shared listening.',
                                    style: TextStyle(color: GlassTokens.textSecondary, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GlassButton(
                                        onTap: () => _showQueuePlaylistSheet(context, audioProvider),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.playlist_play_rounded, size: 16, color: GlassTokens.accent),
                                            SizedBox(width: 6),
                                            Text('Queue Playlist', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      GlassButton(
                                        onTap: () => YoutubeMusicSearchSheet.show(context),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.search_rounded, size: 16, color: GlassTokens.accent),
                                            SizedBox(width: 6),
                                            Text('Search Songs', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: upcomingList.length,
                            itemBuilder: (context, queueIndex) {
                              final song = upcomingList[queueIndex];
                              return Dismissible(
                                key: Key('queue_${song.id}_$queueIndex'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                                ),
                                onDismissed: (_) {
                                  HapticFeedback.lightImpact();
                                  audioProvider.removeSongFromUpcoming(queueIndex);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Removed "${song.title}" from queue'),
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: GlassCard(
                                    enableBlur: false,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        // Number indicator
                                        SizedBox(
                                          width: 22,
                                          child: Text(
                                            '${queueIndex + 1}',
                                            style: const TextStyle(
                                              color: GlassTokens.textSecondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        // Thumbnail
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
                                        // Track title and artist
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                song.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${song.artist} · ${song.durationFormatted}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: GlassTokens.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Remove track button
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                                          tooltip: 'Remove from queue',
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            audioProvider.removeSongFromUpcoming(queueIndex);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Removed "${song.title}" from queue'),
                                                duration: const Duration(seconds: 1),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],

                        const SizedBox(height: 28),

                        // End session button
                        SizedBox(
                          width: double.infinity,
                          child: GlassButton(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              audioProvider.endListenTogether();
                              Navigator.pop(context);
                            },
                            tintColor: Colors.red.withOpacity(0.12),
                            borderColor: const Color(0xFFF87171).withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: const Center(
                              child: Text(
                                'End session',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF87171),
                                ),
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
        ),
      ),
    );
  }

  Widget _buildAvatarCircle(String label, Color bg, Color textColor) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: Center(
        child: Text(
          label,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
        ),
      ),
    );
  }
}
