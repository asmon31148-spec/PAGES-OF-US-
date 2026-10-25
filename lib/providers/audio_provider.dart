import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/music/models/music_models.dart';

class AudioProvider extends ChangeNotifier {
  // -------------------------------------------------------------
  // 1. SONGS & PLAYLIST STATE
  // -------------------------------------------------------------
  final AudioPlayer _songPlayer = AudioPlayer();
  AudioPlayer? _crossfadePlayer;

  Source _resolveSource(String path, {bool isLocal = false}) {
    if (isLocal) {
      return DeviceFileSource(path);
    } else if (path.startsWith('audio/') || path.startsWith('assets/')) {
      final assetPath = path.startsWith('assets/') ? path.substring(7) : path;
      return AssetSource(assetPath);
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      return UrlSource(path);
    } else {
      return DeviceFileSource(path);
    }
  }

  final List<SongItem> _songs = [
    SongItem(
      id: 'song_1',
      title: 'Slow Morning',
      artist: 'Sanctuary Beats · Built-in',
      durationSeconds: 222, // 3:42
      audioUrl: 'audio/lofi_sanctuary.mp3',
      coverColor: const Color(0xFF86EFAC),
      addedBy: 'Sanctuary',
    ),
    SongItem(
      id: 'song_2',
      title: 'Rainy Window',
      artist: 'Aarav Mehta',
      durationSeconds: 178, // 2:58
      audioUrl:
          'https://raw.githubusercontent.com/rafaelreis-hotmart/Audio-Sample-files/master/sample.mp3',
      coverColor: const Color(0xFF2DD4BF),
      addedBy: 'Sam',
    ),
    SongItem(
      id: 'song_3',
      title: 'Night Garden',
      artist: 'Mira Das',
      durationSeconds: 250, // 4:10
      audioUrl:
          'https://raw.githubusercontent.com/rafaelreis-hotmart/Audio-Sample-files/master/sample2.mp3',
      coverColor: const Color(0xFFF97316),
      addedBy: 'You',
    ),
    SongItem(
      id: 'song_4',
      title: 'Paper Boats',
      artist: 'Aarav Mehta',
      durationSeconds: 195, // 3:15
      audioUrl: 'audio/breeze.mp3',
      coverColor: const Color(0xFF9CE658),
      addedBy: 'Aarav Mehta',
    ),
    SongItem(
      id: 'song_5',
      title: 'Calm Sanctuary',
      artist: 'Sanctuary Duo',
      durationSeconds: 210, // 3:30
      audioUrl: 'audio/rain.mp3',
      coverColor: const Color(0xFF34D399),
      addedBy: 'Sanctuary',
    ),
  ];

  final List<PlaylistItem> _playlists = [
    PlaylistItem(
      id: 'pl_1',
      title: 'Calm evenings',
      coverColor: const Color(0xFF2DD4BF),
      songIds: ['song_1', 'song_2', 'song_3', 'song_4'],
    ),
    PlaylistItem(
      id: 'pl_2',
      title: 'Night Sanctuary',
      coverColor: const Color(0xFFF97316),
      songIds: ['song_3', 'song_2'],
    ),
  ];

  int _currentSongIndex = 0;
  bool _isSongPlaying = false;
  Duration _songPosition = Duration.zero;
  Duration _songDuration = const Duration(minutes: 3, seconds: 42);
  bool _isShuffle = false;
  bool _allowBackgroundPlayback = false;

  // -------------------------------------------------------------
  // 2. LISTEN TOGETHER (PARTNER SYNC)
  // -------------------------------------------------------------
  bool _isListenTogetherActive = false;
  String _listenController = 'both'; // 'both' or 'me'
  String _syncSpaceId = '';
  RealtimeChannel? _syncChannel;
  bool _ignoreIncomingSync = false;

  // -------------------------------------------------------------
  // 3. ATMOSPHERE SOUNDSCAPES MULTI-TRACK MIXER
  // -------------------------------------------------------------
  final Map<String, AudioPlayer> _stemPlayers = {
    'rain': AudioPlayer(),
    'birds': AudioPlayer(),
    'wind': AudioPlayer(),
    'ocean': AudioPlayer(),
    'fire': AudioPlayer(),
  };

