import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/audio_provider.dart';
import '../../../providers/auth_provider.dart';
import '../widgets/music_interactive_scrubber.dart';

class ListenTogetherScreen extends StatefulWidget {
  const ListenTogetherScreen({super.key});

  @override
  State<ListenTogetherScreen> createState() => _ListenTogetherScreenState();
}

class _ListenTogetherScreenState extends State<ListenTogetherScreen> {
  @override
  void initState() {
    super.initState();
    final space = context.read<AuthProvider>().space;
    if (space != null) {
      context.read<AudioProvider>().startListenTogether(space.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final partner = authProvider.partner;
    final space = authProvider.space;

    final myInitial = (user?.nickname.isNotEmpty ?? false) ? user!.nickname[0].toUpperCase() : 'A';
    final partnerInitial = (partner?.nickname.isNotEmpty ?? false) ? partner!.nickname[0].toUpperCase() : 'S';
    final partnerName = partner?.nickname ?? 'Partner';
    final pairCode = space?.pairCode ?? 'FOREST-482';

    final currentSong = audioProvider.currentSong;
    final isPlaying = audioProvider.isSongPlaying;
    final pos = audioProvider.songPosition;
    final dur = audioProvider.songDuration;
    final progress = dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;

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
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
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
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),

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
                              // Avatar circles with dashed line
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
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.circle, color: Color(0xFF86EFAC), size: 8),
                                  SizedBox(width: 6),
                                  Text(
                                    'In sync · 0.1s delay',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Code copy pill
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: pairCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sync code copied to clipboard ✦'),
                                      duration: Duration(seconds: 2),
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

                        // 2. Synchronized Now Playing Card
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
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: currentSong.coverColor,
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.music_note_rounded, color: Colors.black87, size: 24),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Slow Morning',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Playing on both phones',
                                          style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Smooth Interactive Music Scrubber (Finger dragging to any sec)
                              MusicInteractiveScrubber(
                                position: pos,
                                duration: dur,
                                onSeek: (target) => audioProvider.seekSong(target),
                              ),
                              const SizedBox(height: 10),

                              // Transport controls
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
                                  onTap: () => audioProvider.setListenController('both'),
                                  child: Container(
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
                                  onTap: () => audioProvider.setListenController('me'),
                                  child: Container(
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

                        // 4. "Up next · shared"
                        const Text(
                          'Up next · shared',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSharedQueueTile(
                          title: 'Rainy Window',
                          subtitle: 'Added by $partnerName',
                          color: const Color(0xFF2DD4BF),
                        ),
                        const SizedBox(height: 8),
                        _buildSharedQueueTile(
                          title: 'Night Garden',
                          subtitle: 'Added by you',
                          color: const Color(0xFFF97316),
                        ),
                        const SizedBox(height: 32),

                        // End session button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
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

  Widget _buildSharedQueueTile({required String title, required String subtitle, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              color: color,
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
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
