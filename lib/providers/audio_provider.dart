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
import '../core/services/device_status_service.dart';
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
  final Set<String> _favoriteSongIds = {};
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
  int _playSessionId = 0;
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
  String _syncUserId = '';
  String? _lastHandledSyncEventId;
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
  Set<String> get favoriteSongIds => Set.unmodifiable(_favoriteSongIds);
  bool isFavorite(String songId) => _favoriteSongIds.contains(songId);
  List<SongItem> get favoriteSongs => _songs.where((s) => _favoriteSongIds.contains(s.id)).toList();
  int get favoriteCount => favoriteSongs.length;
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
    _favoriteSongIds.clear();
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

  /// Eliminates duplicate tracks by unique ID and normalized title+artist
  List<SongItem> _deduplicateSongs(List<SongItem> songs) {
    final seenIds = <String>{};
    final seenTitles = <String>{};
    final unique = <SongItem>[];
    for (final s in songs) {
      if (_deletedSongIds.contains(s.id)) continue;
      final titleKey = '${s.title.trim().toLowerCase()}_${s.artist.trim().toLowerCase()}';
      if (!seenIds.contains(s.id) && !seenTitles.contains(titleKey)) {
        seenIds.add(s.id);
        if (s.title.trim().isNotEmpty) seenTitles.add(titleKey);
        unique.add(s);
      }
    }
    return unique;
  }

  /// Sanitizes playlists to ensure unique songIds and consistent clean state
  List<PlaylistItem> _sanitizePlaylists(List<PlaylistItem> playlists) {
    return playlists.map<PlaylistItem>((pl) {
      final seen = <String>{};
      final uniqueIds = <String>[];
      for (final id in pl.songIds) {
        if (id.trim().isNotEmpty && seen.add(id.trim())) {
          uniqueIds.add(id.trim());
        }
      }
      return pl.copyWith(songIds: uniqueIds);
    }).toList();
  }

  void _loadPersistedSongs() {
    try {
      final deleted = LocalCacheService.getCachedDeletedSongIds();
      _deletedSongIds.addAll(deleted);

      final cached = LocalCacheService.getCachedSongs();
      if (cached != null) {
        _songs = _deduplicateSongs(cached
            .map((e) => SongItem.fromJson(e))
            .where((s) => !_deletedSongIds.contains(s.id))
            .toList());
      } else {
        _songs = [];
      }

      final cachedPlaylists = LocalCacheService.getCachedPlaylists();
      if (cachedPlaylists != null) {
        _playlists.clear();
        _playlists.addAll(_sanitizePlaylists(cachedPlaylists.map((e) => PlaylistItem.fromJson(e)).toList()));
      }

      final cachedFavs = LocalCacheService.prefs.getStringList('favorite_song_ids');
      if (cachedFavs != null) {
        _favoriteSongIds.clear();
        _favoriteSongIds.addAll(cachedFavs);
      }
    } catch (_) {
      _songs = [];
    }
  }

  /// Toggles favorite/starred status for a song and persists locally & cloud
  Future<void> toggleFavorite(String songId) async {
    if (songId.isEmpty || songId == 'empty') return;
    if (_favoriteSongIds.contains(songId)) {
      _favoriteSongIds.remove(songId);
    } else {
      _favoriteSongIds.add(songId);
    }
    notifyListeners();
    try {
      await LocalCacheService.prefs.setStringList('favorite_song_ids', _favoriteSongIds.toList());
      if (_syncSpaceId.isNotEmpty) {
        await SupabaseService.upsertAppContent('favorite_songs_$_syncSpaceId', {
          'favorites': _favoriteSongIds.toList(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  /// Plays all starred favorite songs from the sanctuary library
  void playFavoriteSongs({int initialIndex = 0}) {
    final favs = favoriteSongs;
    if (favs.isEmpty) return;
    final target = favs[initialIndex.clamp(0, favs.length - 1)];
    final songIndex = _songs.indexOf(target);
    if (songIndex != -1) {
      selectSong(songIndex);
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
    if (_isSongPlaying && _songs.isNotEmpty && currentSong.id != 'empty') {
      DeviceStatusService.setNowPlaying(
        title: currentSong.title,
        artist: currentSong.artist,
      );
    } else {
      DeviceStatusService.setNowPlaying(title: null, artist: null);
    }
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

    // Auto-advance with continuous 1-by-1 playback
    _songPlayer.onPlayerComplete.listen((_) {
      if (_isRepeatOne) {
        seekSong(Duration.zero);
        _songPlayer.resume();
      } else {
        nextSong(isAutoAdvance: true);
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
  // SONG CONTROLS & SMOOTH PLAYBACK (Instant Optimistic Feedback)
  // -------------------------------------------------------------
  Future<void> toggleSongPlay() async {
    final willPlay = !_isSongPlaying;
    _isSongPlaying = willPlay;
    _syncNotificationState();
    notifyListeners(); // 0ms instant UI reaction on play/pause tap!

    if (willPlay) {
      await resumeSong();
    } else {
      await pauseSong();
    }
  }

  Future<void> resumeSong() async {
    // Optimistic immediate UI update (0ms delay):
    _isSongPlaying = true;
    notifyListeners();

    try {
      if (_songPosition == Duration.zero ||
          _songPlayer.state == PlayerState.stopped ||
          _songPlayer.state == PlayerState.completed) {
        await _playCurrentSongWithCrossfade();
        _broadcastSync('PLAY', _songPosition.inSeconds);
      } else {
        await _songPlayer.resume();
        _syncNotificationState();
        _broadcastSync('PLAY', _songPosition.inSeconds);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('resumeSong error: $e, recovering with fresh play');
      await _playCurrentSongWithCrossfade();
    }
  }

  Future<void> pauseSong() async {
    try {
      _isSongPlaying = false;
      _syncNotificationState();
      _broadcastSync('PAUSE', _songPosition.inSeconds);
      notifyListeners();
      await _songPlayer.pause();
    } catch (_) {}
  }

  /// Prefetches the next upcoming track's audio stream in the background
  /// Ensures 0ms instant transition when advancing to the next track!
  void _prefetchUpcomingTrack() {
    if (_songs.isEmpty) return;
    final nextIdx = (_currentSongIndex + 1) % _songs.length;
    final nextTrack = _songs[nextIdx];

    // If already stored locally on device, no network prefetch needed
    if (nextTrack.isLocal) return;
    final localPath = MusicDownloadService.instance.getLocalFilePath(nextTrack.id);
    if (localPath != null && File(localPath).existsSync()) return;

    // If stream URL is already verified fresh, skip
    if (YoutubeMusicService.isStreamFresh(nextTrack.audioUrl)) return;

    // Asynchronously resolve fresh audio stream without blocking UI thread
    final trackId = nextTrack.youtubeId ?? nextTrack.id;
    YoutubeMusicService.instance.getAudioStreamUrl(trackId).then((freshUrl) {
      if (freshUrl != null && freshUrl.isNotEmpty) {
        final currentNextIdx = (_currentSongIndex + 1) % _songs.length;
        if (currentNextIdx < _songs.length && _songs[currentNextIdx].id == nextTrack.id) {
          _songs[currentNextIdx] = nextTrack.copyWith(audioUrl: freshUrl);
        }
      }
    }).catchError((e) {
      debugPrint('[AudioProvider] Prefetch error for ${nextTrack.title}: $e');
    });
  }

  /// Plays a track from YouTube Music or local offline cache
  Future<void> playYoutubeTrack(YoutubeTrack track) async {
    final localPath = MusicDownloadService.instance.getLocalFilePath(track.id);
    String audioUrl = '';
    bool isLocal = false;

    if (localPath != null && File(localPath).existsSync()) {
      audioUrl = localPath;
      isLocal = true;
    } else if (track.audioStreamUrl != null &&
        track.audioStreamUrl!.isNotEmpty &&
        YoutubeMusicService.isStreamFresh(track.audioStreamUrl!)) {
      audioUrl = track.audioStreamUrl!;
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
    _isSongPlaying = true;
    _lastPlayError = null;
    _persistSongs();
    _syncNotificationState();
    notifyListeners(); // 0ms instant UI reaction

    _broadcastSync('SELECT', 0);
    await _playCurrentSongWithCrossfade();
  }

  Future<void> selectSong(int index) async {
    if (index < 0 || index >= _songs.length) return;
    _currentSongIndex = index;
    _songPosition = Duration.zero;
    songPositionNotifier.value = Duration.zero;
    _songDuration = Duration(seconds: _songs[index].durationSeconds);
    _isSongPlaying = true;
    _lastPlayError = null;
    _syncNotificationState();
    notifyListeners(); // 0ms instant optimistic UI response: track highlights & mini-player updates immediately!

    _broadcastSync('SELECT', 0);
    await _playCurrentSongWithCrossfade();
  }

  /// Flawless non-stop continuous auto-play:
  /// Never stops at end of playlist; loops continuously through the sanctuary tracks!
  Future<void> nextSong({bool isAutoAdvance = false}) async {
    if (_songs.isEmpty) return;
    if (_isShuffle) {
      _currentSongIndex = Random().nextInt(_songs.length);
    } else {
      _currentSongIndex = (_currentSongIndex + 1) % _songs.length;
    }
    await selectSong(_currentSongIndex);
  }

  Future<void> prevSong() async {
    if (_songs.isEmpty) return;
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

  /// High-speed robust song player start:
  /// - 0ms local file playback
  /// - Automatic validation of stream freshness BEFORE calling native player (eliminates 15s hang)
  /// - Asynchronous prefetch of upcoming track
  /// - Non-stop auto-skip on irrecoverable stream failure so music never stops
  Future<void> _playCurrentSongWithCrossfade() async {
    final sessionId = ++_playSessionId;

    try {
      final song = currentSong;
      if (song.id == 'empty') return;

      // 1. Check local download cache first (0ms latency, zero data)
      String? localPath = song.isLocal ? song.audioUrl : MusicDownloadService.instance.getLocalFilePath(song.id);
      if (localPath != null && File(localPath).existsSync()) {
        if (sessionId != _playSessionId) return;
        _isSongBuffering = false;
        _bufferingSongTitle = null;
        await _songPlayer.setVolume(1.0);
        await _songPlayer.play(DeviceFileSource(localPath));
        if (sessionId != _playSessionId) return;
        _isSongPlaying = true;
        _syncNotificationState();
        notifyListeners();
        _prefetchUpcomingTrack();
        return;
      }

      // 2. Validate remote audioUrl freshness (prevents 15s native MediaPlayer timeout freeze!)
      String playUrl = song.audioUrl;
      final bool needsFreshUrl = !YoutubeMusicService.isStreamFresh(playUrl);

      if (needsFreshUrl) {
        _isSongBuffering = true;
        _bufferingSongTitle = song.title;
        notifyListeners();

        final trackId = song.youtubeId ?? song.id;
        String? freshUrl = await YoutubeMusicService.instance.getAudioStreamUrl(trackId);

        if ((freshUrl == null || freshUrl.isEmpty) && song.title.isNotEmpty) {
          try {
            final searchResults = await YoutubeMusicService.instance.search('${song.title} ${song.artist}'.trim());
            if (searchResults.isNotEmpty) {
              freshUrl = searchResults.first.audioUrl;
              if (freshUrl.isEmpty) {
                freshUrl = await YoutubeMusicService.instance.getAudioStreamUrl(searchResults.first.id);
              }
            }
          } catch (_) {}
        }

        if (sessionId != _playSessionId) return;

        if (freshUrl != null && freshUrl.isNotEmpty) {
          playUrl = freshUrl;
          final currentIdx = _currentSongIndex.clamp(0, _songs.length - 1);
          if (_songs.isNotEmpty && _songs[currentIdx].id == song.id) {
            _songs[currentIdx] = song.copyWith(audioUrl: playUrl);
          }
        } else {
          // Could not resolve stream URL for this track!
          _isSongBuffering = false;
          _bufferingSongTitle = null;
          _lastPlayError = 'Unable to stream "${song.title}". Auto-skipping to next...';
          notifyListeners();

          // Non-stop auto-play: skip to next track so music never stalls
          if (_songs.length > 1) {
            Future.delayed(const Duration(milliseconds: 600), () {
              if (sessionId == _playSessionId) {
                nextSong(isAutoAdvance: true);
              }
            });
          }
          return;
        }
      }

      if (sessionId != _playSessionId) return;

      final targetSource = _resolveSource(playUrl, isLocal: false);
      await _songPlayer.setVolume(1.0);
      await _songPlayer.play(targetSource);

      if (sessionId != _playSessionId) return;

      _isSongPlaying = true;
      _isSongBuffering = false;
      _bufferingSongTitle = null;
      _lastPlayError = null;
      _syncNotificationState();
      notifyListeners();

      // Trigger background prefetch of next track for zero-delay auto-advance
      _prefetchUpcomingTrack();
    } catch (e) {
      debugPrint('[AudioProvider] Play error: $e, attempting stream URL recovery');
      if (sessionId != _playSessionId) return;

      try {
        final song = currentSong;
        final trackId = song.youtubeId ?? song.id;
        final freshUrl = await YoutubeMusicService.instance.getAudioStreamUrl(trackId);

        if (sessionId != _playSessionId) return;

        if (freshUrl != null && freshUrl.isNotEmpty) {
          final currentIdx = _currentSongIndex.clamp(0, _songs.length - 1);
          if (_songs.isNotEmpty && _songs[currentIdx].id == song.id) {
            _songs[currentIdx] = song.copyWith(audioUrl: freshUrl);
          }
          await _songPlayer.setVolume(1.0);
          await _songPlayer.play(UrlSource(freshUrl));

          if (sessionId != _playSessionId) return;

          _isSongPlaying = true;
          _isSongBuffering = false;
          _bufferingSongTitle = null;
          _lastPlayError = null;
          _syncNotificationState();
          notifyListeners();
          _prefetchUpcomingTrack();
          return;
        }
      } catch (err) {
        debugPrint('[AudioProvider] Direct play fallback error: $err');
      }

      _isSongBuffering = false;
      _bufferingSongTitle = null;
      _lastPlayError = 'Stream interrupted. Moving to next track...';
      notifyListeners();

      // Seamless non-stop auto-advance on error
      if (_songs.length > 1) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (sessionId == _playSessionId) {
            nextSong(isAutoAdvance: true);
          }
        });
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
        // 1. Firebase Firestore sync
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

        // 2. Supabase app_content sync (guarantees survival across re-logins)
        await SupabaseService.upsertAppContent('music_$_syncSpaceId', {
          'songs': list,
          'deleted_ids': _deletedSongIds.toList(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // 3. Supabase Realtime broadcast to partner
        await SupabaseService.broadcastEvent(
          spaceId: _syncSpaceId,
          eventType: 'MUSIC_UPDATE',
          payload: {
            'songs': list,
            'deleted_ids': _deletedSongIds.toList(),
          },
        );
      }
    } catch (_) {}
  }

  void _mergePlaylists(List<PlaylistItem> incoming) {
    final merged = <String, PlaylistItem>{};
    for (final p in _playlists) {
      merged[p.id] = p;
    }
    for (final p in incoming) {
      final existing = merged[p.id];
      if (existing != null) {
        final combinedSongs = <String>{...existing.songIds, ...p.songIds}.toList();
        merged[p.id] = PlaylistItem(
          id: p.id,
          title: p.title.isNotEmpty ? p.title : existing.title,
          coverColor: p.coverColor,
          songIds: combinedSongs,
        );
      } else {
        merged[p.id] = p;
      }
    }
    final sanitized = _sanitizePlaylists(merged.values.toList());
    _playlists
      ..clear()
      ..addAll(sanitized);
    LocalCacheService.setCachedPlaylists(_playlists.map((p) => p.toJson()).toList());
    notifyListeners();
  }

  void _applySongsPayload(Map<String, dynamic> data) {
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
        _songs = _deduplicateSongs([...list, ..._songs])
            .where((s) => !_deletedSongIds.contains(s.id))
            .toList();
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

  void initMusicSync(String spaceId, {String? userId}) {
    if (spaceId.isEmpty) return;
    _syncSpaceId = spaceId;
    if (userId != null && userId.isNotEmpty) {
      _syncUserId = userId;
    }

    // 1. Fast fetch from Supabase app_content for playlists, songs, and favorites
    try {
      final client = SupabaseService.client;
      if (client != null) {
        // Fetch playlists from Supabase
        client
            .from('app_content')
            .select('content')
            .eq('id', 'playlists_$spaceId')
            .maybeSingle()
            .then((res) {
          if (res != null && res['content'] != null && res['content'] is Map) {
            final data = Map<String, dynamic>.from(res['content'] as Map);
            final list = data['playlists'] as List<dynamic>?;
            if (list != null && list.isNotEmpty) {
              final incoming = list.map((e) => PlaylistItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
              _mergePlaylists(incoming);
            }
          }
        });

        // Fetch music tracks from Supabase
        client
            .from('app_content')
            .select('content')
            .eq('id', 'music_$spaceId')
            .maybeSingle()
            .then((res) {
          if (res != null && res['content'] != null && res['content'] is Map) {
            _applySongsPayload(Map<String, dynamic>.from(res['content'] as Map));
          }
        });

        // Fetch favorite song IDs from Supabase
        client
            .from('app_content')
            .select('content')
            .eq('id', 'favorite_songs_$spaceId')
            .maybeSingle()
            .then((res) {
          if (res != null && res['content'] != null && res['content'] is Map) {
            final data = Map<String, dynamic>.from(res['content'] as Map);
            if (data['favorites'] is List) {
              final favs = List<String>.from(data['favorites'] as List);
              _favoriteSongIds.addAll(favs);
              LocalCacheService.prefs.setStringList('favorite_song_ids', _favoriteSongIds.toList());
              notifyListeners();
            }
          }
        });
      }
    } catch (_) {}

    // 2. Realtime listener for cross-device updates
    SupabaseService.setMusicSyncListener(
      onPlaylistsUpdate: (data) {
        final list = data['playlists'] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          final incoming = list.map((e) => PlaylistItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          _mergePlaylists(incoming);
        }
      },
      onMusicUpdate: (data) {
        _applySongsPayload(data);
      },
      onMusicPlayback: (payload) {
        handlePlaybackSyncPayload(payload);
      },
    );

    // 3. Fallback Firestore streams
    _musicCloudSub?.cancel();
    _musicCloudSub = FirebaseService.streamFeatureDoc(spaceId, 'music').listen((snap) {
      if (snap.exists && snap.data() != null) {
        _applySongsPayload(snap.data()!);
      }
    });

    // Realtime stream for playlists from Firebase
    _playlistFirebaseSub?.cancel();
    _playlistFirebaseSub = FirebaseService.streamFeatureDoc(spaceId, 'playlists').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final list = snap.data()!['playlists'] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          final incoming = list.map((e) => PlaylistItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          _mergePlaylists(incoming);
        }
      }
    });
  }

  // -------------------------------------------------------------
  // PLAYLIST MANAGEMENT
  // -------------------------------------------------------------
  void _savePlaylistsLocally() {
    try {
      LocalCacheService.setCachedPlaylists(_playlists.map((p) => p.toJson()).toList());
      if (_syncSpaceId.isNotEmpty) {
        // 1. Firebase Firestore sync
        FirebaseService.saveFeatureDoc(_syncSpaceId, 'playlists', {
          'playlists': _playlists.map((p) => p.toJson()).toList(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        // 2. Supabase app_content sync (survives re-logins)
        SupabaseService.upsertAppContent('playlists_$_syncSpaceId', {
          'playlists': _playlists.map((p) => p.toJson()).toList(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        // 3. Supabase Realtime broadcast to partner
        SupabaseService.broadcastEvent(
          spaceId: _syncSpaceId,
          eventType: 'PLAYLISTS_UPDATE',
          payload: {
            'playlists': _playlists.map((p) => p.toJson()).toList(),
          },
        );
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
      _playlists[idx].songIds.removeWhere((id) => id == songId);
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

    final existingIdx = _songs.indexWhere((s) =>
        s.id == song.id ||
        (s.youtubeId != null && s.youtubeId == song.id) ||
        (s.title.trim().toLowerCase() == song.title.trim().toLowerCase() &&
            s.artist.trim().toLowerCase() == song.artist.trim().toLowerCase()));

    if (existingIdx == -1) {
      _songs.add(song);
      _persistSongs();
    } else {
      _songs[existingIdx] = song;
    }

    addSongToPlaylist(playlistId, song.id);
  }

  /// Plays a playlist starting directly from a specific tapped song index
  Future<void> playSongFromPlaylist(PlaylistItem playlist, int playlistIndex) async {
    final playlistSongs = <SongItem>[];
    for (final sid in playlist.songIds) {
      final s = _songs.where((x) => x.id == sid || (x.youtubeId != null && x.youtubeId == sid)).toList();
      if (s.isNotEmpty) playlistSongs.add(s.first);
    }
    if (playlistSongs.isEmpty || playlistIndex < 0 || playlistIndex >= playlistSongs.length) return;

    for (final s in playlistSongs) {
      _songs.removeWhere((x) => x.id == s.id);
    }
    _songs.insertAll(0, playlistSongs);
    _persistSongs();
    await selectSong(playlistIndex);
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
    if (userId != null && userId.isNotEmpty) {
      _syncUserId = userId;
    }
    _lastHandledSyncEventId = null;
    notifyListeners();

    try {
      _syncChannel?.unsubscribe();
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

      _syncChannel!.onBroadcast(
        event: 'playback_update',
        callback: (payload) => handlePlaybackSyncPayload(Map<String, dynamic>.from(payload)),
      );
      _syncChannel!.onBroadcast(
        event: 'playback_sync',
        callback: (payload) => handlePlaybackSyncPayload(Map<String, dynamic>.from(payload)),
      );
      _syncChannel!.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _broadcastSync('SYNC_REQUEST', _songPosition.inSeconds);
        }
      });
    } catch (_) {}
  }

  Future<void> handlePlaybackSyncPayload(Map<String, dynamic> payload) async {
    final senderId = payload['senderId']?.toString() ?? '';
    if (_syncUserId.isNotEmpty && senderId.isNotEmpty && senderId == _syncUserId) {
      return;
    }
    final eventId = payload['eventId']?.toString();
    if (eventId != null && eventId.isNotEmpty) {
      if (eventId == _lastHandledSyncEventId) return;
      _lastHandledSyncEventId = eventId;
    }

    final type = payload['type'] as String?;

    // Partner just joined Listen Together and asked for current playback state
    if (type == 'SYNC_REQUEST') {
      if (_songs.isNotEmpty && currentSong.id != 'empty' && _isSongPlaying) {
        _broadcastSync('PLAY', _songPosition.inSeconds);
      }
      return;
    }

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

    final bool switchedTrack = matchIdx != -1 && matchIdx != _currentSongIndex;
    if (switchedTrack) {
      _currentSongIndex = matchIdx;
      _songDuration = Duration(seconds: _songs[matchIdx].durationSeconds);
    }

    if (type == 'SELECT' || type == 'PLAY') {
      if (type == 'PLAY' && !switchedTrack && (_songPlayer.state == PlayerState.paused || _songPlayer.state == PlayerState.playing)) {
        if (positionSec != null && (_songPosition.inSeconds - positionSec).abs() > 2) {
          final target = Duration(seconds: positionSec);
          _songPosition = target;
          songPositionNotifier.value = target;
          await _songPlayer.seek(target);
        }
        _isSongPlaying = true;
        await _songPlayer.resume();
        _syncNotificationState();
      } else {
        final startPos = Duration(seconds: positionSec ?? 0);
        _songPosition = startPos;
        songPositionNotifier.value = startPos;
        _isSongPlaying = true;
        await _playCurrentSongWithCrossfade();
        if (positionSec != null && positionSec > 2) {
          await _songPlayer.seek(startPos);
        }
      }
    } else if (type == 'PAUSE') {
      _isSongPlaying = false;
      _syncNotificationState();
      await _songPlayer.pause();
      if (positionSec != null && (_songPosition.inSeconds - positionSec).abs() > 2) {
        final target = Duration(seconds: positionSec);
        _songPosition = target;
        songPositionNotifier.value = target;
        await _songPlayer.seek(target);
      }
    } else if (type == 'SEEK' && positionSec != null) {
      final target = Duration(seconds: positionSec);
      _songPosition = target;
      songPositionNotifier.value = target;
      await _songPlayer.seek(target);
    }
    notifyListeners();
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
    if (!_isListenTogetherActive && _syncChannel == null && _syncSpaceId.isEmpty) return;
    try {
      final payload = {
        'type': type,
        'senderId': _syncUserId,
        'eventId': '${_syncUserId}_${DateTime.now().microsecondsSinceEpoch}',
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

      if (_syncChannel != null) {
        _syncChannel!.sendBroadcastMessage(
          event: 'playback_update',
          payload: payload,
        );
        _syncChannel!.sendBroadcastMessage(
          event: 'playback_sync',
          payload: payload,
        );
      }

      if (_syncSpaceId.isNotEmpty) {
        SupabaseService.broadcastEvent(
          spaceId: _syncSpaceId,
          eventType: 'MUSIC_PLAYBACK',
          payload: payload,
        );
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // DUCKING FOR MEDIA & TOP BAR QUICK TOGGLE
  // -------------------------------------------------------------
  bool _wasSongMuted = false;
  bool _wasAtmosphereMuted = false;

  /// Top Bar Master Mute / Unmute Toggle:
  /// Instantly turns off/on any currently playing song or atmosphere soundscape with 0ms UI delay.
  Future<void> toggleMasterMute() async {
    final currentlyPlaying = isPlaying;

    if (currentlyPlaying) {
      // 1. INSTANT OPTIMISTIC UI FLIP (0ms reaction, zero delay):
      _wasSongMuted = _isSongPlaying;
      _wasAtmosphereMuted = _isAtmospherePlaying;
      _isSongPlaying = false;
      _isAtmospherePlaying = false;
      notifyListeners();

      // 2. Dispatch audio pause asynchronously in background:
      if (_wasSongMuted) {
        _syncNotificationState();
        _broadcastSync('PAUSE', _songPosition.inSeconds);
        _songPlayer.pause().catchError((e) {
          debugPrint('Error pausing song in mute: $e');
        });
      }
      if (_wasAtmosphereMuted) {
        pauseAtmosphere().catchError((e) {
          debugPrint('Error pausing atmosphere in mute: $e');
        });
      }
    } else {
      // 1. INSTANT OPTIMISTIC UI FLIP (0ms reaction, zero delay):
      final shouldResumeSong = _wasSongMuted || (_songs.isNotEmpty && !_wasAtmosphereMuted);
      final shouldResumeAtmo = _wasAtmosphereMuted || (!_wasSongMuted && _songs.isEmpty);

      if (shouldResumeSong) _isSongPlaying = true;
      if (shouldResumeAtmo) _isAtmospherePlaying = true;
      notifyListeners();

      // 2. Resume audio in background:
      try {
        if (shouldResumeSong) {
          await resumeSong();
        }
        if (shouldResumeAtmo) {
          await resumeAtmosphere();
        }
      } catch (e) {
        debugPrint('Error resuming audio in unmute: $e');
      } finally {
        _wasSongMuted = false;
        _wasAtmosphereMuted = false;
        _syncNotificationState();
        notifyListeners();
      }
    }
  }

  Future<void> toggleMusic() async {
    await toggleMasterMute();
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