  final Map<String, AtmosphereStem> _atmosphereStems = {
    'rain': AtmosphereStem(
      id: 'rain',
      title: 'Rain',
      icon: Icons.water_drop_outlined,
      audioUrl: 'audio/rain.mp3',
      iconColor: const Color(0xFF2DD4BF),
      volume: 0.70,
    ),
    'birds': AtmosphereStem(
      id: 'birds',
      title: 'Birds',
      icon: Icons.eco_outlined,
      audioUrl: 'audio/birds.mp3',
      iconColor: const Color(0xFF86EFAC),
      volume: 0.30,
    ),
    'wind': AtmosphereStem(
      id: 'wind',
      title: 'Wind',
      icon: Icons.air_rounded,
      audioUrl: 'audio/breeze.mp3',
      iconColor: const Color(0xFF38BDF8),
      volume: 0.20,
    ),
    'ocean': AtmosphereStem(
      id: 'ocean',
      title: 'Ocean waves',
      icon: Icons.waves_rounded,
      audioUrl: 'audio/ocean.mp3',
      iconColor: const Color(0xFF60A5FA),
      volume: 0.0,
    ),
    'fire': AtmosphereStem(
      id: 'fire',
      title: 'Fire crackle',
      icon: Icons.local_fire_department_outlined,
      audioUrl: 'audio/fireplace.mp3',
      iconColor: const Color(0xFFFB923C),
      volume: 0.0,
    ),
  };

  double _masterAtmosphereVolume = 0.65;
  bool _isAtmospherePlaying = false;
  String _activePreset = 'Calm';

  // -------------------------------------------------------------
  // 4. DUCKING FOR MEDIA (WHISPERS / LIGHTBOX)
  // -------------------------------------------------------------
  bool _wasSongPlayingBeforeDuck = false;
  bool _wasAtmospherePlayingBeforeDuck = false;

  // -------------------------------------------------------------
  // GETTERS
  // -------------------------------------------------------------
  List<SongItem> get songs => List.unmodifiable(_songs);
  List<PlaylistItem> get playlists => List.unmodifiable(_playlists);
  int get currentSongIndex => _currentSongIndex;
  SongItem get currentSong => _songs[_currentSongIndex];
  bool get isSongPlaying => _isSongPlaying;
  bool get isPlaying => _isSongPlaying || _isAtmospherePlaying;
  String get currentTrackTitle => currentSong.title;
  Duration get songPosition => _songPosition;
  Duration get songDuration => _songDuration;
  bool get isShuffle => _isShuffle;
  bool get allowBackgroundPlayback => _allowBackgroundPlayback;

  bool get isListenTogetherActive => _isListenTogetherActive;
  String get listenController => _listenController;

  Map<String, AtmosphereStem> get atmosphereStems => _atmosphereStems;
  double get masterAtmosphereVolume => _masterAtmosphereVolume;
  bool get isAtmospherePlaying => _isAtmospherePlaying;
  String get activePreset => _activePreset;

  AudioProvider() {
    _initSongListeners();
    _initAtmospherePlayers();
  }

