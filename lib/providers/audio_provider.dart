import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/music/models/music_models.dart';
import '../core/services/youtube_music_service.dart';
import '../core/services/music_download_service.dart';
import '../core/services/audio_handler.dart';
import '../core/services/local_cache_service.dart';
import '../data/services/firebase_service.dart';
import '../data/services/supabase_service.dart';
import 'auth_provider.dart';

class AudioProvider extends ChangeNotifier {
  final SanctuaryAudioHandler? audioHandler;

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

  static final List<SongItem> _defaultTemplateSongs = [];

  List<SongItem> _songs = [];
  final Set<String> _deletedSongIds = {};
  StreamSubscription? _musicCloudSub;
  StreamSubscription? _playlistFirebaseSub;

  final List<PlaylistItem> _playlists = [
    PlaylistItem(
      id: 'pl_1',
      title: 'Calm evenings',
      coverColor: const Color(0xFF2DD4BF),
      songIds: [],
    ),
    PlaylistItem(
      id: 'pl_2',
      title: 'Night Sanctuary',
      coverColor: const Color(0xFFF97316),
      songIds: [],
    ),
  ];

  int _currentSongIndex = 0;
  bool _isSongPlaying = false;
  bool _isSongBuffering = false;
  String? _bufferingSongTitle;
  String? _lastPlayError;
  Duration _songPosition = Duration.zero;
  final ValueNotifier<Duration> songPositionNotifier = ValueNotifier<Duration>(Duration.zero);
  Duration _songDuration = const Duration(minutes: 3, seconds: 42);
  bool _isShuffle = false;
  bool _isRepeatOne = false;
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
  List<SongItem> get upcomingSongs {
    if (_songs.isEmpty || _currentSongIndex >= _songs.length - 1) return [];
    return List.unmodifiable(_songs.sublist(_currentSongIndex + 1));
  }
  List<PlaylistItem> get playlists => List.unmodifiable(_playlists);
  int get currentSongIndex => _currentSongIndex;
  SongItem get currentSong {
    if (_songs.isEmpty) {
      return SongItem(
        id: 'empty',
        title: 'No songs in sanctuary',
        artist: 'Tap + above to add tracks',
        durationSeconds: 0,
        audioUrl: '',
        coverColor: const Color(0xFF2DD4BF),
      );
    }
    final safeIndex = _currentSongIndex.clamp(0, _songs.length - 1);
    return _songs[safeIndex];
  }
  bool get isSongPlaying => _isSongPlaying && _songs.isNotEmpty;
  bool get isSongBuffering => _isSongBuffering;
  String? get bufferingSongTitle => _bufferingSongTitle;
  String? get lastPlayError => _lastPlayError;
  void clearPlayError() => _lastPlayError = null;
  bool get isPlaying => (_isSongPlaying && _songs.isNotEmpty) || _isAtmospherePlaying;
  String get currentTrackTitle => currentSong.title;
  Duration get songPosition => _songPosition;
  Duration get songDuration => _songDuration;
  bool get isShuffle => _isShuffle;
  bool get isRepeatOne => _isRepeatOne;
  bool get allowBackgroundPlayback => _allowBackgroundPlayback;

  bool get isListenTogetherActive => _isListenTogetherActive;
  String get listenController => _listenController;

  Map<String, AtmosphereStem> get atmosphereStems => _atmosphereStems;
  double get masterAtmosphereVolume => _masterAtmosphereVolume;
  bool get isAtmospherePlaying => _isAtmospherePlaying;
  String get activePreset => _activePreset;

  AudioProvider({this.audioHandler}) {
    AuthProvider.registerSignOutHook(resetState);
    _loadPersistedSongs();
    _initHandlerCallbacks();
    _initSongListeners();
    _initAtmospherePlayers();
  }

  /// Wipes ALL audio player and music state when user logs out.
  void resetState() {
    _musicCloudSub?.cancel();
    _playlistFirebaseSub?.cancel();
    _syncChannel?.unsubscribe();
    _musicCloudSub = null;
    _playlistFirebaseSub = null;
    _syncChannel = null;
    _syncSpaceId = '';

    try { _songPlayer.stop(); } catch (_) {}
    pauseAtmosphere();

    _songs = [];
    _deletedSongIds.clear();
    _playlists.clear();
    _playlists.addAll([
      PlaylistItem(id: 'pl_1', title: 'Calm evenings', coverColor: const Color(0xFF2DD4BF), songIds: []),
      PlaylistItem(id: 'pl_2', title: 'Night Sanctuary', coverColor: const Color(0xFFF97316), songIds: []),
      PlaylistItem(id: 'pl_3', title: 'Road Trips', coverColor: const Color(0xFF6366F1), songIds: []),
    ]);
    _currentSongIndex = 0;
    _isSongPlaying = false;
    _isAtmospherePlaying = false;
    _songPosition = Duration.zero;
    _songDuration = Duration.zero;
    notifyListeners();
  }

