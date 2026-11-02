import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../models/watch_room_model.dart';
import '../services/watch_together_service.dart';
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
  bool _isPickingFile = false;
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

      // Check automatic start condition: both members ready and files picked
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

    final bothReady = (myMember?.ready == true) &&
        (partnerMember?.ready == true) &&
        _pickedFilePath != null &&
        _pickedFilePath!.isNotEmpty;

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
            localVideoPath: _pickedFilePath!,
            movieTitle: _pickedFileName ?? 'Movie',
          ),
        ),
      );
    }
  }

  Future<void> _pickMovieFile() async {
    setState(() {
      _isPickingFile = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;

        // Directly read duration from local file with temporary VideoPlayerController
        final controller = VideoPlayerController.file(File(path));
        await controller.initialize();
        final duration = controller.value.duration;
        final durationMs = duration.inMilliseconds;
        await controller.dispose();

        setState(() {
          _pickedFilePath = path;
          _pickedFileName = name;
          _pickedDurationMs = durationMs;
        });

        // Update Firebase with picked file metadata
        final myUid = context.read<AuthProvider>().user?.id;
        if (myUid != null) {
          await WatchTogetherService.instance.updateMemberFile(
            roomCode: widget.roomCode,
            uid: myUid,
            fileName: name,
            durationMs: durationMs,
          );
        }
      }
    } catch (e) {
      debugPrint('File pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open video file: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
        });
      }
    }
  }

  Future<void> _toggleReady() async {
    final myUid = context.read<AuthProvider>().user?.id;
    if (myUid == null || _pickedFilePath == null) return;

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
    final myUid = context.read<AuthProvider>().user?.id;
    if (myUid != null) {
      await WatchTogetherService.instance.leaveRoom(
        roomCode: widget.roomCode,
        uid: myUid,
        isHost: widget.isHost,
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
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
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

    // File match check: duration difference <= 3000ms
    bool? isSameMovie;
    if (myPicked && partnerPicked) {
      final diff = (_pickedDurationMs - partnerMember!.durationMs).abs();
      isSameMovie = diff <= 3000;
    }

    final isMyReady = myMember?.ready == true;
    final isPartnerReady = partnerMember?.ready == true;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
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
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 6,
                                  color: AppColors.terra,
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: _copyRoomCode,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.terra.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                    color: AppColors.terra,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Share this code with your partner to join',
                            style: TextStyle(fontSize: 11.5, color: soft),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Partner Status Line
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
                          if (isPartnerPresent && partnerPicked)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'File picked ✓',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Pick Movie File Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
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
                                'Your Local Movie File',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: ink,
                                ),
                              ),
                              if (myPicked)
                                Text(
                                  _formatDuration(_pickedDurationMs),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.terra,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (_pickedFileName != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black.withOpacity(0.25) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.video_file_rounded,
                                    size: 24,
                                    color: AppColors.terra,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _pickedFileName!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Pick Button
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: _isPickingFile ? null : _pickMovieFile,
                              icon: _isPickingFile
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(
                                      myPicked ? Icons.change_circle_rounded : Icons.folder_open_rounded,
                                      size: 18,
                                      color: AppColors.terra,
                                    ),
                              label: Text(
                                myPicked ? 'Change Movie File' : 'Pick Movie File',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.terra,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.terra, width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // File Match Indicator
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
                                isSameMovie
                                    ? 'Same movie duration matches ✓'
                                    : 'These files may be different versions. Sync may be off.',
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
                      const SizedBox(height: 20),
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

                    const SizedBox(height: 30),

                    // Button: I'm Ready
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: !myPicked ? null : _toggleReady,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMyReady ? const Color(0xFF10B981) : AppColors.terra,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          !myPicked
                              ? 'Pick a movie file first'
                              : (isMyReady ? 'Waiting for partner... (tap to unready)' : "I'm Ready 🍿"),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
