import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../models/watch_room_model.dart';
import '../services/watch_together_service.dart';
import '../widgets/watch_controls_overlay.dart';
import '../widgets/watch_chat_view.dart';
import '../widgets/watch_floating_reactions.dart';
import '../widgets/watch_call_overlay.dart';
import '../services/watch_call_service.dart';
import 'watch_waiting_screen.dart';

class WatchPlayerScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;
  final String localVideoPath;
  final String movieTitle;

  const WatchPlayerScreen({
    super.key,
    required this.roomCode,
    required this.isHost,
    required this.localVideoPath,
    required this.movieTitle,
  });

  @override
  State<WatchPlayerScreen> createState() => _WatchPlayerScreenState();
}

class _WatchPlayerScreenState extends State<WatchPlayerScreen> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _initError;

  // Stream Subscriptions
  StreamSubscription<WatchPlayback>? _playbackSub;
  StreamSubscription<WatchRoom?>? _roomSub;
  StreamSubscription<List<WatchMessage>>? _chatSub;
  StreamSubscription<int>? _messageCountSub;

  // Sync state
  WatchPlayback? _lastRemotePlayback;
  DateTime _ignoreRemoteUntil = DateTime.now();
  Timer? _driftCheckTimer;
  SyncStatus _syncStatus = SyncStatus.inSync;

  // Chat & UI state
  List<WatchMessage> _chatMessages = [];
  int _totalMessageCount = 0;
  bool _isLandscape = false;
  bool _isChatVisible = true;
  bool _hasShownMovieEnded = false;
  bool _isLeaving = false;

  // Skip debounce & target position
  Duration? _targetSkipPosition;
  Timer? _skipDebounceTimer;

  // 2X Speed state
  bool _isFastForwarding = false;

  // Subtle New Message Toast & unread state
  WatchMessage? _quickToastMessage;
  Timer? _quickToastTimer;
  bool _hasUnreadMessages = false;

  // Video Aspect Ratio Fit mode
  BoxFit _videoFit = BoxFit.contain;
  String _aspectRatioLabel = 'Fit';

  // Key to trigger floating reactions on screen
  final GlobalKey<WatchFloatingReactionsState> _reactionsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlayer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isLeaving) {
      final myUid = context.read<AuthProvider>().user?.id;
      if (myUid != null) {
        WatchTogetherService.instance.setMemberOnline(
          roomCode: widget.roomCode,
          uid: myUid,
          online: true,
        );
      }
    }
  }

  Future<void> _initPlayer() async {
    // 1. Keep screen on during playback
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Wakelock error: $e');
    }

    // 2. Initialize video controller directly from local storage
    try {
      _controller = VideoPlayerController.file(File(widget.localVideoPath));
      await _controller.initialize();

      _controller.addListener(_videoPlayerListener);

      setState(() {
        _isInitialized = true;
      });

      // 3. Connect real-time playback and room listeners
      _setupSyncListeners();

      // 4. Start periodic drift correction timer (every 4 seconds)
      _startDriftCorrectionTimer();
    } catch (e) {
      debugPrint('Video init error: $e');
      setState(() {
        _initError = 'Could not load video: $e';
      });
    }
  }

  void _videoPlayerListener() {
    if (!mounted || !_isInitialized || _isLeaving) return;

    // Check for movie completion (Screen 4 condition) - only if movie has valid duration > 10s
    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    if (dur > const Duration(seconds: 10) && pos >= dur && !_hasShownMovieEnded) {
      _hasShownMovieEnded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isLeaving) {
          _showMovieEndedDialog();
        }
      });
    }
  }

  void _setupSyncListeners() {
    final myUid = context.read<AuthProvider>().user?.id;

    // 1. Playback stream
    _playbackSub = WatchTogetherService.instance
        .streamPlayback(widget.roomCode)
        .listen((playback) {
      _handleRemotePlayback(playback, myUid);
    });

    // 2. Room stream (tracks partner online status and room end)
    _roomSub = WatchTogetherService.instance
        .streamRoom(widget.roomCode)
        .listen((room) {
      if (!mounted || _isLeaving) return;

      if (room == null) {
        // Room ended
        _isLeaving = true;
        try {
          _controller.pause();
        } catch (_) {}
        try {
          WakelockPlus.disable();
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Watch party ended 🎬'),
              backgroundColor: AppColors.terra,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return;
      }

      final partnerUid = room.members.keys.firstWhere(
        (uid) => uid != myUid,
        orElse: () => '',
      );
      final partner = partnerUid.isNotEmpty ? room.members[partnerUid] : null;

      if (partner != null && !partner.online) {
        setState(() {
          _syncStatus = SyncStatus.partnerOffline;
        });
      } else if (_syncStatus == SyncStatus.partnerOffline) {
        setState(() {
          _syncStatus = SyncStatus.inSync;
        });
      }
    });

    // 3. Chat stream
    _chatSub = WatchTogetherService.instance
        .streamChat(widget.roomCode)
        .listen((messages) {
      if (!mounted || _isLeaving) return;

      // Check if new reactions or messages arrived
      if (messages.length > _chatMessages.length) {
        final newMsgs = messages.sublist(_chatMessages.length);
        for (final m in newMsgs) {
          if (m.type == 'reaction') {
            _reactionsKey.currentState?.triggerReaction(m.text);
          } else if (m.type == 'text' && m.uid != myUid) {
            // Partner sent a message while chat is closed!
            if (!_isChatVisible) {
              _showQuickToast(m);
            }
          }
        }
      }

      setState(() {
        _chatMessages = messages;
      });
    });

    // 4. Message count stream (persists real total count beyond query limit)
    _messageCountSub = WatchTogetherService.instance
        .streamMessageCount(widget.roomCode)
        .listen((count) {
      if (mounted && !_isLeaving) {
        setState(() {
          _totalMessageCount = count;
        });
      }
    });
  }

  /// Exact Sync Algorithm: Receiving an action
  void _handleRemotePlayback(WatchPlayback playback, String? myUid) {
    if (!mounted || !_isInitialized || _isLeaving) return;

    // Rule 4: No echo loops — ignore own updates
    if (playback.updatedBy == myUid) return;

    // Ignore remote updates during local action lock (800ms debounce)
    if (DateTime.now().isBefore(_ignoreRemoteUntil)) return;

    _lastRemotePlayback = playback;

    // Calculate latency using server time offset
    final nowServer = WatchTogetherService.instance.currentServerTime;
    final delay = (nowServer - playback.updatedAt).clamp(0, 5000);

    if (playback.isPlaying) {
      final targetMs = playback.positionMs + delay;
      final currentMs = _controller.value.position.inMilliseconds;

      // Only seek if difference is large (> 1500ms) to prevent video frame thrashing and crashing
      if ((currentMs - targetMs).abs() > 1500) {
        _controller.seekTo(Duration(milliseconds: targetMs));
      }
      if (!_controller.value.isPlaying) {
        _controller.play();
      }
      setState(() {
        _syncStatus = SyncStatus.inSync;
      });
    } else {
      // Pause action: only seek if significant difference
      final currentMs = _controller.value.position.inMilliseconds;
      if ((currentMs - playback.positionMs).abs() > 1000) {
        _controller.seekTo(Duration(milliseconds: playback.positionMs));
      }
      if (_controller.value.isPlaying) {
        _controller.pause();
      }
    }
  }

  /// Exact Sync Algorithm: Drift check every 4 seconds
  void _startDriftCorrectionTimer() {
    _driftCheckTimer?.cancel();
    _driftCheckTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_isInitialized || _isLeaving || !_controller.value.isPlaying || _isFastForwarding) return;
      if (DateTime.now().isBefore(_ignoreRemoteUntil)) return;

      final myUid = context.read<AuthProvider>().user?.id;
      if (_lastRemotePlayback != null &&
          _lastRemotePlayback!.isPlaying &&
          _lastRemotePlayback!.updatedBy != myUid) {
        final nowServer = WatchTogetherService.instance.currentServerTime;
        final expectedMs =
            _lastRemotePlayback!.positionMs + (nowServer - _lastRemotePlayback!.updatedAt);
        final currentMs = _controller.value.position.inMilliseconds;
        final diff = (currentMs - expectedMs).abs();

        // If drift exceeds 1500 milliseconds, quietly correct to expected position
        if (diff > 1500) {
          setState(() {
            _syncStatus = SyncStatus.syncing;
          });
          _controller.seekTo(Duration(milliseconds: expectedMs));
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted && !_isLeaving) {
              setState(() {
                _syncStatus = SyncStatus.inSync;
              });
            }
          });
        }
      }
    });
  }

  /// Exact Sync Algorithm: Sending an action
  void _sendPlaybackAction({required bool isPlaying, required int positionMs}) {
    if (_isLeaving) return;
    final myUid = context.read<AuthProvider>().user?.id;
    if (myUid == null) return;

    // Set 2500ms lock so local events don't trigger remote echo
    _ignoreRemoteUntil = DateTime.now().add(const Duration(milliseconds: 2500));

    // Update _lastRemotePlayback locally so local drift timer won't use partner's old position
    _lastRemotePlayback = WatchPlayback(
      isPlaying: isPlaying,
      positionMs: positionMs,
      updatedAt: WatchTogetherService.instance.currentServerTime,
      updatedBy: myUid,
      speed: _controller.value.playbackSpeed,
    );

    WatchTogetherService.instance.updatePlayback(
      roomCode: widget.roomCode,
      uid: myUid,
      isPlaying: isPlaying,
      positionMs: positionMs,
      speed: _controller.value.playbackSpeed,
      buffering: false,
    );
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    HapticFeedback.lightImpact();

    if (_controller.value.isPlaying) {
      _controller.pause();
      _sendPlaybackAction(
        isPlaying: false,
        positionMs: _controller.value.position.inMilliseconds,
      );
    } else {
      _controller.play();
      _sendPlaybackAction(
        isPlaying: true,
        positionMs: _controller.value.position.inMilliseconds,
      );
    }
    setState(() {});
  }

  void _seek(Duration position) {
    if (!_isInitialized) return;
    HapticFeedback.lightImpact();

    _targetSkipPosition = position;
    _controller.seekTo(position);

    _skipDebounceTimer?.cancel();
    _skipDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      _targetSkipPosition = null;
    });

    _sendPlaybackAction(
      isPlaying: _controller.value.isPlaying,
      positionMs: position.inMilliseconds,
    );
    setState(() {});
  }

  void _skip10Seconds(bool forward) {
    if (!_isInitialized) return;
    HapticFeedback.lightImpact();

    final base = _targetSkipPosition ?? _controller.value.position;
    final target = forward
        ? base + const Duration(seconds: 10)
        : base - const Duration(seconds: 10);

    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _controller.value.duration ? _controller.value.duration : target);

    _targetSkipPosition = clamped;
    _controller.seekTo(clamped);

    _skipDebounceTimer?.cancel();
    _skipDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      _targetSkipPosition = null;
    });

    _sendPlaybackAction(
      isPlaying: _controller.value.isPlaying,
      positionMs: clamped.inMilliseconds,
    );
    setState(() {});
  }

  void _startSpeedUp() {
    if (!_isInitialized || _isLeaving) return;
    HapticFeedback.mediumImpact();
    _controller.setPlaybackSpeed(2.0);
    _ignoreRemoteUntil = DateTime.now().add(const Duration(seconds: 10));
    setState(() {
      _isFastForwarding = true;
    });
  }

  void _stopSpeedUp() {
    if (!_isInitialized || _isLeaving) return;
    HapticFeedback.lightImpact();
    _controller.setPlaybackSpeed(1.0);
    setState(() {
      _isFastForwarding = false;
    });
    _sendPlaybackAction(
      isPlaying: _controller.value.isPlaying,
      positionMs: _controller.value.position.inMilliseconds,
    );
  }

  void _showQuickToast(WatchMessage message) {
    _quickToastTimer?.cancel();
    setState(() {
      _quickToastMessage = message;
      _hasUnreadMessages = true;
    });

    _quickToastTimer = Timer(const Duration(milliseconds: 3600), () {
      if (mounted) {
        setState(() {
          _quickToastMessage = null;
        });
      }
    });
  }

  void _openChatFromToast() {
    _quickToastTimer?.cancel();
    setState(() {
      _isChatVisible = true;
      _quickToastMessage = null;
      _hasUnreadMessages = false;
    });
  }

  void _toggleAspectRatio() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_videoFit == BoxFit.contain) {
        _videoFit = BoxFit.cover;
        _aspectRatioLabel = 'Zoom';
      } else if (_videoFit == BoxFit.cover) {
        _videoFit = BoxFit.fill;
        _aspectRatioLabel = 'Stretch';
      } else {
        _videoFit = BoxFit.contain;
        _aspectRatioLabel = 'Fit';
      }
    });
  }

  void _toggleFullscreen() {
    setState(() {
      _isLandscape = !_isLandscape;
    });

    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _showLeaveConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Leave movie night? 🎬',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will pause playback and return you to the lobby.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No, Stay', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _leavePlayerAndRoom();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terra,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yes, Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _leavePlayerAndRoom() async {
    if (_isLeaving) return;
    setState(() {
      _isLeaving = true;
    });

    try {
      _controller.pause();
    } catch (_) {}

    try {
      WakelockPlus.disable();
    } catch (_) {}

    try {
      WatchCallService.instance.endCall();
    } catch (_) {}

    final myUid = context.read<AuthProvider>().user?.id;
    if (myUid != null) {
      WatchTogetherService.instance.leaveRoom(
        roomCode: widget.roomCode,
        uid: myUid,
        isHost: widget.isHost,
      );
    }

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  /// Screen 4: Movie Ended View
  void _showMovieEndedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.terra.withOpacity(0.4), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'Movie Night Complete',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You shared another wonderful story together.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              // Watch Another Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final myUid = context.read<AuthProvider>().user?.id;
                    if (myUid != null) {
                      await WatchTogetherService.instance.resetRoomForAnother(
                        roomCode: widget.roomCode,
                        uid: myUid,
                      );
                    }
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WatchWaitingScreen(
                            roomCode: widget.roomCode,
                            isHost: widget.isHost,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text(
                    'Watch Another',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.terra,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Leave Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _leavePlayerAndRoom();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    foregroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Leave to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _playbackSub?.cancel();
    _roomSub?.cancel();
    _chatSub?.cancel();
    _messageCountSub?.cancel();
    _driftCheckTimer?.cancel();
    _skipDebounceTimer?.cancel();
    _quickToastTimer?.cancel();
    WatchCallService.instance.dispose();
    _controller.removeListener(_videoPlayerListener);
    _controller.dispose();

    // Reset preferred orientation to default portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  Widget _buildFastForwardIndicator() {
    if (!_isFastForwarding) return const SizedBox.shrink();

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.terra.withOpacity(0.85), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.terra.withOpacity(0.4),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fast_forward_rounded, color: AppColors.terra, size: 24),
            SizedBox(width: 8),
            Text(
              '2X SPEED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickToast(String partnerAvatarUrl) {
    if (_quickToastMessage == null || _isChatVisible) {
      return const SizedBox.shrink();
    }

    final avatar = _quickToastMessage!.avatarUrl.isNotEmpty
        ? _quickToastMessage!.avatarUrl
        : partnerAvatarUrl;

    return Positioned(
      top: _isLandscape ? 16 : 10,
      right: 14,
      child: GestureDetector(
        onTap: _openChatFromToast,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: _isLandscape ? 280 : 230,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.terra.withOpacity(0.7), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.terra.withOpacity(0.3),
                backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                child: avatar.isEmpty
                    ? Text(
                        _quickToastMessage!.name.isNotEmpty
                            ? _quickToastMessage!.name[0].toUpperCase()
                            : 'P',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.terra,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _quickToastMessage!.name.isNotEmpty ? _quickToastMessage!.name : 'Partner',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.terra,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _quickToastMessage!.text,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myUid = auth.user?.id ?? '';
    final myName = auth.user?.nickname ?? 'You';
    final myAvatarUrl = auth.user?.avatarUrl ?? '';
    final partnerAvatarUrl = auth.partner?.avatarUrl ?? '';
    final partnerName = auth.partner?.nickname ?? 'Partner';

    if (_initError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  _initError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.terra),
                  child: const Text('Back to Waiting Room', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.terra),
        ),
      );
    }

    return PopScope(
      canPop: _isLeaving,
      onPopInvoked: (didPop) {
        if (!didPop && !_isLeaving) {
          _showLeaveConfirmation();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: !_isLandscape,
          bottom: !_isLandscape,
          child: Stack(
            children: [
              // Main Layout (Portrait vs Landscape)
              if (!_isLandscape)
                // Portrait: Video ~40% on top, Chat below
                Column(
                  children: [
                    // Video Section
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.38,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: FittedBox(
                              fit: _videoFit,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: _controller.value.size.width > 0
                                    ? _controller.value.size.width
                                    : 16,
                                height: _controller.value.size.height > 0
                                    ? _controller.value.size.height
                                    : 9,
                                child: VideoPlayer(_controller),
                              ),
                            ),
                          ),
                          // Floating Reactions over Video
                          WatchFloatingReactions(key: _reactionsKey),
                          // Fast Forward 2X HUD
                          _buildFastForwardIndicator(),
                          // Controls Overlay
                          ValueListenableBuilder<WatchCallStatus>(
                            valueListenable: WatchCallService.instance.callStatus,
                            builder: (context, callStatus, _) {
                              final isCallActive = callStatus == WatchCallStatus.connected ||
                                  callStatus == WatchCallStatus.calling;
                              return WatchControlsOverlay(
                                isPlaying: _controller.value.isPlaying,
                                position: _controller.value.position,
                                duration: _controller.value.duration,
                                syncStatus: _syncStatus,
                                movieTitle: widget.movieTitle,
                                isFullscreen: _isLandscape,
                                isChatVisible: _isChatVisible,
                                hasUnreadMessages: _hasUnreadMessages,
                                onTogglePlay: _togglePlayPause,
                                onSeek: _seek,
                                onSkipBack10: () => _skip10Seconds(false),
                                onSkipForward10: () => _skip10Seconds(true),
                                onToggleFullscreen: _toggleFullscreen,
                                onToggleAspectRatio: _toggleAspectRatio,
                                aspectRatioLabel: _aspectRatioLabel,
                                onSpeedUpStart: _startSpeedUp,
                                onSpeedUpEnd: _stopSpeedUp,
                                onStartCall: () {
                                  if (callStatus == WatchCallStatus.idle) {
                                    WatchCallService.instance.startCall(
                                      roomCode: widget.roomCode,
                                      myUid: myUid,
                                      myName: myName,
                                    );
                                  } else {
                                    WatchCallService.instance.endCall();
                                  }
                                },
                                isCallActive: isCallActive,
                                onToggleChat: () {
                                  setState(() {
                                    _isChatVisible = !_isChatVisible;
                                    if (_isChatVisible) {
                                      _hasUnreadMessages = false;
                                      _quickToastMessage = null;
                                    }
                                  });
                                },
                                onLeave: _showLeaveConfirmation,
                              );
                            },
                          ),
                          // Quick notification toast over video in portrait
                          _buildQuickToast(partnerAvatarUrl),
                        ],
                      ),
                    ),

                    // Chat Section below video in Portrait
                    Expanded(
                      child: _isChatVisible
                          ? WatchChatView(
                              messages: _chatMessages,
                              currentUid: myUid,
                              totalCount: _totalMessageCount,
                              partnerAvatarUrl: partnerAvatarUrl,
                              userAvatarUrl: myAvatarUrl,
                              isLandscape: false,
                              onSendMessage: (text) {
                                WatchTogetherService.instance.sendChatMessage(
                                  roomCode: widget.roomCode,
                                  uid: myUid,
                                  name: myName,
                                  text: text,
                                  avatarUrl: myAvatarUrl,
                                );
                              },
                              onSendReaction: (emoji) {
                                _reactionsKey.currentState?.triggerReaction(emoji);
                                WatchTogetherService.instance.sendReaction(
                                  roomCode: widget.roomCode,
                                  uid: myUid,
                                  name: myName,
                                  emoji: emoji,
                                );
                              },
                              onToggleCollapse: () {
                                setState(() {
                                  _isChatVisible = false;
                                });
                              },
                            )
                          : Center(
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isChatVisible = true;
                                    _hasUnreadMessages = false;
                                    _quickToastMessage = null;
                                  });
                                },
                                icon: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(Icons.chat_bubble_outline_rounded,
                                        color: AppColors.terra),
                                    if (_hasUnreadMessages)
                                      Positioned(
                                        top: -2,
                                        right: -2,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Show Live Chat',
                                        style: TextStyle(color: AppColors.terra)),
                                    if (_hasUnreadMessages) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          'New',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                )
              else
                // Landscape: Video Fullscreen with Translucent Overlay Chat on Right
                Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: FittedBox(
                        fit: _videoFit,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: _controller.value.size.width > 0
                              ? _controller.value.size.width
                              : 16,
                          height: _controller.value.size.height > 0
                              ? _controller.value.size.height
                              : 9,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    ),
                    // Floating Reactions over fullscreen video
                    WatchFloatingReactions(key: _reactionsKey),
                    // Fast Forward 2X HUD
                    _buildFastForwardIndicator(),
                    // Controls Overlay
                    ValueListenableBuilder<WatchCallStatus>(
                      valueListenable: WatchCallService.instance.callStatus,
                      builder: (context, callStatus, _) {
                        final isCallActive = callStatus == WatchCallStatus.connected ||
                            callStatus == WatchCallStatus.calling;
                        return WatchControlsOverlay(
                          isPlaying: _controller.value.isPlaying,
                          position: _controller.value.position,
                          duration: _controller.value.duration,
                          syncStatus: _syncStatus,
                          movieTitle: widget.movieTitle,
                          isFullscreen: _isLandscape,
                          isChatVisible: _isChatVisible,
                          hasUnreadMessages: _hasUnreadMessages,
                          onTogglePlay: _togglePlayPause,
                          onSeek: _seek,
                          onSkipBack10: () => _skip10Seconds(false),
                          onSkipForward10: () => _skip10Seconds(true),
                          onToggleFullscreen: _toggleFullscreen,
                          onToggleAspectRatio: _toggleAspectRatio,
                          aspectRatioLabel: _aspectRatioLabel,
                          onSpeedUpStart: _startSpeedUp,
                          onSpeedUpEnd: _stopSpeedUp,
                          onStartCall: () {
                            if (callStatus == WatchCallStatus.idle) {
                              WatchCallService.instance.startCall(
                                roomCode: widget.roomCode,
                                myUid: myUid,
                                myName: myName,
                              );
                            } else {
                              WatchCallService.instance.endCall();
                            }
                          },
                          isCallActive: isCallActive,
                          onToggleChat: () {
                            setState(() {
                              _isChatVisible = !_isChatVisible;
                              if (_isChatVisible) {
                                _hasUnreadMessages = false;
                                _quickToastMessage = null;
                              }
                            });
                          },
                          onLeave: _showLeaveConfirmation,
                        );
                      },
                    ),
                    // Quick notification toast over video in landscape
                    _buildQuickToast(partnerAvatarUrl),
                    // Translucent Overlay Chat in Landscape (Right 28% of screen)
                    if (_isChatVisible)
                      Positioned(
                        top: 20,
                        bottom: 20,
                        right: 8,
                        width: MediaQuery.of(context).size.width * 0.28,
                        child: WatchChatView(
                          messages: _chatMessages,
                          currentUid: myUid,
                          totalCount: _totalMessageCount,
                          partnerAvatarUrl: partnerAvatarUrl,
                          userAvatarUrl: myAvatarUrl,
                          isLandscape: true,
                          onSendMessage: (text) {
                            WatchTogetherService.instance.sendChatMessage(
                              roomCode: widget.roomCode,
                              uid: myUid,
                              name: myName,
                              text: text,
                              avatarUrl: myAvatarUrl,
                            );
                          },
                          onSendReaction: (emoji) {
                            _reactionsKey.currentState?.triggerReaction(emoji);
                            WatchTogetherService.instance.sendReaction(
                              roomCode: widget.roomCode,
                              uid: myUid,
                              name: myName,
                              emoji: emoji,
                            );
                          },
                          onToggleCollapse: () {
                            setState(() {
                              _isChatVisible = false;
                            });
                          },
                        ),
                      ),
                  ],
                ),

              // Floating Picture-in-Picture Video Call Overlay
              WatchCallOverlay(
                roomCode: widget.roomCode,
                myUid: myUid,
                myName: myName,
                partnerAvatarUrl: partnerAvatarUrl,
                partnerName: partnerName,
                isLandscape: _isLandscape,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