  void _loadPersistedSongs() {
    try {
      final deleted = LocalCacheService.getCachedDeletedSongIds();
      _deletedSongIds.addAll(deleted);

      final cached = LocalCacheService.getCachedSongs();
      if (cached != null) {
        _songs = cached
            .map((e) => SongItem.fromJson(e))
            .where((s) => !_deletedSongIds.contains(s.id))
            .toList();
      } else {
        _songs = [];
      }

      final cachedPlaylists = LocalCacheService.getCachedPlaylists();
      if (cachedPlaylists != null) {
        _playlists.clear();
        _playlists.addAll(cachedPlaylists.map((e) => PlaylistItem.fromJson(e)));
      }

      // Clean up any stale/deleted song IDs from playlists
      for (final pl in _playlists) {
        pl.songIds.removeWhere((id) => !_songs.any((s) => s.id == id));
      }
    } catch (_) {
      _songs = [];
    }
  }

  void _initHandlerCallbacks() {
    if (audioHandler != null) {
      audioHandler!.onPlayCallback = resumeSong;
      audioHandler!.onPauseCallback = pauseSong;
      audioHandler!.onSkipNextCallback = nextSong;
      audioHandler!.onSkipPreviousCallback = prevSong;
      audioHandler!.onSeekCallback = seekSong;
    }
  }