  void _initSongListeners() {
    // Configure audio focus so it auto-pauses when other apps or phone calls play audio
    _songPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.duckOthers},
        ),
      ),
    );

    _songPlayer.onPositionChanged.listen((pos) {
      _songPosition = pos;
      notifyListeners();
    });

    _songPlayer.onDurationChanged.listen((dur) {
      if (dur.inSeconds > 0) {
        _songDuration = dur;
        notifyListeners();
      }
    });

    // Auto-advance with smooth crossfade
    _songPlayer.onPlayerComplete.listen((_) {
      playNextWithCrossfade();
    });
  }

  void _initAtmospherePlayers() {
    for (final entry in _stemPlayers.entries) {
      entry.value.setReleaseMode(ReleaseMode.loop);
      entry.value.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false, // In-app only!
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
          ),
        ),
      );
    }
  }

  // -------------------------------------------------------------
  // SONG CONTROLS & SMOOTH CROSSFADE
  // -------------------------------------------------------------
  Future<void> toggleSongPlay() async {
    if (_isSongPlaying) {
      await pauseSong();
    } else {
      await resumeSong();
    }
  }

  Future<void> resumeSong() async {
    try {
      if (_songPosition == Duration.zero ||
          _songPlayer.state == PlayerState.stopped ||
          _songPlayer.state == PlayerState.completed) {
        final src = _resolveSource(currentSong.audioUrl, isLocal: currentSong.isLocal);
        await _songPlayer.play(src);
      } else {
        await _songPlayer.resume();
      }
      _isSongPlaying = true;
      notifyListeners();
      _broadcastSync('PLAY', _songPosition.inSeconds);
    } catch (e) {
      debugPrint('resumeSong error: $e');
    }
  }

  Future<void> pauseSong() async {
    try {
      await _songPlayer.pause();
      _isSongPlaying = false;
      notifyListeners();
      _broadcastSync('PAUSE', _songPosition.inSeconds);
    } catch (_) {}
  }

  Future<void> selectSong(int index) async {
    if (index < 0 || index >= _songs.length) return;
    _currentSongIndex = index;
    _songPosition = Duration.zero;
    _songDuration = Duration(seconds: _songs[index].durationSeconds);
    await _playCurrentSongWithCrossfade();
    notifyListeners();
    _broadcastSync('SELECT', 0);
  }

  Future<void> nextSong() async {
    if (_isShuffle) {
      _currentSongIndex = Random().nextInt(_songs.length);
    } else {
      _currentSongIndex = (_currentSongIndex + 1) % _songs.length;
    }
    await selectSong(_currentSongIndex);
  }

  Future<void> prevSong() async {
    if (_songPosition.inSeconds > 3) {
      await seekSong(Duration.zero);
    } else {
      _currentSongIndex = (_currentSongIndex - 1 + _songs.length) % _songs.length;
      await selectSong(_currentSongIndex);
    }
  }

  Future<void> seekSong(Duration position) async {
    await _songPlayer.seek(position);
    _songPosition = position;
    notifyListeners();
    _broadcastSync('SEEK', position.inSeconds);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleBackgroundPlayback() {
    _allowBackgroundPlayback = !_allowBackgroundPlayback;
    notifyListeners();
  }

  /// Smooth crossfade between songs (fade-out old, fade-in new)
  Future<void> _playCurrentSongWithCrossfade() async {
    try {
      final targetSource = _resolveSource(currentSong.audioUrl, isLocal: currentSong.isLocal);

      // 1. Fade out current player smoothly if playing
      if (_songPlayer.state == PlayerState.playing) {
        for (double v = 1.0; v >= 0.0; v -= 0.25) {
          await _songPlayer.setVolume(v);
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }
      await _songPlayer.stop();

      // 2. Start at volume 0
      await _songPlayer.setVolume(0.0);
      await _songPlayer.play(targetSource);
      _isSongPlaying = true;

      // 3. Fade in smoothly
      for (double v = 0.1; v <= 1.0; v += 0.15) {
        await _songPlayer.setVolume(v);
        await Future.delayed(const Duration(milliseconds: 25));
      }
      await _songPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint('Crossfade error: $e, falling back to direct play');
      try {
        await _songPlayer.setVolume(1.0);
        await _songPlayer.play(_resolveSource(currentSong.audioUrl, isLocal: currentSong.isLocal));
        _isSongPlaying = true;
      } catch (err) {
        debugPrint('Direct play fallback error: $err');
      }
    }
  }

  Future<void> playNextWithCrossfade() async {
    await nextSong();
  }

  void addCustomSong(SongItem song) {
    _songs.add(song);
    notifyListeners();
  }

  void deleteSong(String id) {
    if (_songs.length <= 1) return; // Keep at least one
    final idx = _songs.indexWhere((s) => s.id == id);
    if (idx != -1) {
      _songs.removeAt(idx);
      if (_currentSongIndex >= _songs.length) {
        _currentSongIndex = 0;
      }
      notifyListeners();
    }
  }

  // -------------------------------------------------------------
  // PLAYLIST MANAGEMENT
  // -------------------------------------------------------------
  void createPlaylist(String title, List<String> songIds, {Color? coverColor}) {
    final pl = PlaylistItem(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      coverColor: coverColor ?? const Color(0xFF2DD4BF),
      songIds: songIds,
    );
    _playlists.add(pl);
    notifyListeners();
  }

  void deletePlaylist(String id) {
    _playlists.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void addSongToPlaylist(String playlistId, String songId) {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      if (!_playlists[idx].songIds.contains(songId)) {
        _playlists[idx].songIds.add(songId);
        notifyListeners();
      }
    }
  }

  void removeSongFromPlaylist(String playlistId, String songId) {
    final pl = _playlists.firstWhere((p) => p.id == playlistId, orElse: () => _playlists.first);
    pl.songIds.remove(songId);
    notifyListeners();
  }

  // -------------------------------------------------------------
  // ATMOSPHERE SOUNDSCAPES MULTI-STEM MIXER
  // -------------------------------------------------------------
  Future<void> toggleAtmospherePlay() async {
    if (_isAtmospherePlaying) {
      await pauseAtmosphere();
    } else {
      await resumeAtmosphere();
    }
  }

  Future<void> resumeAtmosphere() async {
    _isAtmospherePlaying = true;
    notifyListeners();

    for (final stemId in _atmosphereStems.keys) {
      final stem = _atmosphereStems[stemId]!;
      final player = _stemPlayers[stemId]!;
      final effectiveVolume = stem.volume * _masterAtmosphereVolume;

      if (effectiveVolume > 0.01) {
        try {
          await player.setVolume(effectiveVolume);
          if (player.state != PlayerState.playing) {
            await player.play(_resolveSource(stem.audioUrl));
          }
        } catch (e) {
          debugPrint('Error playing stem $stemId: $e');
        }
      } else {
        if (player.state == PlayerState.playing) {
          await player.pause();
        }
      }
    }
  }

  Future<void> pauseAtmosphere() async {
    _isAtmospherePlaying = false;
    notifyListeners();

    for (final player in _stemPlayers.values) {
      try {
        await player.pause();
      } catch (_) {}
    }
  }

  void setStemVolume(String stemId, double volume) {
    final stem = _atmosphereStems[stemId];
    if (stem == null) return;

    stem.volume = volume.clamp(0.0, 1.0);
    _activePreset = 'Custom';
    notifyListeners();

    if (_isAtmospherePlaying) {
      final player = _stemPlayers[stemId];
      final effective = stem.volume * _masterAtmosphereVolume;
      if (effective > 0.01) {
        player?.setVolume(effective);
        if (player?.state != PlayerState.playing) {
          player?.play(_resolveSource(stem.audioUrl));
        }
      } else {
        if (player?.state == PlayerState.playing) {
          player?.pause();
        }
      }
    }
  }

  void setMasterVolume(double volume) {
    _masterAtmosphereVolume = volume.clamp(0.0, 1.0);
    notifyListeners();

    if (_isAtmospherePlaying) {
      for (final stemId in _atmosphereStems.keys) {
        final stem = _atmosphereStems[stemId]!;
        final player = _stemPlayers[stemId]!;
        final effective = stem.volume * _masterAtmosphereVolume;
        if (effective > 0.01) {
          player.setVolume(effective);
          if (player.state != PlayerState.playing) {
            player.play(_resolveSource(stem.audioUrl));
          }
        } else {
          if (player.state == PlayerState.playing) {
            player.pause();
          }
        }
      }
    }
  }

  void applyPreset(String preset) {
    _activePreset = preset;
    switch (preset) {
      case 'Calm':
        _atmosphereStems['rain']!.volume = 0.70;
        _atmosphereStems['birds']!.volume = 0.30;
        _atmosphereStems['wind']!.volume = 0.20;
        _atmosphereStems['ocean']!.volume = 0.0;
        _atmosphereStems['fire']!.volume = 0.0;
        break;
      case 'Soft':
        _atmosphereStems['rain']!.volume = 0.40;
        _atmosphereStems['birds']!.volume = 0.50;
        _atmosphereStems['wind']!.volume = 0.10;
        _atmosphereStems['ocean']!.volume = 0.0;
        _atmosphereStems['fire']!.volume = 0.0;
        break;
      case 'Peace':
        _atmosphereStems['rain']!.volume = 0.20;
        _atmosphereStems['birds']!.volume = 0.20;
        _atmosphereStems['wind']!.volume = 0.30;
        _atmosphereStems['ocean']!.volume = 0.50;
        _atmosphereStems['fire']!.volume = 0.0;
        break;
      case 'Deep sleep':
        _atmosphereStems['rain']!.volume = 0.80;
        _atmosphereStems['birds']!.volume = 0.0;
        _atmosphereStems['wind']!.volume = 0.20;
        _atmosphereStems['ocean']!.volume = 0.0;
        _atmosphereStems['fire']!.volume = 0.30;
        break;
      case 'Auto mix':
        _atmosphereStems['rain']!.volume = 0.50;
        _atmosphereStems['birds']!.volume = 0.40;
        _atmosphereStems['wind']!.volume = 0.30;
        _atmosphereStems['ocean']!.volume = 0.20;
        _atmosphereStems['fire']!.volume = 0.15;
        break;
    }
    notifyListeners();

    if (_isAtmospherePlaying) {
      resumeAtmosphere();
    }
  }

  /// Called when user leaves the app: strictly stop atmosphere natural sounds!
  void stopAtmosphereOnExit() {
    pauseAtmosphere();
  }

  // -------------------------------------------------------------
  // LISTEN TOGETHER (REALTIME SUPABASE BROADCAST)
  // -------------------------------------------------------------
  void startListenTogether(String spaceId) {
    _isListenTogetherActive = true;
    _syncSpaceId = spaceId;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      _syncChannel = supabase.channel('music_sync_$spaceId');
      _syncChannel!.onBroadcast(
        event: 'playback_update',
        callback: (payload) {
          if (_ignoreIncomingSync) return;
          final type = payload['type'] as String?;
          final songIndex = payload['songIndex'] as int?;
          final positionSec = payload['positionSec'] as int?;

          if (songIndex != null && songIndex != _currentSongIndex) {
            _currentSongIndex = songIndex;
          }

          if (type == 'PLAY') {
            _isSongPlaying = true;
            _songPlayer.play(_resolveSource(currentSong.audioUrl, isLocal: currentSong.isLocal));
          } else if (type == 'PAUSE') {
            _isSongPlaying = false;
            _songPlayer.pause();
          } else if (type == 'SEEK' && positionSec != null) {
            _songPlayer.seek(Duration(seconds: positionSec));
          }
          notifyListeners();
        },
      ).subscribe();
    } catch (_) {}
  }

  void endListenTogether() {
    _isListenTogetherActive = false;
    _syncChannel?.unsubscribe();
    _syncChannel = null;
    notifyListeners();
  }

  void setListenController(String mode) {
    _listenController = mode;
    notifyListeners();
  }

  void _broadcastSync(String type, int positionSec) {
    if (!_isListenTogetherActive || _syncChannel == null) return;
    try {
      _ignoreIncomingSync = true;
      _syncChannel!.sendBroadcastMessage(
        event: 'playback_update',
        payload: {
          'type': type,
          'songIndex': _currentSongIndex,
          'positionSec': positionSec,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      Future.delayed(const Duration(milliseconds: 300), () {
        _ignoreIncomingSync = false;
      });
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // DUCKING FOR MEDIA & TOP BAR QUICK TOGGLE
  // -------------------------------------------------------------
  Future<void> toggleMusic() async {
    // Legacy top bar quick action: toggles current active audio
    if (_isSongPlaying) {
      await pauseSong();
    } else {
      await resumeSong();
    }
  }

  void duckForMedia() {
    if (_isSongPlaying) {
      _wasSongPlayingBeforeDuck = true;
      _songPlayer.pause();
      _isSongPlaying = false;
    }
    if (_isAtmospherePlaying) {
      _wasAtmospherePlayingBeforeDuck = true;
      pauseAtmosphere();
    }
    notifyListeners();
  }

  void restoreFromMedia() {
    if (_wasSongPlayingBeforeDuck) {
      resumeSong();
      _wasSongPlayingBeforeDuck = false;
    }
    if (_wasAtmospherePlayingBeforeDuck) {
      resumeAtmosphere();
      _wasAtmospherePlayingBeforeDuck = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _songPlayer.dispose();
    _crossfadePlayer?.dispose();
    for (final p in _stemPlayers.values) {
      p.dispose();
    }
    _syncChannel?.unsubscribe();
    super.dispose();
  }
}
