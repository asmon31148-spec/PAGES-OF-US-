import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/memories_provider.dart';
import '../models/watch_room_model.dart';
import '../services/watch_together_service.dart';
import '../widgets/watch_controls_overlay.dart';
import '../widgets/watch_chat_view.dart';
import '../widgets/watch_floating_reactions.dart';
import '../widgets/watch_call_overlay.dart';
import '../services/watch_call_service.dart';
import 'watch_waiting_screen.dart';
import '../services/watch_video_service.dart';

class WatchPlayerScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;
  final String? localVideoPath;
  final String? networkVideoUrl;
  final String? youtubeId;
  final String videoType; // 'local', 'youtube', 'web_url'
  final String movieTitle;

  const WatchPlayerScreen({
    super.key,
    required this.roomCode,
    required this.isHost,
    this.localVideoPath,
    this.networkVideoUrl,
    this.youtubeId,
    this.videoType = 'local',
    required this.movieTitle,
  });

  @override
  State<WatchPlayerScreen> createState() => _WatchPlayerScreenState();
}

class _WatchPlayerScreenState extends State<WatchPlayerScreen> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _hasController = false;
  bool _isInitialized = false;
  String? _initError;

  // WebView Cinema fallback state (Synced YouTube IFrame & Web Video Pages)
  bool _isWebViewMode = false;
  WebViewController? _webController;
  bool _wvIsPlaying = false;
  Duration _wvPosition = Duration.zero;
  Duration _wvDuration = Duration.zero;
  double _wvSpeed = 1.0;
  bool _wvTouchThrough = false;
  bool _triedMobileWebFallback = false;

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

  // Heartbeat & connection listeners
  Timer? _heartbeatTimer;
  StreamSubscription? _connectedSub;
  VoidCallback? _callStatusListener;

  // Chat & UI state
  List<WatchMessage> _chatMessages = [];
  int _totalMessageCount = 0;
  bool _isLandscape = false;
  bool _isChatVisible = true;
  bool _hasShownMovieEnded = false;
  bool _isLeaving = false;
  bool _hasSavedTicketStub = false;

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
        WatchTogetherService.instance.updateMemberOnline(
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

    // Mark online state immediately upon entering player
    final myUid = context.read<AuthProvider>().user?.id;
    if (myUid != null) {
      WatchTogetherService.instance.updateMemberOnline(
        roomCode: widget.roomCode,
        uid: myUid,
        online: true,
      );
    }

    // Start periodic heartbeat every 8 seconds to prevent false offline status
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!_isLeaving && mounted) {
        final uid = context.read<AuthProvider>().user?.id;
        if (uid != null) {
          WatchTogetherService.instance.updateMemberOnline(
            roomCode: widget.roomCode,
            uid: uid,
            online: true,
          );
        }
      }
    });

    // Listen to RTDB connection state so reconnections immediately restore online status
    _connectedSub?.cancel();
    _connectedSub = FirebaseDatabase.instance.ref('.info/connected').onValue.listen((event) {
      final connected = event.snapshot.value == true;
      if (connected && !_isLeaving && mounted) {
        final uid = context.read<AuthProvider>().user?.id;
        if (uid != null) {
          WatchTogetherService.instance.updateMemberOnline(
            roomCode: widget.roomCode,
            uid: uid,
            online: true,
          );
          try {
            FirebaseDatabase.instance
                .ref('watchRooms/${widget.roomCode}/members/$uid/online')
                .onDisconnect()
                .set(false);
          } catch (_) {}
        }
      }
    });

    // Listen for call status changes to guarantee online status and audio focus during calls
    _callStatusListener = () {
      if (!mounted || _isLeaving) return;
      final status = WatchCallService.instance.callStatus.value;
      if (status == WatchCallStatus.connected || status == WatchCallStatus.calling) {
        try {
          _controller.setVolume(1.0);
        } catch (_) {}
        if (_syncStatus == SyncStatus.partnerOffline) {
          setState(() {
            _syncStatus = SyncStatus.inSync;
          });
        }
      }
    };
    WatchCallService.instance.callStatus.addListener(_callStatusListener!);

    // 2. Initialize video controller (Supports YouTube Stream with multi-client & proxy failover, Web URL, and Local File)
    try {
      await _initializeVideoSource(forceRefresh: false);

      // 3. Connect real-time playback and room listeners
      _setupSyncListeners();

      // 4. Start periodic drift correction timer (every 4 seconds)
      _startDriftCorrectionTimer();
    } catch (e) {
      debugPrint('Video init error: $e');
      if (mounted) {
        setState(() {
          _initError = 'Could not load video: $e';
        });
      }
    }
  }

  Future<void> _disposeCurrentController() async {
    if (!_hasController) return;
    _hasController = false;
    try {
      _controller.removeListener(_videoPlayerListener);
    } catch (_) {}
    try {
      await _controller.dispose();
    } catch (_) {}
  }

  bool get _currentIsPlaying => _isWebViewMode
      ? _wvIsPlaying
      : (_hasController && _controller.value.isPlaying);

  Duration get _currentPosition => _isWebViewMode
      ? _wvPosition
      : (_hasController ? _controller.value.position : Duration.zero);

  Duration get _currentDuration => _isWebViewMode
      ? _wvDuration
      : (_hasController ? _controller.value.duration : Duration.zero);

  double get _currentSpeed => _isWebViewMode
      ? _wvSpeed
      : (_hasController ? _controller.value.playbackSpeed : 1.0);

  Future<void> _playerPlay() async {
    if (_isWebViewMode) {
      _wvIsPlaying = true;
      await _runWebJs("window._cinemaCmd && window._cinemaCmd('play');");
    } else if (_hasController) {
      await _controller.play();
    }
  }

  Future<void> _playerPause() async {
    if (_isWebViewMode) {
      _wvIsPlaying = false;
      await _runWebJs("window._cinemaCmd && window._cinemaCmd('pause');");
    } else if (_hasController) {
      await _controller.pause();
    }
  }

  Future<void> _playerSeekTo(Duration position) async {
    if (_isWebViewMode) {
      _wvPosition = position;
      final sec = position.inMilliseconds / 1000.0;
      await _runWebJs("window._cinemaCmd && window._cinemaCmd('seek', $sec);");
    } else if (_hasController) {
      await _controller.seekTo(position);
    }
  }

  Future<void> _playerSetSpeed(double speed) async {
    if (_isWebViewMode) {
      _wvSpeed = speed;
      await _runWebJs("window._cinemaCmd && window._cinemaCmd('speed', $speed);");
    } else if (_hasController) {
      await _controller.setPlaybackSpeed(speed);
    }
  }

  Future<void> _runWebJs(String js) async {
    try {
      await _webController?.runJavaScript(js);
    } catch (_) {}
  }

  Future<bool> _tryNativeSources(List<WatchStreamSource> sources) async {
    for (final src in sources) {
      VideoPlayerController? candidate;
      try {
        candidate = VideoPlayerController.networkUrl(
          Uri.parse(src.url),
          httpHeaders: src.headers,
        );
        await candidate.initialize().timeout(const Duration(seconds: 12));
        await _disposeCurrentController();
        _controller = candidate;
        _hasController = true;
        _isWebViewMode = false;
        try {
          await _controller.setVolume(1.0);
        } catch (_) {}
        _controller.addListener(_videoPlayerListener);
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _initError = null;
          });
        }
        return true;
      } catch (e) {
        debugPrint('[WatchPlayer] Source ${src.label} failed: $e');
        try {
          await candidate?.dispose();
        } catch (_) {}
      }
    }
    return false;
  }

  Future<void> _initializeVideoSource({bool forceRefresh = false}) async {
    _triedMobileWebFallback = false;

    if (widget.videoType == 'youtube' && widget.youtubeId != null && widget.youtubeId!.isNotEmpty) {
      final sources = await WatchVideoService.instance.getPlayableYouTubeSources(
        widget.youtubeId!,
        forceRefresh: forceRefresh,
      );
      if (sources.isNotEmpty && await _tryNativeSources(sources)) {
        return;
      }
      // Fast automatic failover to Synced YouTube IFrame Cinema WebView
      await _activateWebViewYouTube(widget.youtubeId!);
      return;
    }

    if (widget.videoType == 'web_url' && widget.networkVideoUrl != null && widget.networkVideoUrl!.isNotEmpty) {
      final resolved = await WatchVideoService.instance.resolveWebVideoSources(widget.networkVideoUrl!);
      if (resolved.detectedYoutubeId != null) {
        if (resolved.nativeSources.isNotEmpty && await _tryNativeSources(resolved.nativeSources)) {
          return;
        }
        await _activateWebViewYouTube(resolved.detectedYoutubeId!);
        return;
      }
      if (resolved.nativeSources.isNotEmpty && await _tryNativeSources(resolved.nativeSources)) {
        return;
      }
      // Automatic failover to Synced Web Video Page Mode
      await _activateWebViewUrl(resolved.webViewFallbackUrl ?? widget.networkVideoUrl!);
      return;
    }

    if (widget.localVideoPath != null && widget.localVideoPath!.isNotEmpty) {
      final ctrl = VideoPlayerController.file(File(widget.localVideoPath!));
      await ctrl.initialize().timeout(const Duration(seconds: 18));
      await _disposeCurrentController();
      _controller = ctrl;
      _hasController = true;
      _isWebViewMode = false;
      try {
        await _controller.setVolume(1.0);
      } catch (_) {}
      _controller.addListener(_videoPlayerListener);
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _initError = null;
        });
      }
      return;
    }

    throw Exception('No video stream URL or local file provided.');
  }

  WebViewController _createBaseWebViewController({String? htmlVideoFallbackId}) {
    const chromeUa =
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';
    const params = PlatformWebViewControllerCreationParams();
    final ctrl = WebViewController.fromPlatformCreationParams(params);
    ctrl
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(chromeUa)
      ..addJavaScriptChannel(
        'CinemaBridge',
        onMessageReceived: (JavaScriptMessage msg) {
          _handleCinemaBridgeMessage(msg.message, htmlVideoFallbackId);
        },
      );

    if (ctrl.platform is AndroidWebViewController) {
      final androidCtrl = ctrl.platform as AndroidWebViewController;
      androidCtrl.setMediaPlaybackRequiresUserGesture(false);
    }
    return ctrl;
  }

  void _handleCinemaBridgeMessage(String raw, String? ytFallbackId) {
    if (!mounted || _isLeaving) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;
      final type = data['type']?.toString() ?? '';
      if (type == 'embedError' && ytFallbackId != null && !_triedMobileWebFallback) {
        _triedMobileWebFallback = true;
        _activateWebViewUrl('https://m.youtube.com/watch?v=$ytFallbackId');
        return;
      }
      if (type == 'state') {
        final playing = data['playing'] == true;
        final posMs = (data['posMs'] as num?)?.toInt() ?? 0;
        final durMs = (data['durMs'] as num?)?.toInt() ?? 0;
        final rate = (data['rate'] as num?)?.toDouble() ?? 1.0;
        final ended = data['ended'] == true;
        setState(() {
          _wvIsPlaying = playing;
          if (posMs >= 0) _wvPosition = Duration(milliseconds: posMs);
          if (durMs >= 0) _wvDuration = Duration(milliseconds: durMs);
          _wvSpeed = rate;
        });
        if (ended && !_hasShownMovieEnded && durMs > 10000) {
          _hasShownMovieEnded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isLeaving) _showMovieEndedDialog();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _activateWebViewYouTube(String youtubeId) async {
    await _disposeCurrentController();
    final ctrl = _createBaseWebViewController(htmlVideoFallbackId: youtubeId);
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body, #player { width: 100%; height: 100%; background: #000; overflow: hidden; }
  </style>
</head>
<body>
  <div id="player"></div>
  <script src="https://www.youtube.com/iframe_api"></script>
  <script>
    var player;
    var ready = false;
    function sendState() {
      if (!ready || !player || !window.CinemaBridge) return;
      try {
        var st = player.getPlayerState ? player.getPlayerState() : -1;
        var pos = player.getCurrentTime ? player.getCurrentTime() : 0;
        var dur = player.getDuration ? player.getDuration() : 0;
        var rate = player.getPlaybackRate ? player.getPlaybackRate() : 1;
        window.CinemaBridge.postMessage(JSON.stringify({
          type: 'state',
          playing: st === 1,
          ended: st === 0,
          posMs: Math.round(pos * 1000),
          durMs: Math.round(dur * 1000),
          rate: rate
        }));
      } catch (e) {}
    }
    function onYouTubeIframeAPIReady() {
      player = new YT.Player('player', {
        videoId: '$youtubeId',
        width: '100%',
        height: '100%',
        playerVars: {
          playsinline: 1,
          rel: 0,
          modestbranding: 1,
          controls: 1,
          enablejsapi: 1,
          origin: 'https://www.youtube.com'
        },
        events: {
          onReady: function() { ready = true; sendState(); },
          onStateChange: function() { sendState(); },
          onError: function(ev) {
            if (window.CinemaBridge) {
              window.CinemaBridge.postMessage(JSON.stringify({ type: 'embedError', code: ev.data }));
            }
          }
        }
      });
    }
    window._cinemaCmd = function(cmd, val) {
      if (!ready || !player) return;
      try {
        if (cmd === 'play') player.playVideo();
        else if (cmd === 'pause') player.pauseVideo();
        else if (cmd === 'seek') player.seekTo(Number(val) || 0, true);
        else if (cmd === 'speed') player.setPlaybackRate(Number(val) || 1);
        setTimeout(sendState, 150);
      } catch (e) {}
    };
    setInterval(sendState, 700);
  </script>
</body>
</html>
''';
    await ctrl.loadHtmlString(html, baseUrl: 'https://www.youtube.com');
    if (!mounted) return;
    setState(() {
      _webController = ctrl;
      _isWebViewMode = true;
      _wvIsPlaying = false;
      _wvPosition = Duration.zero;
      _wvDuration = Duration.zero;
      _wvSpeed = 1.0;
      _isInitialized = true;
      _initError = null;
    });
  }

  static const String _html5VideoBridgeJs = '''
(function() {
  if (window._cinemaHooked) return;
  window._cinemaHooked = true;
  function findVideo() {
    return document.querySelector('video');
  }
  function sendState() {
    var v = findVideo();
    if (!v || !window.CinemaBridge) return;
    try {
      window.CinemaBridge.postMessage(JSON.stringify({
        type: 'state',
        playing: !v.paused && !v.ended,
        ended: !!v.ended,
        posMs: Math.round((v.currentTime || 0) * 1000),
        durMs: Math.round((isFinite(v.duration) ? v.duration : 0) * 1000),
        rate: v.playbackRate || 1
      }));
    } catch (e) {}
  }
  window._cinemaCmd = function(cmd, val) {
    var v = findVideo();
    if (!v) return;
    try {
      if (cmd === 'play') { v.muted = false; v.play(); }
      else if (cmd === 'pause') v.pause();
      else if (cmd === 'seek') v.currentTime = Number(val) || 0;
      else if (cmd === 'speed') v.playbackRate = Number(val) || 1;
      setTimeout(sendState, 150);
    } catch (e) {}
  };
  setInterval(sendState, 700);
})();
''';

  Future<void> _activateWebViewUrl(String url) async {
    await _disposeCurrentController();
    final ctrl = _createBaseWebViewController();
    ctrl.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          ctrl.runJavaScript(_html5VideoBridgeJs);
        },
      ),
    );
    await ctrl.loadRequest(Uri.parse(url));
    if (!mounted) return;
    setState(() {
      _webController = ctrl;
      _isWebViewMode = true;
      _wvIsPlaying = false;
      _wvPosition = Duration.zero;
      _wvDuration = Duration.zero;
      _wvSpeed = 1.0;
      _isInitialized = true;
      _initError = null;
    });
  }

  Future<void> _retryStreamLoad() async {
    if (!mounted) return;
    setState(() {
      _initError = null;
      _isInitialized = false;
      _isWebViewMode = false;
      _webController = null;
    });
    try {
      await _initializeVideoSource(forceRefresh: true);
      if (mounted) {
        _setupSyncListeners();
        _startDriftCorrectionTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = 'Could not load video: $e';
        });
      }
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
    _playbackSub?.cancel();
    _roomSub?.cancel();
    _chatSub?.cancel();
    _messageCountSub?.cancel();
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

      final isCallActive = WatchCallService.instance.callStatus.value == WatchCallStatus.connected ||
          WatchCallService.instance.callStatus.value == WatchCallStatus.calling;

      if (isCallActive) {
        // If actively in a call, partner is 100% online
        if (_syncStatus == SyncStatus.partnerOffline) {
          setState(() {
            _syncStatus = SyncStatus.inSync;
          });
        }
      } else if (partner != null && !partner.online) {
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
      final currentMs = _currentPosition.inMilliseconds;

      // Only seek if difference is large (> 1500ms) to prevent video frame thrashing and crashing
      if ((currentMs - targetMs).abs() > 1500) {
        _playerSeekTo(Duration(milliseconds: targetMs));
      }
      if (!_currentIsPlaying) {
        _playerPlay();
      }
      setState(() {
        _syncStatus = SyncStatus.inSync;
      });
    } else {
      // Pause action: only seek if significant difference
      final currentMs = _currentPosition.inMilliseconds;
      if ((currentMs - playback.positionMs).abs() > 1000) {
        _playerSeekTo(Duration(milliseconds: playback.positionMs));
      }
      if (_currentIsPlaying) {
        _playerPause();
      }
    }
  }

  /// Exact Sync Algorithm: Drift check every 4 seconds
  void _startDriftCorrectionTimer() {
    _driftCheckTimer?.cancel();
    _driftCheckTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_isInitialized || _isLeaving || !_currentIsPlaying || _isFastForwarding) return;
      if (DateTime.now().isBefore(_ignoreRemoteUntil)) return;

      final myUid = context.read<AuthProvider>().user?.id;
      if (_lastRemotePlayback != null &&
          _lastRemotePlayback!.isPlaying &&
          _lastRemotePlayback!.updatedBy != myUid) {
        final nowServer = WatchTogetherService.instance.currentServerTime;
        final expectedMs =
            _lastRemotePlayback!.positionMs + (nowServer - _lastRemotePlayback!.updatedAt);
        final currentMs = _currentPosition.inMilliseconds;
        final diff = (currentMs - expectedMs).abs();

        // If drift exceeds 1500 milliseconds, quietly correct to expected position
        if (diff > 1500) {
          setState(() {
            _syncStatus = SyncStatus.syncing;
          });
          _playerSeekTo(Duration(milliseconds: expectedMs));
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
      speed: _currentSpeed,
    );

    WatchTogetherService.instance.updatePlayback(
      roomCode: widget.roomCode,
      uid: myUid,
      isPlaying: isPlaying,
      positionMs: positionMs,
      speed: _currentSpeed,
      buffering: false,
    );
  }

  void _togglePlayPause() {
    if (!_isInitialized) return;
    HapticFeedback.lightImpact();

    if (_currentIsPlaying) {
      _playerPause();
      _sendPlaybackAction(
        isPlaying: false,
        positionMs: _currentPosition.inMilliseconds,
      );
    } else {
      _playerPlay();
      _sendPlaybackAction(
        isPlaying: true,
        positionMs: _currentPosition.inMilliseconds,
      );
    }
    setState(() {});
  }

  void _seek(Duration position) {
    if (!_isInitialized) return;
    HapticFeedback.lightImpact();

    _targetSkipPosition = position;
    _playerSeekTo(position);

    _skipDebounceTimer?.cancel();
    _skipDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      _targetSkipPosition = null;
    });

    _sendPlaybackAction(
      isPlaying: _currentIsPlaying,
      positionMs: position.inMilliseconds,
    );
    setState(() {});
  }

  void _skip10Seconds(bool forward) {
    if (!_isInitialized) return;
    HapticFeedback.lightImpact();

    final base = _targetSkipPosition ?? _currentPosition;
    final target = forward
        ? base + const Duration(seconds: 10)
        : base - const Duration(seconds: 10);

    final dur = _currentDuration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (dur > Duration.zero && target > dur ? dur : target);

    _targetSkipPosition = clamped;
    _playerSeekTo(clamped);

    _skipDebounceTimer?.cancel();
    _skipDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      _targetSkipPosition = null;
    });

    _sendPlaybackAction(
      isPlaying: _currentIsPlaying,
      positionMs: clamped.inMilliseconds,
    );
    setState(() {});
  }

  void _startSpeedUp() {
    if (!_isInitialized || _isLeaving) return;
    HapticFeedback.mediumImpact();
    _playerSetSpeed(2.0);
    _ignoreRemoteUntil = DateTime.now().add(const Duration(seconds: 10));
    setState(() {
      _isFastForwarding = true;
    });
  }

  void _stopSpeedUp() {
    if (!_isInitialized || _isLeaving) return;
    HapticFeedback.lightImpact();
    _playerSetSpeed(1.0);
    setState(() {
      _isFastForwarding = false;
    });
    _sendPlaybackAction(
      isPlaying: _currentIsPlaying,
      positionMs: _currentPosition.inMilliseconds,
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

    final label = switch (_aspectRatioLabel) {
      'Zoom' => 'Zoom (Crop to Fill Screen) 🔍',
      'Stretch' => 'Stretch (Edge-to-Edge) ↔️',
      _ => 'Fit (Original 16:9) 📐',
    };
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label),
        backgroundColor: Colors.black87,
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          if (!_hasSavedTicketStub)
            TextButton.icon(
              onPressed: () async {
                await _saveTicketStubToMemories('');
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  await _leavePlayerAndRoom();
                }
              },
              icon: const Icon(Icons.confirmation_number_outlined, size: 16, color: Colors.amber),
              label: const Text('Save Ticket & Leave', style: TextStyle(color: Colors.amber)),
            ),
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
      await _playerPause();
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

  Future<void> _saveTicketStubToMemories(String reactionNote) async {
    if (_hasSavedTicketStub) return;
    final authProv = context.read<AuthProvider>();
    final memProv = context.read<MemoriesProvider>();
    final spaceId = authProv.space?.id ?? '';
    final user = authProv.user;
    if (spaceId.isEmpty || user == null) return;

    final dur = _currentDuration;
    final durMins = dur.inMinutes;
    final durationLabel = durMins > 0 ? '${durMins}m' : 'Movie Night';
    final cleanNote = reactionNote.trim();
    final posterUrl = (widget.youtubeId != null && widget.youtubeId!.isNotEmpty)
        ? 'https://img.youtube.com/vi/${widget.youtubeId}/hqdefault.jpg'
        : '';

    final caption = 'Cinema Ticket Stub • $durationLabel • Watched Together 🍿'
        '${cleanNote.isNotEmpty ? '\n"$cleanNote"' : ''}';

    await memProv.addMemory(
      spaceId: spaceId,
      title: '🎟️ ${widget.movieTitle}',
      caption: caption,
      mediaUrl: posterUrl,
      author: user.nickname,
      currentUserId: user.id,
      partnerNickname: authProv.partner?.nickname,
    );

    if (mounted) {
      setState(() {
        _hasSavedTicketStub = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cinema Ticket Stub saved to Memories 🎟️'),
          backgroundColor: AppColors.sage,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Screen 4: Movie Ended View
  void _showMovieEndedDialog() {
    String noteDraft = '';
    bool savingTicket = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
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
                const Text('🎉', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 10),
                const Text(
                  'Movie Night Complete',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.movieTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                if (!_hasSavedTicketStub) ...[
                  TextField(
                    onChanged: (val) => noteDraft = val,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 12.5, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a quick note for your ticket stub (optional)...',
                      hintStyle: const TextStyle(fontSize: 11.5, color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: savingTicket
                          ? null
                          : () async {
                              setDialogState(() => savingTicket = true);
                              await _saveTicketStubToMemories(noteDraft);
                              setDialogState(() => savingTicket = false);
                            },
                      icon: const Icon(Icons.confirmation_number_rounded, size: 17),
                      label: Text(
                        savingTicket ? 'Saving Ticket...' : 'Save Ticket Stub to Memories',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sage,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.sage.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.sage.withOpacity(0.5)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: AppColors.sageLight),
                        SizedBox(width: 6),
                        Text(
                          'Ticket Stub Saved to Memories 🎟️',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.sageLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Watch Another Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
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
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _heartbeatTimer?.cancel();
    _connectedSub?.cancel();
    if (_callStatusListener != null) {
      WatchCallService.instance.callStatus.removeListener(_callStatusListener!);
    }
    _playbackSub?.cancel();
    _roomSub?.cancel();
    _chatSub?.cancel();
    _messageCountSub?.cancel();
    _driftCheckTimer?.cancel();
    _skipDebounceTimer?.cancel();
    _quickToastTimer?.cancel();
    WatchCallService.instance.dispose();
    if (_hasController) {
      _hasController = false;
      try {
        _controller.removeListener(_videoPlayerListener);
      } catch (_) {}
      try {
        _controller.dispose();
      } catch (_) {}
    }

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
                ElevatedButton.icon(
                  onPressed: _retryStreamLoad,
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                  label: const Text('Retry Stream', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    final myUid = context.read<AuthProvider>().user?.id;
                    if (myUid != null) {
                      await WatchTogetherService.instance.updateMemberReady(
                        roomCode: widget.roomCode,
                        uid: myUid,
                        ready: false,
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.terra),
                  child: const Text('Change Movie / Waiting Room', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.terra),
              const SizedBox(height: 18),
              Text(
                widget.videoType == 'youtube'
                    ? 'Connecting to YouTube Cinema stream...'
                    : (widget.videoType == 'web_url' ? 'Connecting to Web Stream...' : 'Preparing video player...'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.movieTitle,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'No download needed • Live sync for two 🍿',
                  style: TextStyle(fontSize: 10.5, color: Colors.white70),
                ),
              ),
            ],
          ),
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
                      child: _buildVideoStage(myUid: myUid, myName: myName, partnerAvatarUrl: partnerAvatarUrl),
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
                    Positioned.fill(
                      child: _buildVideoStage(myUid: myUid, myName: myName, partnerAvatarUrl: partnerAvatarUrl),
                    ),
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

  /// Shared video viewport + reactions + synced controls for both Native ExoPlayer and WebView Cinema Mode.
  Widget _buildVideoStage({
    required String myUid,
    required String myName,
    required String partnerAvatarUrl,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: _isWebViewMode && _webController != null
              ? WebViewWidget(controller: _webController!)
              : SizedBox.expand(
                  child: FittedBox(
                    fit: _videoFit,
                    clipBehavior: Clip.hardEdge,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: _hasController && _controller.value.size.width > 0
                          ? _controller.value.size.width
                          : 16,
                      height: _hasController && _controller.value.size.height > 0
                          ? _controller.value.size.height
                          : 9,
                      child: _hasController ? VideoPlayer(_controller) : const SizedBox.shrink(),
                    ),
                  ),
                ),
        ),
        // Floating Reactions over Video
        WatchFloatingReactions(key: _reactionsKey),
        // Fast Forward 2X HUD
        _buildFastForwardIndicator(),
        // Controls Overlay (disabled only when user explicitly enables touch-through to tap inside a web player)
        if (!_wvTouchThrough)
          ValueListenableBuilder<WatchCallStatus>(
            valueListenable: WatchCallService.instance.callStatus,
            builder: (context, callStatus, _) {
              final isCallActive = callStatus == WatchCallStatus.connected ||
                  callStatus == WatchCallStatus.calling;
              return WatchControlsOverlay(
                isPlaying: _currentIsPlaying,
                position: _currentPosition,
                duration: _currentDuration,
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
                onToggleAspectRatio: _isWebViewMode ? null : _toggleAspectRatio,
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
        // In WebView Cinema mode, give a small pill to toggle direct page touch vs Watch Together overlay
        if (_isWebViewMode)
          Positioned(
            bottom: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => setState(() => _wvTouchThrough = !_wvTouchThrough),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _wvTouchThrough ? Icons.tune_rounded : Icons.touch_app_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _wvTouchThrough ? 'Sync Controls' : 'Tap Video',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Quick notification toast over video
        _buildQuickToast(partnerAvatarUrl),
      ],
    );
  }
}