  void _syncNotificationState() {
    if (audioHandler == null) return;
    if (_allowBackgroundPlayback || _isSongPlaying) {
      audioHandler!.updateSong(
        id: currentSong.id,
        title: currentSong.title,
        artist: currentSong.artist,
        duration: _songDuration,
        artUri: currentSong.thumbnailUrl != null ? Uri.tryParse(currentSong.thumbnailUrl!) : null,
      );
      audioHandler!.updatePlaybackState(
        isPlaying: _isSongPlaying,
        position: _songPosition,
        duration: _songDuration,
      );
    } else {
      audioHandler!.clearNotification();
    }
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

    // Strictly bind playing state to real player state!
    _songPlayer.onPlayerStateChanged.listen((state) {
      _isSongPlaying = state == PlayerState.playing;
      _applyAtmosphereVolumes(); // Smart ducking!
      _syncNotificationState(); // Status bar notification!
      notifyListeners();
    });

    _songPlayer.onPositionChanged.listen((pos) {
      _songPosition = pos;
      songPositionNotifier.value = pos;
      if (audioHandler != null && _isSongPlaying) {
        audioHandler!.updatePlaybackState(
          isPlaying: _isSongPlaying,
          position: pos,
          duration: _songDuration,
        );
      }
      // Zero UI jank: do NOT call notifyListeners() here to prevent entire app rebuild cascades!
    });

    _songPlayer.onDurationChanged.listen((dur) {
      if (dur.inSeconds > 0) {
        _songDuration = dur;
        _syncNotificationState();
        notifyListeners();
      }
    });

    // Auto-advance with smooth crossfade
    _songPlayer.onPlayerComplete.listen((_) {
      if (_isRepeatOne) {
        seekSong(Duration.zero);
        _songPlayer.resume();
      } else {
        playNextWithCrossfade();
      }
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
      _syncNotificationState();
      _broadcastSync('PLAY', _songPosition.inSeconds);
    } catch (e) {
      debugPrint('resumeSong error: $e');
    }
  }

  Future<void> pauseSong() async {
    try {
      await _songPlayer.pause();
      _syncNotificationState();
      _broadcastSync('PAUSE', _songPosition.inSeconds);
    } catch (_) {}
  }

  /// Plays a track from YouTube Music or local offline cache
  Future<void> playYoutubeTrack(YoutubeTrack track) async {
    _isSongBuffering = true;
    _bufferingSongTitle = track.title;
    _lastPlayError = null;
    notifyListeners();

    try {
      final localPath = MusicDownloadService.instance.getLocalFilePath(track.id);
      String audioUrl;
      bool isLocal = false;

      if (localPath != null && File(localPath).existsSync()) {
        audioUrl = localPath;
        isLocal = true;
      } else {
        final streamUrl = (track.audioStreamUrl != null && track.audioStreamUrl!.isNotEmpty)
            ? track.audioStreamUrl
            : await YoutubeMusicService.instance.getAudioStreamUrl(track.id);
        if (streamUrl == null || streamUrl.isEmpty) {
          debugPrint('[AudioProvider] Could not resolve audio stream for ${track.id}');
          _isSongBuffering = false;
          _bufferingSongTitle = null;
          _lastPlayError = 'Could not stream "${track.title}". Please try another track.';
          notifyListeners();
          return;
        }
        audioUrl = streamUrl;
        isLocal = false;
      }

      final newSong = SongItem(
        id: track.id,
        youtubeId: track.id,
        title: track.title,
        artist: track.artist,
        durationSeconds: track.durationSeconds,
        audioUrl: audioUrl,
        coverColor: const Color(0xFFD97706),
        isLocal: isLocal,
        addedBy: 'YouTube Music',
        thumbnailUrl: track.thumbnailUrl,
      );

      final existingIdx = _songs.indexWhere((s) => s.id == newSong.id || s.youtubeId == newSong.id);
      if (existingIdx != -1) {
        _songs[existingIdx] = newSong;
        _currentSongIndex = existingIdx;
      } else {
        _songs.insert(0, newSong);
        _currentSongIndex = 0;
      }

      _songPosition = Duration.zero;
      songPositionNotifier.value = Duration.zero;
      _songDuration = Duration(seconds: newSong.durationSeconds);

      await _playCurrentSongWithCrossfade();
      _isSongBuffering = false;
      _bufferingSongTitle = null;
      notifyListeners();
      _broadcastSync('SELECT', 0);
    } catch (e) {
      debugPrint('[AudioProvider] Exception playing YouTube track: $e');
      _isSongBuffering = false;
      _bufferingSongTitle = null;
      _lastPlayError = 'Unable to play "${track.title}": $e';
      notifyListeners();
    }
  }

  Future<void> selectSong(int index) async {
    if (index < 0 || index >= _songs.length) return;
    _currentSongIndex = index;
    _songPosition = Duration.zero;
    songPositionNotifier.value = Duration.zero;
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
    songPositionNotifier.value = position;
    if (audioHandler != null && _isSongPlaying) {
      audioHandler!.updatePlaybackState(
        isPlaying: _isSongPlaying,
        position: position,
        duration: _songDuration,
      );
    }
    notifyListeners();
    _broadcastSync('SEEK', position.inSeconds);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeatOne = !_isRepeatOne;
    notifyListeners();
  }

  void toggleBackgroundPlayback() {
    _allowBackgroundPlayback = !_allowBackgroundPlayback;
    _syncNotificationState();
    notifyListeners();
  }

  /// Robust song player start (clean state reset and immediate full volume)
  Future<void> _playCurrentSongWithCrossfade() async {
    try {
      final targetSource = _resolveSource(currentSong.audioUrl, isLocal: currentSong.isLocal);

      if (_songPlayer.state == PlayerState.playing) {
        await _songPlayer.stop();
      }

      await _songPlayer.setVolume(1.0);
      await _songPlayer.play(targetSource);
      _isSongPlaying = true;
      _syncNotificationState();
    } catch (e) {
      debugPrint('Play error: $e, retrying at full volume');
      try {
        await _songPlayer.setVolume(1.0);
        await _songPlayer.play(_resolveSource(currentSong.audioUrl, isLocal: currentSong.isLocal));
        _isSongPlaying = true;
        _syncNotificationState();
      } catch (err) {
        debugPrint('Direct play fallback error: $err');
      }
    }
  }

  Future<void> playNextWithCrossfade() async {
    await nextSong();
  }

  void addCustomSong(SongItem song) {
    _deletedSongIds.remove(song.id);
    LocalCacheService.setCachedDeletedSongIds(_deletedSongIds.toList());
    _songs.add(song);
    _persistSongs();
    notifyListeners();
  }

  Future<void> deleteSong(String id) async {
    // 1. Permanently record this song ID as deleted so it NEVER reappears on app reopen
    _deletedSongIds.add(id);
    await LocalCacheService.setCachedDeletedSongIds(_deletedSongIds.toList());

    // 2. Remove from active memory list
    final idx = _songs.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final wasPlayingThis = _isSongPlaying && _currentSongIndex == idx;
      if (wasPlayingThis) {
        await pauseSong();
      }
      _songs.removeAt(idx);
      if (_songs.isEmpty) {
        _currentSongIndex = 0;
        _isSongPlaying = false;
        await _songPlayer.stop();
      } else if (_currentSongIndex >= _songs.length) {
        _currentSongIndex = _songs.length - 1;
      }
      await _persistSongs();

      // Remove deleted song from all playlists
      bool playlistsChanged = false;
      for (final pl in _playlists) {
        if (pl.songIds.remove(id)) {
          playlistsChanged = true;
        }
      }
      if (playlistsChanged) {
        _savePlaylistsLocally();
      }

      notifyListeners();
    }
  }

