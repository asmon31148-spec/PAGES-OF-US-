import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/liquid_glass/liquid_glass_background.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../models/watch_room_model.dart';
import '../services/watch_together_service.dart';
import '../widgets/watch_movie_picker_sheet.dart';
import 'watch_player_screen.dart';

class WatchWaitingScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const WatchWaitingScreen({
    super.key,
    required this.roomCode,
    required this.isHost,
  });

  @override
  State<WatchWaitingScreen> createState() => _WatchWaitingScreenState();
}

class _WatchWaitingScreenState extends State<WatchWaitingScreen> {
  StreamSubscription<WatchRoom?>? _roomSub;
  WatchRoom? _room;

  String? _pickedFilePath;
  String? _pickedFileName;
  int _pickedDurationMs = 0;
  bool _hasNavigatedToPlayer = false;

  @override
  void initState() {
    super.initState();
    _subscribeToRoom();
  }

  void _subscribeToRoom() {
    _roomSub = WatchTogetherService.instance.streamRoom(widget.roomCode).listen((room) {
      if (!mounted) return;

      if (room == null) {
        // Room was closed / deleted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room closed by host.'),
            backgroundColor: AppColors.terra,
          ),
        );
        Navigator.pop(context);
        return;
      }

      setState(() {
        _room = room;
      });

      // Check automatic start condition: both members ready and movie chosen
      _checkBothReady(room);
    });
  }

  void _checkBothReady(WatchRoom room) {
    if (_hasNavigatedToPlayer) return;

    final myUid = context.read<AuthProvider>().user?.id;
    if (myUid == null) return;

    final myMember = room.members[myUid];
    final partnerUid = room.members.keys.firstWhere(
      (uid) => uid != myUid,
      orElse: () => '',
    );
    final partnerMember = partnerUid.isNotEmpty ? room.members[partnerUid] : null;

    final videoSource = room.videoSource;
    final isOnline = videoSource != null && videoSource.isOnline;

    final bothReady = (myMember?.ready == true) &&
        (partnerMember?.ready == true) &&
        (isOnline || (_pickedFilePath != null && _pickedFilePath!.isNotEmpty));

    if (bothReady) {
      _hasNavigatedToPlayer = true;

      // Host initializes playback at position 0 paused
      if (widget.isHost) {
        WatchTogetherService.instance.updatePlayback(
          roomCode: widget.roomCode,
          uid: myUid,
          isPlaying: false,
          positionMs: 0,
          speed: 1.0,
        );
      }

      // Smooth transition to Screen 3 (Player Screen)
      HapticFeedback.mediumImpact();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WatchPlayerScreen(
            roomCode: widget.roomCode,
            isHost: widget.isHost,
            localVideoPath: _pickedFilePath,
            networkVideoUrl: videoSource?.webUrl,
            youtubeId: videoSource?.youtubeId,
            videoType: videoSource?.type ?? 'local',
            movieTitle: videoSource?.title.isNotEmpty == true
                ? videoSource!.title
                : (_pickedFileName ?? 'Movie'),
          ),
        ),
      );
    }
  }

  void _openMoviePicker() {
    final isDark = context.read<ThemeProvider>().isDark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WatchMoviePickerSheet(
        isDark: isDark,
        onVideoSelected: (source, localPath) async {
          final myUid = context.read<AuthProvider>().user?.id;
          if (myUid == null) return;

          if (source.isLocal && localPath != null) {
            setState(() {
              _pickedFilePath = localPath;
              _pickedFileName = source.title;
              _pickedDurationMs = source.durationMs;
            });
            await WatchTogetherService.instance.updateMemberFile(
              roomCode: widget.roomCode,
              uid: myUid,
              fileName: source.title,
              durationMs: source.durationMs,
            );
          } else {
            // Online stream (YouTube or Web Link)
            setState(() {
              _pickedFilePath = null;
              _pickedFileName = source.title;
              _pickedDurationMs = source.durationMs;
            });
            await WatchTogetherService.instance.updateMemberFile(
              roomCode: widget.roomCode,
              uid: myUid,
              fileName: source.title,
              durationMs: source.durationMs,
            );
          }

          // Update room's shared video source in RTDB
          await WatchTogetherService.instance.updateRoomVideoSource(
            roomCode: widget.roomCode,
            videoSource: source,
          );
        },
      ),
    );
  }

  Future<void> _toggleReady() async {
    final myUid = context.read<AuthProvider>().user?.id;
    if (myUid == null) return;

    final videoSource = _room?.videoSource;
    final isOnline = videoSource != null && videoSource.isOnline;
    if (!isOnline && (_pickedFilePath == null || _pickedFilePath!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a movie or video first!'),
          backgroundColor: AppColors.terra,
        ),
      );
      return;
    }

    final currentReady = _room?.members[myUid]?.ready ?? false;
    final newReady = !currentReady;

    HapticFeedback.lightImpact();
    await WatchTogetherService.instance.updateMemberReady(
      roomCode: widget.roomCode,
      uid: myUid,
      ready: newReady,
    );
  }

  Future<void> _leaveRoom() async {
    HapticFeedback.selectionClick();
    final myUid = context.read<AuthProvider>().user?.id;
    if (widget.isHost) {
      await WatchTogetherService.instance.deleteRoom(widget.roomCode);
    } else if (myUid != null) {
      await WatchTogetherService.instance.leaveRoom(
        roomCode: widget.roomCode,
        uid: myUid,
        isHost: false,
      );
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard! Share it with your partner 💌'),
        backgroundColor: AppColors.terra,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return 'Stream';
    final duration = Duration(milliseconds: ms);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final soft = isDark ? AppColors.darkSoft : AppColors.lightSoft;

    final myUid = context.watch<AuthProvider>().user?.id;
    final myMember = myUid != null ? _room?.members[myUid] : null;

    final partnerUid = _room?.members.keys.firstWhere(
      (uid) => uid != myUid,
      orElse: () => '',
    );
    final partnerMember = partnerUid != null && partnerUid.isNotEmpty
        ? _room?.members[partnerUid]
        : null;

    final isPartnerPresent = partnerMember != null;
    final isPartnerOnline = partnerMember?.online == true;
    final partnerPicked = (partnerMember?.durationMs ?? 0) > 0;
    final myPicked = _pickedDurationMs > 0;

    final videoSource = _room?.videoSource;
    final isOnlineMovie = videoSource != null && videoSource.isOnline;
    final hasChosenMovie = videoSource != null && videoSource.title.isNotEmpty;

    // File match check
    bool? isSameMovie;
    if (isOnlineMovie) {
      isSameMovie = true; // Perfect match guaranteed for YouTube and Web streams!
    } else if (myPicked && partnerPicked) {
      final diff = (_pickedDurationMs - partnerMember!.durationMs).abs();
      isSameMovie = diff <= 3000;
    }

    final isMyReady = myMember?.ready == true;
    final isPartnerReady = partnerMember?.ready == true;
    final canReady = isOnlineMovie || myPicked;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LiquidGlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _leaveRoom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: ink),
                            const SizedBox(width: 4),
                            Text(
                              'Leave Room',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.terra.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.isHost ? 'Host 👑' : 'Guest 🍿',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.terra,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: Column(
                    children: [
                      // Room Code Display Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'ROOM CODE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: soft,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.roomCode,
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4.0,
                                    color: AppColors.terra,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.terra),
                                  onPressed: _copyRoomCode,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Share this code with your partner to connect',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: soft),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Partner Connection Status Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isPartnerPresent
                                    ? (isPartnerOnline ? const Color(0xFF10B981) : Colors.grey)
                                    : Colors.orangeAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                !isPartnerPresent
                                    ? 'Waiting for your partner...'
                                    : '${partnerMember.name} is ${isPartnerOnline ? "online" : "offline"}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                            ),
                            if (isPartnerPresent && (isOnlineMovie || partnerPicked))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isOnlineMovie ? 'Stream synced ✓' : 'File picked ✓',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Cinema Movie Card (YouTube, Web Link, or Local)
                      _buildMovieSelectionCard(
                        isDark: isDark,
                        surface: surface,
                        border: border,
                        ink: ink,
                        soft: soft,
                        videoSource: videoSource,
                        hasChosenMovie: hasChosenMovie,
                      ),

                      const SizedBox(height: 16),

                      // Movie Sync Indicator
                      if (isSameMovie != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSameMovie
                                ? const Color(0xFF10B981).withOpacity(0.12)
                                : const Color(0xFFF59E0B).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSameMovie
                                  ? const Color(0xFF10B981).withOpacity(0.4)
                                  : const Color(0xFFF59E0B).withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSameMovie ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                size: 18,
                                color: isSameMovie ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isOnlineMovie
                                      ? 'Direct Cloud Stream Ready • Zero download needed ✓'
                                      : (isSameMovie
                                          ? 'Same movie duration matches ✓'
                                          : 'These files may be different versions. Sync may be off.'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isSameMovie
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Ready Status Cards (Two columns: Me & Partner)
                      Row(
                        children: [
                          // Me
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMyReady
                                    ? const Color(0xFF10B981).withOpacity(0.12)
                                    : surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isMyReady ? const Color(0xFF10B981) : border,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'You',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: soft,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isMyReady ? 'READY ✓' : 'NOT READY',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isMyReady ? const Color(0xFF10B981) : soft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Partner
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isPartnerReady
                                    ? const Color(0xFF10B981).withOpacity(0.12)
                                    : surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPartnerReady ? const Color(0xFF10B981) : border,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    partnerMember?.name ?? 'Partner',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: soft,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isPartnerReady ? 'READY ✓' : 'NOT READY',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isPartnerReady ? const Color(0xFF10B981) : soft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 26),

                      // Button: I'm Ready
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: !canReady ? null : _toggleReady,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMyReady ? const Color(0xFF10B981) : AppColors.terra,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            disabledBackgroundColor: Colors.grey.withOpacity(0.25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            !canReady
                                ? (widget.isHost ? 'Pick a movie to begin' : 'Waiting for host to pick movie...')
                                : (isMyReady ? 'Waiting for partner... (tap to unready)' : "I'm Ready 🍿"),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovieSelectionCard({
    required bool isDark,
    required Color surface,
    required Color border,
    required Color ink,
    required Color soft,
    required WatchVideoSource? videoSource,
    required bool hasChosenMovie,
  }) {
    if (!hasChosenMovie) {
      // No movie chosen yet
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.terra.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.movie_filter_rounded, size: 36, color: AppColors.terra),
            ),
            const SizedBox(height: 12),
            Text(
              'No Movie Chosen Yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ink),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isHost
                  ? 'Choose YouTube, Web Link, or a Local File for you two.'
                  : 'Your partner is choosing the cinema movie...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: soft),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _openMoviePicker,
                icon: const Icon(Icons.search_rounded, size: 18, color: Colors.white),
                label: Text(
                  widget.isHost ? 'Choose Movie to Watch 🎬' : 'Suggest a Movie 🍿',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terra,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // A movie has been chosen for the room
    final isYouTube = videoSource!.isYouTube;
    final isWebUrl = videoSource.isWebUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cinema Movie',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ink),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isYouTube
                      ? const Color(0xFFFF0000).withOpacity(0.12)
                      : (isWebUrl ? Colors.blueAccent.withOpacity(0.12) : AppColors.terra.withOpacity(0.12)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isYouTube ? 'YouTube 🔴' : (isWebUrl ? 'Web Stream 🌐' : 'Local File 📁'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isYouTube ? const Color(0xFFFF0000) : (isWebUrl ? Colors.blueAccent : AppColors.terra),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Thumbnail / Poster Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isYouTube && videoSource.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: videoSource.thumbnailUrl!,
                        width: 100,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(width: 100, height: 60, color: Colors.black26),
                      )
                    : Container(
                        width: 70,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.terra.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isWebUrl ? Icons.link_rounded : Icons.movie_rounded,
                          size: 28,
                          color: AppColors.terra,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      videoSource.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      videoSource.durationMs > 0
                          ? _formatDuration(videoSource.durationMs)
                          : (isYouTube || isWebUrl ? 'Zero download needed' : 'Offline'),
                      style: TextStyle(fontSize: 11, color: soft),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Change button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _openMoviePicker,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.terra),
              label: const Text(
                'Change Movie / Video',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.terra),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.terra, width: 1.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
