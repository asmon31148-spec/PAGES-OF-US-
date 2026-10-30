import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../providers/audio_provider.dart';
import 'audio_cache_service.dart';

/// Unified Voice Audio Playback Service for Pages of Us
/// Coordinates all voice notes across Memories, Vault, Timeline, and Preview screens.
/// Guarantees that only ONE voice audio plays at a time, ducks ambient background
/// audio smoothly, and provides 60 FPS position scrubbing without UI jank.
class VoicePlaybackService extends ChangeNotifier {
  static final VoicePlaybackService instance = VoicePlaybackService._internal();

  VoicePlaybackService._internal() {
    _initListeners();
  }

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  int _sessionId = 0;
  String? _activeId;
  String? _activeUrl;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isBuffering = false;

  AudioProvider? _ambientAudio;

  /// Dedicated 60 FPS notifier for isolated waveform scrubbing without widget rebuilds
  final ValueNotifier<Duration> positionNotifier = ValueNotifier<Duration>(Duration.zero);

  String? get activeId => _activeId;
  String? get activeUrl => _activeUrl;
  PlayerState get playerState => _playerState;
  bool get isPlaying => _playerState == PlayerState.playing;
  bool get isPaused => _playerState == PlayerState.paused;
  bool get isBuffering => _isBuffering;
  Duration get position => _position;
  Duration get duration => _duration;
  double get playbackSpeed => _playbackSpeed;

  void _initListeners() {
    _posSub = _player.onPositionChanged.listen((pos) {
      if (_playerState == PlayerState.playing) {
        _position = pos;
        positionNotifier.value = pos;
        if (_duration.inMilliseconds > 0 && pos > _duration) {
          _duration = pos;
        }
      }
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (dur.inMilliseconds > 0 && dur != _duration) {
        _duration = dur;
        notifyListeners();
      }
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        _playerState = PlayerState.stopped;
        _position = Duration.zero;
        positionNotifier.value = Duration.zero;
        _activeId = null;
        _ambientAudio?.restoreFromMedia();
        notifyListeners();
      }
    });
  }

  /// Toggle play / pause on a voice note
  Future<void> togglePlay({
    required String id,
    required String url,
    int? durationSeconds,
    AudioProvider? ambientAudio,
  }) async {
    if (_activeId == id) {
      if (isPlaying) {
        await pause();
      } else if (isPaused) {
        await resume();
      } else {
        await play(
          id: id,
          url: url,
          durationSeconds: durationSeconds,
          ambientAudio: ambientAudio,
        );
      }
    } else {
      await play(
        id: id,
        url: url,
        durationSeconds: durationSeconds,
        ambientAudio: ambientAudio,
      );
    }
  }

  /// Starts playback of a voice note
  Future<void> play({
    required String id,
    required String url,
    int? durationSeconds,
    AudioProvider? ambientAudio,
  }) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;

    _ambientAudio = ambientAudio;
    _ambientAudio?.duckForMedia();

    final currentSession = ++_sessionId;

    // Immediately reflect active note in UI (0ms delay)
    _activeId = id;
    _activeUrl = cleanUrl;
    _position = Duration.zero;
    positionNotifier.value = Duration.zero;
    _duration = (durationSeconds != null && durationSeconds > 0)
        ? Duration(seconds: durationSeconds)
        : Duration.zero;
    _playerState = PlayerState.playing;
    _isBuffering = true;
    notifyListeners();

    try {
      // 1. Stop any currently playing audio safely
      await _player.stop();

      // Check if another play request intervened
      if (_sessionId != currentSession) return;

      // 2. Resolve audio source (Local file, Asset, or Stream)
      Source source;
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        final filePath = cleanUrl.replaceFirst('file://', '');
        source = DeviceFileSource(filePath);
      } else {
        // Check if already cached on local disk for instant offline zero-buffer playback
        final isDiskCached = await AudioCacheService.isCached(cleanUrl);
        if (isDiskCached) {
          final localPath = await AudioCacheService.getCachedAudioPath(cleanUrl);
          source = DeviceFileSource(localPath);
        } else {
          // Stream directly from remote URL with 0ms pre-wait
          source = UrlSource(cleanUrl);
          // Silently cache in background for next time
          AudioCacheService.prefetchList([cleanUrl]);
        }
      }

      if (_sessionId != currentSession) return;

      await _player.setPlaybackRate(_playbackSpeed);
      await _player.play(source);

      _isBuffering = false;
      notifyListeners();

      // 3. Query native player duration if not known from metadata
      if (_duration.inMilliseconds == 0) {
        final d = await _player.getDuration();
        if (d != null && d.inMilliseconds > 0 && _sessionId == currentSession) {
          _duration = d;
          notifyListeners();
        } else {
          // Retry duration fetch after short buffer window
          Future.delayed(const Duration(milliseconds: 350), () async {
            if (_sessionId == currentSession && _duration.inMilliseconds == 0) {
              try {
                final delayedDur = await _player.getDuration();
                if (delayedDur != null && delayedDur.inMilliseconds > 0) {
                  _duration = delayedDur;
                  notifyListeners();
                }
              } catch (_) {}
            }
          });
        }
      }
    } catch (e) {
      debugPrint('VoicePlaybackService play error: $e');
      if (_sessionId == currentSession) {
        _isBuffering = false;
        _playerState = PlayerState.stopped;
        _activeId = null;
        _ambientAudio?.restoreFromMedia();
        notifyListeners();
      }
    }
  }

  /// Pauses currently playing voice note
  Future<void> pause() async {
    try {
      await _player.pause();
      _playerState = PlayerState.paused;
      _ambientAudio?.restoreFromMedia();
      notifyListeners();
    } catch (_) {}
  }

  /// Resumes playback
  Future<void> resume() async {
    try {
      _ambientAudio?.duckForMedia();
      _playerState = PlayerState.playing;
      notifyListeners();
      await _player.resume();
    } catch (_) {}
  }

  /// Seeks to a specific target position
  Future<void> seek(Duration target) async {
    try {
      _position = target;
      positionNotifier.value = target;
      await _player.seek(target);
      notifyListeners();
    } catch (_) {}
  }

  /// Stops voice playback completely
  Future<void> stop() async {
    _sessionId++;
    try {
      await _player.stop();
    } catch (_) {}
    _activeId = null;
    _activeUrl = null;
    _playerState = PlayerState.stopped;
    _position = Duration.zero;
    positionNotifier.value = Duration.zero;
    _ambientAudio?.restoreFromMedia();
    notifyListeners();
  }

  /// Toggles playback speed (1.0x -> 1.5x -> 2.0x -> 1.0x)
  Future<void> togglePlaybackSpeed() async {
    if (_playbackSpeed == 1.0) {
      _playbackSpeed = 1.5;
    } else if (_playbackSpeed == 1.5) {
      _playbackSpeed = 2.0;
    } else {
      _playbackSpeed = 1.0;
    }
    await _player.setPlaybackRate(_playbackSpeed);
    notifyListeners();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    positionNotifier.dispose();
    super.dispose();
  }
}