  Future<void> _persistSongs() async {
    try {
      final list = _songs.map((s) => s.toJson()).toList();
      await LocalCacheService.setCachedSongs(list);

      if (_syncSpaceId.isNotEmpty) {
        await FirebaseService.saveNestedFeatureField(
          _syncSpaceId,
          'music',
          'songs',
          list,
          rootDefaults: {'songs': list, 'deleted_ids': _deletedSongIds.toList()},
        );
        await FirebaseService.saveNestedFeatureField(
          _syncSpaceId,
          'music',
          'deleted_ids',
          _deletedSongIds.toList(),
        );
      }
    } catch (_) {}
  }

  void initMusicSync(String spaceId) {
    if (spaceId.isEmpty || _syncSpaceId == spaceId) return;
    _syncSpaceId = spaceId;

    _musicCloudSub?.cancel();
    _musicCloudSub = FirebaseService.streamFeatureDoc(spaceId, 'music').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        bool hasChanges = false;
        if (data['deleted_ids'] is List) {
          final del = List<String>.from(data['deleted_ids'] as List);
          _deletedSongIds.addAll(del);
          LocalCacheService.setCachedDeletedSongIds(_deletedSongIds.toList());
          final beforeCount = _songs.length;
          _songs.removeWhere((s) => _deletedSongIds.contains(s.id));
          if (_songs.length != beforeCount) hasChanges = true;
        }
        if (data['songs'] is List) {
          final list = (data['songs'] as List)
              .map((e) => SongItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .where((s) => !_deletedSongIds.contains(s.id))
              .toList();
          if (list.isNotEmpty || _songs.isNotEmpty) {
            _songs = list;
            LocalCacheService.setCachedSongs(_songs.map((s) => s.toJson()).toList());
            hasChanges = true;
          }
        }
        if (hasChanges) {
          if (_songs.isEmpty) {
            _currentSongIndex = 0;
            _isSongPlaying = false;
          } else if (_currentSongIndex >= _songs.length) {
            _currentSongIndex = _songs.length - 1;
          }
          notifyListeners();
        }
      }
    });

    // Realtime stream for playlists from Firebase
    _playlistFirebaseSub?.cancel();
    _playlistFirebaseSub = FirebaseService.streamFeatureDoc(spaceId, 'playlists').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final list = snap.data()!['playlists'] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          _playlists.clear();
          _playlists.addAll(list.map((e) => PlaylistItem.fromJson(Map<String, dynamic>.from(e as Map))));
          LocalCacheService.setCachedPlaylists(_playlists.map((p) => p.toJson()).toList());
          notifyListeners();
        }
      }
    });

    // Supabase app_content fetch for shared space playlists
    try {
      final client = SupabaseService.client;
      if (client != null) {
        client
            .from('app_content')
            .select('content')
            .eq('id', 'playlists_$spaceId')
            .maybeSingle()
            .then((res) {
          if (res != null && res['content'] != null && res['content'] is List) {
            final list = res['content'] as List;
            if (list.isNotEmpty) {
              _playlists.clear();
              _playlists.addAll(list.map((e) => PlaylistItem.fromJson(Map<String, dynamic>.from(e as Map))));
              notifyListeners();
            }
          }
        });
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // PLAYLIST MANAGEMENT
  // -------------------------------------------------------------
  void _savePlaylistsLocally() {
    try {
      LocalCacheService.setCachedPlaylists(_playlists.map((p) => p.toJson()).toList());
      if (_syncSpaceId.isNotEmpty) {
        FirebaseService.saveFeatureDoc(_syncSpaceId, 'playlists', {
          'playlists': _playlists.map((p) => p.toJson()).toList(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        final client = SupabaseService.client;
        if (client != null) {
          client.from('app_content').upsert({
            'id': 'playlists_$_syncSpaceId',
            'content': _playlists.map((p) => p.toJson()).toList(),
            'updated_at': DateTime.now().toIso8601String(),
          }).then((_) {});
        }
      }
    } catch (_) {}
  }

  void createPlaylist(String title, List<String> songIds, {Color? coverColor}) {
    final pl = PlaylistItem(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      coverColor: coverColor ?? const Color(0xFF2DD4BF),
      songIds: songIds,
    );
    _playlists.add(pl);
    _savePlaylistsLocally();
    notifyListeners();
  }

  void deletePlaylist(String id) {
    _playlists.removeWhere((p) => p.id == id);
    _savePlaylistsLocally();
    notifyListeners();
  }

  void addSongToPlaylist(String playlistId, String songId) {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      if (!_playlists[idx].songIds.contains(songId)) {
        _playlists[idx].songIds.add(songId);
        _savePlaylistsLocally();
        notifyListeners();
      }
    }
  }

  void removeSongFromPlaylist(String playlistId, String songId) {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      _playlists[idx].songIds.remove(songId);
      _savePlaylistsLocally();
      notifyListeners();
    }
  }

  /// Add YouTube Track directly to existing playlist
  void addYoutubeTrackToPlaylist(String playlistId, YoutubeTrack track) {
    final song = SongItem(
      id: track.id,
      youtubeId: track.id,
      title: track.title,
      artist: track.artist,
      durationSeconds: track.durationSeconds,
      audioUrl: track.audioStreamUrl ?? '',
      coverColor: const Color(0xFFD97706),
      isLocal: false,
      addedBy: 'YouTube Music',
      thumbnailUrl: track.thumbnailUrl,
    );

    final existingIdx = _songs.indexWhere((s) => s.id == song.id || s.youtubeId == song.id);
    if (existingIdx == -1) {
      _songs.add(song);
      _persistSongs();
    } else {
      _songs[existingIdx] = song;
    }

    addSongToPlaylist(playlistId, song.id);
  }

  /// Add YouTube Track directly to shared/local playback queue
  void queueYoutubeTrack(YoutubeTrack track) {
    final song = SongItem(
      id: track.id,
      youtubeId: track.id,
      title: track.title,
      artist: track.artist,
      durationSeconds: track.durationSeconds,
      audioUrl: track.audioStreamUrl ?? '',
      coverColor: const Color(0xFFD97706),
      isLocal: false,
      addedBy: 'Shared Queue',
      thumbnailUrl: track.thumbnailUrl,
    );

    final existingIdx = _songs.indexWhere((s) => s.id == song.id || s.youtubeId == song.id);
    if (existingIdx != -1) {
      _songs.removeAt(existingIdx);
    }
    final insertIdx = (_currentSongIndex + 1).clamp(0, _songs.length);
    _songs.insert(insertIdx, song);
    _persistSongs();
    notifyListeners();

    // Broadcast queue addition to partner in Listen Together
    if (_isListenTogetherActive && _syncChannel != null) {
      final payload = {
        'type': 'QUEUE_ADD',
        'songId': song.id,
        'youtubeId': song.youtubeId,
        'title': song.title,
        'artist': song.artist,
        'durationSeconds': song.durationSeconds,
        'thumbnailUrl': song.thumbnailUrl,
        'audioUrl': song.audioUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      _syncChannel!.sendBroadcastMessage(
        event: 'playback_update',
        payload: payload,
      );
      _syncChannel!.sendBroadcastMessage(
        event: 'playback_sync',
        payload: payload,
      );
    }
  }

  /// Play an entire playlist from the beginning
  Future<void> playPlaylist(PlaylistItem playlist) async {
    if (playlist.songIds.isEmpty) return;
    final playlistSongs = <SongItem>[];
    for (final sid in playlist.songIds) {
      final s = _songs.where((x) => x.id == sid || (x.youtubeId != null && x.youtubeId == sid)).toList();
      if (s.isNotEmpty) playlistSongs.add(s.first);
    }
    if (playlistSongs.isEmpty) return;

    for (final s in playlistSongs) {
      _songs.removeWhere((x) => x.id == s.id);
    }
    _songs.insertAll(0, playlistSongs);
    _persistSongs();
    await selectSong(0);
  }

  /// Add all songs from a playlist into the upcoming queue
  void queuePlaylist(PlaylistItem playlist) {
    if (playlist.songIds.isEmpty) return;
    final playlistSongs = <SongItem>[];
    for (final sid in playlist.songIds) {
      final s = _songs.where((x) => x.id == sid || (x.youtubeId != null && x.youtubeId == sid)).toList();
      if (s.isNotEmpty) playlistSongs.add(s.first);
    }
    if (playlistSongs.isEmpty) return;

    int insertIdx = _currentSongIndex + 1;
    for (final song in playlistSongs) {
      _songs.removeWhere((x) => x.id == song.id && _songs.indexOf(x) > _currentSongIndex);
      _songs.insert(insertIdx, song);
      insertIdx++;

      if (_isListenTogetherActive && _syncChannel != null) {
        final payload = {
          'type': 'QUEUE_ADD',
          'songId': song.id,
          'youtubeId': song.youtubeId,
          'title': song.title,
          'artist': song.artist,
          'durationSeconds': song.durationSeconds,
          'thumbnailUrl': song.thumbnailUrl,
          'audioUrl': song.audioUrl,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        _syncChannel!.sendBroadcastMessage(event: 'playback_update', payload: payload);
        _syncChannel!.sendBroadcastMessage(event: 'playback_sync', payload: payload);
      }
    }
    _persistSongs();
    notifyListeners();
  }

  /// Remove a song from the upcoming queue by index (0 is next song)
  void removeSongFromUpcoming(int queueIndex) {
    final targetIndex = _currentSongIndex + 1 + queueIndex;
    if (targetIndex >= 0 && targetIndex < _songs.length) {
      final removed = _songs.removeAt(targetIndex);
      _persistSongs();
      notifyListeners();

      if (_isListenTogetherActive && _syncChannel != null) {
        final payload = {
          'type': 'QUEUE_REMOVE',
          'songId': removed.id,
          'youtubeId': removed.youtubeId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        _syncChannel!.sendBroadcastMessage(event: 'playback_update', payload: payload);
        _syncChannel!.sendBroadcastMessage(event: 'playback_sync', payload: payload);
      }
    }
  }

  /// Remove a song from sanctuary library/queue by its ID
  void removeSong(String songId) {
    final idx = _songs.indexWhere((s) => s.id == songId || (s.youtubeId != null && s.youtubeId == songId));
    if (idx != -1) {
      if (idx == _currentSongIndex && _songs.length > 1) {
        nextSong();
      }
      final removed = _songs.removeAt(idx);
      if (idx < _currentSongIndex) {
        _currentSongIndex = (_currentSongIndex - 1).clamp(0, _songs.length - 1);
      }
      _persistSongs();
      notifyListeners();

      if (_isListenTogetherActive && _syncChannel != null) {
        final payload = {
          'type': 'QUEUE_REMOVE',
          'songId': removed.id,
          'youtubeId': removed.youtubeId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        _syncChannel!.sendBroadcastMessage(event: 'playback_update', payload: payload);
        _syncChannel!.sendBroadcastMessage(event: 'playback_sync', payload: payload);
      }
    }
  }

  /// Clear all upcoming songs in the queue
  void clearUpcomingQueue() {
    if (_songs.length > _currentSongIndex + 1) {
      _songs.removeRange(_currentSongIndex + 1, _songs.length);
      _persistSongs();
      notifyListeners();

      if (_isListenTogetherActive && _syncChannel != null) {
        final payload = {
          'type': 'QUEUE_CLEAR',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        _syncChannel!.sendBroadcastMessage(event: 'playback_update', payload: payload);
        _syncChannel!.sendBroadcastMessage(event: 'playback_sync', payload: payload);
      }
    }
  }

  /// Insert song directly after the current song so it plays next
  void playNext(SongItem song) {
    final existingIdx = _songs.indexWhere((s) => s.id == song.id || (s.youtubeId != null && s.youtubeId == song.youtubeId));
    if (existingIdx != -1) {
      if (existingIdx == _currentSongIndex) return;
      _songs.removeAt(existingIdx);
      if (existingIdx < _currentSongIndex) {
        _currentSongIndex--;
      }
    }
    final insertIdx = (_currentSongIndex + 1).clamp(0, _songs.length);
    _songs.insert(insertIdx, song);
    _persistSongs();
    notifyListeners();

    if (_isListenTogetherActive && _syncChannel != null) {
      final payload = {
        'type': 'QUEUE_ADD',
        'songId': song.id,
        'youtubeId': song.youtubeId,
        'title': song.title,
        'artist': song.artist,
        'durationSeconds': song.durationSeconds,
        'thumbnailUrl': song.thumbnailUrl,
        'audioUrl': song.audioUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      _syncChannel!.sendBroadcastMessage(event: 'playback_update', payload: payload);
      _syncChannel!.sendBroadcastMessage(event: 'playback_sync', payload: payload);
    }
  }

  /// Add song to the end of the upcoming queue
  void queueSongItem(SongItem song) {
    final existingIdx = _songs.indexWhere((s) => s.id == song.id || (s.youtubeId != null && s.youtubeId == song.youtubeId));
    if (existingIdx != -1) {
      if (existingIdx == _currentSongIndex) return;
      _songs.removeAt(existingIdx);
      if (existingIdx < _currentSongIndex) {
        _currentSongIndex--;
      }
    }
    _songs.add(song);
    _persistSongs();
    notifyListeners();

    if (_isListenTogetherActive && _syncChannel != null) {
      final payload = {
        'type': 'QUEUE_ADD',
        'songId': song.id,
        'youtubeId': song.youtubeId,
        'title': song.title,
        'artist': song.artist,
        'durationSeconds': song.durationSeconds,
        'thumbnailUrl': song.thumbnailUrl,
        'audioUrl': song.audioUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      _syncChannel!.sendBroadcastMessage(event: 'playback_update', payload: payload);
      _syncChannel!.sendBroadcastMessage(event: 'playback_sync', payload: payload);
    }
  }

  // -------------------------------------------------------------
  // ATMOSPHERE SOUNDSCAPES MULTI-STEM MIXER & SMART DUCKING
  // -------------------------------------------------------------
  Future<void> toggleAtmospherePlay() async {
    if (_isAtmospherePlaying) {
      await pauseAtmosphere();
    } else {
      await resumeAtmosphere();
    }
  }

  /// Smart Ducking: When a song is playing, atmosphere sound automatically ducks to 25% volume.
  /// When song pauses, atmosphere sound smoothly returns to 100% of set volume.
  void _applyAtmosphereVolumes() {
    final duckFactor = (_isSongPlaying && _isAtmospherePlaying) ? 0.25 : 1.0;

    for (final stemId in _atmosphereStems.keys) {
      final stem = _atmosphereStems[stemId]!;
      final player = _stemPlayers[stemId]!;
      final effectiveVolume = stem.volume * _masterAtmosphereVolume * duckFactor;

      if (effectiveVolume > 0.01 && _isAtmospherePlaying) {
        try {
          player.setVolume(effectiveVolume);
          if (player.state != PlayerState.playing) {
            player.play(_resolveSource(stem.audioUrl));
          }
        } catch (e) {
          debugPrint('Error playing stem $stemId: $e');
        }
      } else {
        if (player.state == PlayerState.playing) {
          player.pause();
        }
      }
    }
  }

  Future<void> resumeAtmosphere() async {
    _isAtmospherePlaying = true;
    notifyListeners();
    _applyAtmosphereVolumes();
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
      _applyAtmosphereVolumes();
    }
  }

  void setMasterVolume(double volume) {
    _masterAtmosphereVolume = volume.clamp(0.0, 1.0);
    notifyListeners();

    if (_isAtmospherePlaying) {
      _applyAtmosphereVolumes();
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
      _applyAtmosphereVolumes();
    }
  }

  /// Called when user leaves the app: strictly stop atmosphere natural sounds!
  void stopAtmosphereOnExit() {
    pauseAtmosphere();
  }

  // -------------------------------------------------------------
  // LISTEN TOGETHER (REALTIME SUPABASE BROADCAST)
  // -------------------------------------------------------------
  void startListenTogether(String spaceId, {String? userId, String? nickname}) {
    _isListenTogetherActive = true;
    _syncSpaceId = spaceId;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      _syncChannel = supabase.channel('music_sync_$spaceId');

      // Broadcast listen together invitation to partner
      SupabaseService.broadcastEvent(
        spaceId: spaceId,
        eventType: 'LISTEN_INVITE',
        payload: {
          'senderId': userId ?? '',
          'senderNickname': nickname ?? 'Your Partner',
          'songTitle': currentSong.title,
          'artist': currentSong.artist,
        },
      );

      void handleSyncPayload(Map<String, dynamic> payload) async {
        if (_ignoreIncomingSync) return;
        final type = payload['type'] as String?;
        final songId = payload['songId'] as String?;
        final youtubeId = payload['youtubeId'] as String?;
        final title = payload['title'] as String?;
        final artist = payload['artist'] as String?;
        final remoteAudioUrl = payload['audioUrl'] as String?;
        final durationSec = payload['durationSeconds'] as int? ?? 180;
        final thumb = payload['thumbnailUrl'] as String?;
        final positionSec = payload['positionSec'] as int?;

        // Handle Partner Shared Queue Insertion
        if (type == 'QUEUE_ADD') {
          final qSong = SongItem(
            id: songId ?? 'sync_${DateTime.now().millisecondsSinceEpoch}',
            youtubeId: youtubeId,
            title: title ?? 'Queued Track',
            artist: artist ?? 'Partner Queue',
            durationSeconds: durationSec,
            audioUrl: remoteAudioUrl ?? '',
            coverColor: const Color(0xFFD97706),
            isLocal: false,
            addedBy: 'Partner Queue',
            thumbnailUrl: thumb,
          );
          final existing = _songs.indexWhere((s) => s.id == qSong.id || (s.youtubeId != null && s.youtubeId == qSong.youtubeId));
          if (existing != -1) {
            _songs.removeAt(existing);
          }
          final insertIdx = (_currentSongIndex + 1).clamp(0, _songs.length);
          _songs.insert(insertIdx, qSong);
          notifyListeners();
          return;
        }

        // Handle Partner Shared Queue Removal
        if (type == 'QUEUE_REMOVE') {
          if (songId != null || youtubeId != null) {
            final idx = _songs.indexWhere((s) =>
                (songId != null && s.id == songId) ||
                (youtubeId != null && s.youtubeId == youtubeId));
            if (idx != -1 && idx != _currentSongIndex) {
              if (idx < _currentSongIndex) {
                _currentSongIndex = (_currentSongIndex - 1).clamp(0, _songs.length - 1);
              }
              _songs.removeAt(idx);
              notifyListeners();
            }
          }
          return;
        }

        // Handle Partner Shared Queue Clear
        if (type == 'QUEUE_CLEAR') {
          if (_songs.length > _currentSongIndex + 1) {
            _songs.removeRange(_currentSongIndex + 1, _songs.length);
            notifyListeners();
          }
          return;
        }

        // 1. Locate matching song in current partner's playlist
        int matchIdx = -1;
        if (songId != null) {
          matchIdx = _songs.indexWhere((s) => s.id == songId || (s.youtubeId != null && s.youtubeId == songId));
        }
        if (matchIdx == -1 && youtubeId != null) {
          matchIdx = _songs.indexWhere((s) => s.id == youtubeId || s.youtubeId == youtubeId);
        }
        if (matchIdx == -1 && title != null) {
          matchIdx = _songs.indexWhere((s) => s.title.toLowerCase() == title.toLowerCase());
        }

        // If not found in playlist, dynamically add it
        if (matchIdx == -1 && title != null) {
          String resolvedUrl = remoteAudioUrl ?? '';
          bool resolvedIsLocal = false;

          // Check if partner already has it downloaded locally
          if (youtubeId != null) {
            final local = MusicDownloadService.instance.getLocalFilePath(youtubeId);
            if (local != null && File(local).existsSync()) {
              resolvedUrl = local;
              resolvedIsLocal = true;
            }
          }

          final syncedSong = SongItem(
            id: songId ?? 'sync_${DateTime.now().millisecondsSinceEpoch}',
            youtubeId: youtubeId,
            title: title,
            artist: artist ?? 'Partner Queue',
            durationSeconds: durationSec,
            audioUrl: resolvedUrl,
            coverColor: const Color(0xFFD97706),
            isLocal: resolvedIsLocal,
            addedBy: 'Partner',
            thumbnailUrl: thumb,
          );
          _songs.insert(0, syncedSong);
          matchIdx = 0;
        }

        if (matchIdx != -1 && matchIdx != _currentSongIndex) {
          _currentSongIndex = matchIdx;
          _songDuration = Duration(seconds: _songs[matchIdx].durationSeconds);
        }

        if (type == 'PLAY') {
          final targetSong = currentSong;
          if (targetSong.audioUrl.isEmpty && targetSong.youtubeId != null) {
            final resolvedStream = await YoutubeMusicService.instance.getAudioStreamUrl(targetSong.youtubeId!);
            if (resolvedStream != null) {
              _songs[_currentSongIndex] = targetSong.copyWith(audioUrl: resolvedStream, isLocal: false);
            }
          }
          if (currentSong.audioUrl.isNotEmpty) {
            _isSongPlaying = true;
            await _songPlayer.play(_resolveSource(currentSong.audioUrl, isLocal: currentSong.isLocal));
          }
        } else if (type == 'PAUSE') {
          _isSongPlaying = false;
          await _songPlayer.pause();
        } else if (type == 'SEEK' && positionSec != null) {
          final target = Duration(seconds: positionSec);
          _songPosition = target;
          songPositionNotifier.value = target;
          await _songPlayer.seek(target);
        }
        notifyListeners();
      }

      _syncChannel!.onBroadcast(
        event: 'playback_update',
        callback: (payload) => handleSyncPayload(Map<String, dynamic>.from(payload)),
      );
      _syncChannel!.onBroadcast(
        event: 'playback_sync',
        callback: (payload) => handleSyncPayload(Map<String, dynamic>.from(payload)),
      );
      _syncChannel!.subscribe();
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
      final payload = {
        'type': type,
        'songIndex': _currentSongIndex,
        'positionSec': positionSec,
        'songId': currentSong.id,
        'youtubeId': currentSong.youtubeId,
        'title': currentSong.title,
        'artist': currentSong.artist,
        'durationSeconds': currentSong.durationSeconds,
        'thumbnailUrl': currentSong.thumbnailUrl,
        'isLocal': currentSong.isLocal,
        // Only send remote URL across network, never device sandbox paths like /data/user/0/...
        'audioUrl': currentSong.isLocal ? null : currentSong.audioUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      _syncChannel!.sendBroadcastMessage(
        event: 'playback_update',
        payload: payload,
      );
      _syncChannel!.sendBroadcastMessage(
        event: 'playback_sync',
        payload: payload,
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
      _isSongPlaying = false;
      _songPlayer.pause().catchError((_) {});
    }
    if (_isAtmospherePlaying) {
      _wasAtmospherePlayingBeforeDuck = true;
      _isAtmospherePlaying = false;
      // Pause atmosphere stems asynchronously without blocking the UI thread
      Future.microtask(() => pauseAtmosphere());
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
    _musicCloudSub?.cancel();
    _playlistFirebaseSub?.cancel();
    audioHandler?.clearNotification();
    _songPlayer.dispose();
    _crossfadePlayer?.dispose();
    for (final p in _stemPlayers.values) {
      p.dispose();
    }
    _syncChannel?.unsubscribe();
    super.dispose();
  }
}
