import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../models/watch_room_model.dart';
import '../services/watch_together_service.dart';
import '../widgets/watch_controls_overlay.dart';
import '../widgets/watch_chat_view.dart';
import '../widgets/watch_floating_reactions.dart';
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

class _WatchPlayerScreenState extends State<WatchPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  String? _initError;

  // Stream Subscriptions
  StreamSubscription<WatchPlayback>? _playbackSub;
  StreamSubscription<WatchRoom?>? _roomSub;
  StreamSubscription<List<WatchMessage>>? _chatSub;

  // Sync state
  WatchPlayback? _lastRemotePlayback;
  DateTime _ignoreRemoteUntil = DateTime.now();
  Timer? _driftCheckTimer;
  SyncStatus _syncStatus = SyncStatus.inSync;

  // Chat & UI state
  List<WatchMessage> _chatMessages = [];
  bool _isLandscape = false;
  bool _isChatVisible = true;
  bool _hasShownMovieEnded = false;

  // Key to trigger floating reactions on screen
  final GlobalKey<WatchFloatingReactionsState> _reactionsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initPlayer();
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
    if (!mounted || !_isInitialized) return;

    // Check for movie completion (Screen 4 condition)
    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    if (dur > Duration.zero && pos >= dur && !_hasShownMovieEnded) {
      _hasShownMovieEnded = true;
      _showMovieEndedDialog();
    }

    // Handle buffering notification to partner
    if (_controller.value.isBuffering) {
      final myUid = context.read<AuthProvider>().user?.id;
      if (myUid != null) {
        WatchTogetherService.instance.updatePlayback(
          roomCode: widget.roomCode,
          uid: myUid,
          isPlaying: false,
          positionMs: pos.inMilliseconds,
          buffering: true,
        );
      }
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

    // 2. Room stream (tracks partner online status)
    _roomSub = WatchTogetherService.instance
        .streamRoom(widget.roomCode)
        .listen((room) {
      if (!mounted || room == null) return;

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
      if (!mounted) return;

      // Check if new reactions arrived
      if (messages.length > _chatMessages.length) {
        final newMsgs = messages.sublist(_chatMessages.length);
        for (final m in newMsgs) {
          if (m.type == 'reaction') {
            _reactionsKey.currentState?.triggerReaction(m.text);
          }
        }
      }

      setState(() {
        _chatMessages = messages;
      });
    });
  }

  /// Exact Sync Algorithm: Receiving an action
  void _handleRemotePlayback(WatchPlayback playback, String? myUid) {
    if (!mounted || !_isInitialized) return;

    // Rule 4: No echo loops — ignore own updates
    if (playback.updatedBy == myUid) return;

    // Ignore remote updates during local action lock (500ms debounce)
    if (DateTime.now().isBefore(_ignoreRemoteUntil)) return;

    _lastRemotePlayback = playback;

    // Calculate latency using server time offset
    final nowServer = WatchTogetherService.instance.currentServerTime;
    final delay = (nowServer - playback.updatedAt).clamp(0, 8000);

    if (playback.isPlaying) {
      final targetMs = playback.positionMs + delay;
      final currentMs = _controller.value.position.inMilliseconds;

      // Only seek if difference is noticeable (> 300ms) to avoid local audio stutter
      if ((currentMs - targetMs).abs() > 300) {
        _controller.seekTo(Duration(milliseconds: targetMs));
      }
      _controller.play();
      setState(() {
        _syncStatus = SyncStatus.inSync;
      });
    } else {
      // Pause action
      _controller.seekTo(Duration(milliseconds: playback.positionMs));
      _controller.pause();
    }
  }

  /// Exact Sync Algorithm: Drift check every 4 seconds
  void _startDriftCorrectionTimer() {
    _driftCheckTimer?.cancel();
    _driftCheckTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_isInitialized || !_controller.value.isPlaying) return;

      final myUid = context.read<AuthProvider>().user?.id;
      if (_lastRemotePlayback != null &&
          _lastRemotePlayback!.isPlaying &&
          _lastRemotePlayback!.updatedBy != myUid) {
        final nowServer = WatchTogetherService.instance.currentServerTime;
        final expectedMs =
            _lastRemotePlayback!.positionMs + (nowServer - _lastRemotePlayback!.updatedAt);
        final currentMs = _controller.value.position.inMilliseconds;
        final diff = (currentMs - expectedMs).abs();

        // If drift exceeds 400 milliseconds, quietly correct to expected position
        if (diff > 400) {
          setState(() {
            _syncStatus = SyncStatus.syncing;
          });
          _controller.seekTo(Duration(milliseconds: expectedMs));
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) {
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
    final myUid = context.read<AuthProvider>().user?.id;
    if (myUid == null) return;

    // Set 500ms lock so local events don't trigger remote echo
    _ignoreRemoteUntil = DateTime.now().add(const Duration(milliseconds: 500));

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

    _controller.seekTo(position);
    _sendPlaybackAction(
      isPlaying: _controller.value.isPlaying,
      positionMs: position.inMilliseconds,
    );
    setState(() {});
  }

  void _skip10Seconds(bool forward) {
    if (!_isInitialized) return;
    HapticFeedback.lightImpact();

    final current = _controller.value.position;
    final target = forward
        ? current + const Duration(seconds: 10)
        : current - const Duration(seconds: 10);

    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _controller.value.duration ? _controller.value.duration : target);

    _controller.seekTo(clamped);
    _sendPlaybackAction(
      isPlaying: _controller.value.isPlaying,
      positionMs: clamped.inMilliseconds,
    );
    setState(() {});
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
    _controller.pause();
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
    WakelockPlus.disable();
    _playbackSub?.cancel();
    _roomSub?.cancel();
    _chatSub?.cancel();
    _driftCheckTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final myUid = context.watch<AuthProvider>().user?.id ?? '';
    final myName = context.watch<AuthProvider>().user?.nickname ?? 'You';

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
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _showLeaveConfirmation();
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
                            child: AspectRatio(
                              aspectRatio: _controller.value.aspectRatio > 0
                                  ? _controller.value.aspectRatio
                                  : 16 / 9,
                              child: VideoPlayer(_controller),
                            ),
                          ),
                          // Floating Reactions over Video
                          WatchFloatingReactions(key: _reactionsKey),
                          // Controls Overlay
                          WatchControlsOverlay(
                            isPlaying: _controller.value.isPlaying,
                            position: _controller.value.position,
                            duration: _controller.value.duration,
                            syncStatus: _syncStatus,
                            movieTitle: widget.movieTitle,
                            isFullscreen: _isLandscape,
                            isChatVisible: _isChatVisible,
                            onTogglePlay: _togglePlayPause,
                            onSeek: _seek,
                            onSkipBack10: () => _skip10Seconds(false),
                            onSkipForward10: () => _skip10Seconds(true),
                            onToggleFullscreen: _toggleFullscreen,
                            onToggleChat: () {
                              setState(() {
                                _isChatVisible = !_isChatVisible;
                              });
                            },
                            onLeave: _showLeaveConfirmation,
                          ),
                        ],
                      ),
                    ),

                    // Chat Section below video in Portrait
                    Expanded(
                      child: _isChatVisible
                          ? WatchChatView(
                              messages: _chatMessages,
                              currentUid: myUid,
                              isLandscape: false,
                              onSendMessage: (text) {
                                WatchTogetherService.instance.sendChatMessage(
                                  roomCode: widget.roomCode,
                                  uid: myUid,
                                  name: myName,
                                  text: text,
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
                                  });
                                },
                                icon: const Icon(Icons.chat_bubble_outline_rounded,
                                    color: AppColors.terra),
                                label: const Text('Show Live Chat',
                                    style: TextStyle(color: AppColors.terra)),
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
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio > 0
                            ? _controller.value.aspectRatio
                            : 16 / 9,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                    // Floating Reactions over fullscreen video
                    WatchFloatingReactions(key: _reactionsKey),
                    // Controls Overlay
                    WatchControlsOverlay(
                      isPlaying: _controller.value.isPlaying,
                      position: _controller.value.position,
                      duration: _controller.value.duration,
                      syncStatus: _syncStatus,
                      movieTitle: widget.movieTitle,
                      isFullscreen: _isLandscape,
                      isChatVisible: _isChatVisible,
                      onTogglePlay: _togglePlayPause,
                      onSeek: _seek,
                      onSkipBack10: () => _skip10Seconds(false),
                      onSkipForward10: () => _skip10Seconds(true),
                      onToggleFullscreen: _toggleFullscreen,
                      onToggleChat: () {
                        setState(() {
                          _isChatVisible = !_isChatVisible;
                        });
                      },
                      onLeave: _showLeaveConfirmation,
                    ),
                    // Translucent Overlay Chat in Landscape (Right 35% of screen)
                    if (_isChatVisible)
                      Positioned(
                        top: 48,
                        bottom: 12,
                        right: 12,
                        width: MediaQuery.of(context).size.width * 0.35,
                        child: WatchChatView(
                          messages: _chatMessages,
                          currentUid: myUid,
                          isLandscape: true,
                          onSendMessage: (text) {
                            WatchTogetherService.instance.sendChatMessage(
                              roomCode: widget.roomCode,
                              uid: myUid,
                              name: myName,
                              text: text,
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
            ],
          ),
        ),
      ),
    );
  }
}
