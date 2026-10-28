import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Source;
import '../data/models/memory_item.dart';
import '../data/models/letter_item.dart';
import '../data/models/milestone_item.dart';
import '../data/services/supabase_service.dart';
import '../data/services/firebase_service.dart';
import 'audio_provider.dart';

class MemoriesProvider extends ChangeNotifier {
  List<MemoryItem> _memories = [];
  List<LetterItem> _letters = [];
  List<MilestoneItem> _milestones = [];
  bool _isLoading = false;
  String _mediaFilter = 'all'; // 'all', 'photos', 'videos', 'audio'
  String _searchQuery = '';
  int _activeStackIndex = 0;

  // Voice whisper playback
  final AudioPlayer _voicePlayer = AudioPlayer();
  String? _playingVoiceId;
  Duration _voicePosition = Duration.zero;
  Duration _voiceDuration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;

  List<MemoryItem> get memories => _memories;
  List<LetterItem> get letters => _letters;
  List<MilestoneItem> get milestones => _milestones;
  bool get isLoading => _isLoading;
  String get mediaFilter => _mediaFilter;
  String get searchQuery => _searchQuery;
  int get activeStackIndex => _activeStackIndex;
  String? get playingVoiceId => _playingVoiceId;
  Duration get voicePosition => _voicePosition;
  Duration get voiceDuration => _voiceDuration;
  bool get isVoicePlaying => _playerState == PlayerState.playing;

  StreamSubscription? _voicePosSub;
  StreamSubscription? _voiceDurSub;
  StreamSubscription? _voiceStateSub;
  StreamSubscription? _firestoreMilestonesSub;
  RealtimeChannel? _memoriesChannel;
  RealtimeChannel? _lettersChannel;
  RealtimeChannel? _milestonesChannel;

  MemoriesProvider() {
    _initVoicePlayerListeners();
  }

  void _initVoicePlayerListeners() {
    _voicePosSub = _voicePlayer.onPositionChanged.listen((pos) async {
      _voicePosition = pos;
      if (_voiceDuration.inMilliseconds == 0 || _voiceDuration == const Duration(seconds: 30)) {
        try {
          final d = await _voicePlayer.getDuration();
          if (d != null && d.inMilliseconds > 0) {
            _voiceDuration = d;
          }
        } catch (_) {}
      }
      notifyListeners();
    });
    _voiceDurSub = _voicePlayer.onDurationChanged.listen((dur) {
      if (dur.inMilliseconds > 0) {
        _voiceDuration = dur;
        notifyListeners();
      }
    });
    _voiceStateSub = _voicePlayer.onPlayerStateChanged.listen((state) {
      _playerState = state;
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        _playingVoiceId = null;
        _voicePosition = Duration.zero;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _voicePosSub?.cancel();
    _voiceDurSub?.cancel();
    _voiceStateSub?.cancel();
    _firestoreMilestonesSub?.cancel();
    _voicePlayer.dispose();
    final supabase = SupabaseService.client;
    if (supabase != null) {
      if (_memoriesChannel != null) supabase.removeChannel(_memoriesChannel!);
      if (_lettersChannel != null) supabase.removeChannel(_lettersChannel!);
      if (_milestonesChannel != null) supabase.removeChannel(_milestonesChannel!);
    }
    super.dispose();
  }

  void setFilter(String filter) {
    _mediaFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setActiveStackIndex(int index) {
    _activeStackIndex = index;
    notifyListeners();
  }

  List<MemoryItem> get filteredMemories {
    return _memories.where((m) {
      if (_mediaFilter == 'photos' && m.mediaType != 'photo') return false;
      if (_mediaFilter == 'videos' && m.mediaType != 'video') return false;
      if (_mediaFilter == 'audio' && m.mediaType != 'audio') return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = m.title.toLowerCase().contains(q);
        final matchesCaption = m.caption.toLowerCase().contains(q);
        return matchesTitle || matchesCaption;
      }
      return true;
    }).toList();
  }

  Future<void> initMemoriesSync({
    required String spaceId,
    required String currentUserId,
    String? partnerNickname,
  }) async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([
      fetchMemories(spaceId, currentUserId, partnerNickname),
      fetchLetters(spaceId, currentUserId, partnerNickname),
      fetchMilestones(spaceId, currentUserId, partnerNickname),
    ]);

    _isLoading = false;
    notifyListeners();

    // Setup Supabase Realtime Channels
    final supabase = SupabaseService.client;
    if (supabase != null) {
      _memoriesChannel = supabase
          .channel('memories_$spaceId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'memories',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'space_id',
              value: spaceId,
            ),
            callback: (_) => fetchMemories(spaceId, currentUserId, partnerNickname),
          )
          .subscribe();

      _lettersChannel = supabase
          .channel('letters_$spaceId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'letters',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'space_id',
              value: spaceId,
            ),
            callback: (_) => fetchLetters(spaceId, currentUserId, partnerNickname),
          )
          .subscribe();

      _milestonesChannel = supabase
          .channel('milestones_$spaceId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'milestones',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'space_id',
              value: spaceId,
            ),
            callback: (_) => fetchMilestones(spaceId, currentUserId, partnerNickname),
          )
          .subscribe();
    }

    // Firestore Dual-Sync Realtime Listener for Milestones
    try {
      _firestoreMilestonesSub?.cancel();
      _firestoreMilestonesSub = FirebaseService.firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('milestones')
          .snapshots()
          .listen((snapshot) {
            final incoming = snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return MilestoneItem.fromJson(
                data,
                currentUserId: currentUserId,
                partnerNickname: partnerNickname,
              );
            }).toList();
            _mergeMilestones(incoming);
          }, onError: (err) {
            debugPrint('Firestore milestones listener err: $err');
          });
    } catch (_) {}
  }

  Future<void> fetchMemories(
    String spaceId,
    String currentUserId,
    String? partnerNickname,
  ) async {
    try {
      final supabase = SupabaseService.client;
      if (supabase == null) return;

      final data = await supabase
          .from('memories')
          .select()
          .eq('space_id', spaceId)
          .order('created_at', ascending: false);

      _memories = (data as List)
          .map((row) => MemoryItem.fromJson(
                row as Map<String, dynamic>,
                currentUserId: currentUserId,
                partnerNickname: partnerNickname,
              ))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchLetters(
    String spaceId,
    String currentUserId,
    String? partnerNickname,
  ) async {
    try {
      final supabase = SupabaseService.client;
      if (supabase == null) return;

      final data = await supabase
          .from('letters')
          .select()
          .eq('space_id', spaceId)
          .order('created_at', ascending: false);

      _letters = (data as List)
          .map((row) => LetterItem.fromJson(
                row as Map<String, dynamic>,
                currentUserId: currentUserId,
                partnerNickname: partnerNickname,
              ))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchMilestones(
    String spaceId,
    String currentUserId,
    String? partnerNickname,
  ) async {
    try {
      final supabase = SupabaseService.client;
      if (supabase == null) return;

      final data = await supabase
          .from('milestones')
          .select()
          .eq('space_id', spaceId)
          .order('event_date', ascending: false);

      final list = (data as List)
          .map((row) => MilestoneItem.fromJson(
                row as Map<String, dynamic>,
                currentUserId: currentUserId,
                partnerNickname: partnerNickname,
              ))
          .toList();
      _mergeMilestones(list);
    } catch (_) {}
  }

  void _mergeMilestones(List<MilestoneItem> incoming) {
    final Map<String, MilestoneItem> map = {for (final m in _milestones) m.id: m};
    for (final item in incoming) {
      map[item.id] = item;
    }
    _milestones = map.values.toList()
      ..sort((a, b) => b.rawDate.compareTo(a.rawDate));
    notifyListeners();
  }

  // Voice whisper playback with ambient audio ducking
  Future<void> playVoiceWhisper(
    String id,
    String url, {
    AudioProvider? ambientAudio,
  }) async {
    if (_playingVoiceId == id && isVoicePlaying) {
      await _voicePlayer.pause();
      ambientAudio?.restoreFromMedia();
      return;
    }

    try {
      ambientAudio?.duckForMedia();
      _playingVoiceId = id;
      notifyListeners();

      await _voicePlayer.stop();

      Source source;
      final cleanUrl = url.trim();
      if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
        source = UrlSource(cleanUrl);
      } else if (cleanUrl.startsWith('assets/')) {
        source = AssetSource(cleanUrl);
      } else {
        source = DeviceFileSource(cleanUrl.replaceFirst('file://', ''));
      }

      await _voicePlayer.play(source);
      try {
        final d = await _voicePlayer.getDuration();
        if (d != null && d.inMilliseconds > 0) {
          _voiceDuration = d;
          notifyListeners();
        }
      } catch (_) {}
    } catch (_) {
      ambientAudio?.restoreFromMedia();
      _playingVoiceId = null;
      notifyListeners();
    }
  }

  Future<void> seekVoiceWhisper(Duration target) async {
    try {
      await _voicePlayer.seek(target);
      _voicePosition = target;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> stopVoiceWhisper({AudioProvider? ambientAudio}) async {
    await _voicePlayer.stop();
    ambientAudio?.restoreFromMedia();
    _playingVoiceId = null;
    notifyListeners();
  }

  Future<void> addMemory({
    required String spaceId,
    required String title,
    required String caption,
    required String mediaUrl,
    String? voiceUrl,
    required String author,
    required String currentUserId,
    String? partnerNickname,
  }) async {
    final newId = 'mem_${DateTime.now().millisecondsSinceEpoch}';
    final nowIso = DateTime.now().toIso8601String();

    final optimisticItem = MemoryItem(
      id: newId,
      title: title,
      caption: caption,
      mediaUrl: mediaUrl,
      voiceUrl: voiceUrl,
      mediaType: mediaUrl.isEmpty
          ? 'audio'
          : (mediaUrl.contains('.mp4') || mediaUrl.contains('.mov') ? 'video' : 'photo'),
      createdAt: nowIso,
      rawDate: nowIso,
      author: author,
      authorName: 'You',
      isMine: true,
    );

    _memories.insert(0, optimisticItem);
    notifyListeners();

    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('memories').insert(optimisticItem.toJson(spaceId: spaceId));
      }
    } catch (_) {}
  }

  Future<void> deleteMemory(String spaceId, String memoryId) async {
    _memories.removeWhere((m) => m.id == memoryId);
    notifyListeners();

    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('memories').delete().eq('id', memoryId);
      }
    } catch (_) {}
  }

  Future<void> sendLetter({
    required String spaceId,
    required String title,
    required String body,
    required String sealType,
    required String category,
    String? sealedUntilDate,
    required String author,
  }) async {
    final newId = 'let_${DateTime.now().millisecondsSinceEpoch}';
    final nowIso = DateTime.now().toIso8601String();

    final newLetter = LetterItem(
      id: newId,
      title: title,
      body: body,
      author: author,
      authorName: 'You',
      isMine: true,
      createdAt: nowIso,
      writtenDate: nowIso,
      sealType: sealType,
      category: category,
      sealedUntilDate: sealedUntilDate,
      isRead: false,
    );

    _letters.insert(0, newLetter);
    notifyListeners();

    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('letters').insert(newLetter.toJson(spaceId: spaceId));
      }
    } catch (_) {}
  }

  Future<void> markLetterAsRead(String spaceId, String letterId) async {
    final idx = _letters.indexWhere((l) => l.id == letterId);
    if (idx != -1) {
      final updated = LetterItem(
        id: _letters[idx].id,
        title: _letters[idx].title,
        body: _letters[idx].body,
        author: _letters[idx].author,
        authorName: _letters[idx].authorName,
        isMine: _letters[idx].isMine,
        createdAt: _letters[idx].createdAt,
        writtenDate: _letters[idx].writtenDate,
        sealType: _letters[idx].sealType,
        category: _letters[idx].category,
        sealedUntilDate: _letters[idx].sealedUntilDate,
        isRead: true,
      );
      _letters[idx] = updated;
      notifyListeners();

      try {
        final supabase = SupabaseService.client;
        if (supabase != null) {
          await supabase.from('letters').update({'is_read': true}).eq('id', letterId);
        }
      } catch (_) {}
    }
  }

  Future<void> deleteLetter(String spaceId, String letterId) async {
    _letters.removeWhere((l) => l.id == letterId);
    notifyListeners();

    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('letters').delete().eq('id', letterId);
      }
    } catch (_) {}
  }

  Future<void> addMilestone({
    required String spaceId,
    required String title,
    required String date,
    required String story,
    required String author,
    String? imageUrl,
    String? audioUrl,
    int? audioDuration,
  }) async {
    final newId = 'mls_${DateTime.now().millisecondsSinceEpoch}';

    final item = MilestoneItem(
      id: newId,
      title: title,
      date: date,
      rawDate: date,
      story: story,
      addedBy: 'You',
      authorId: author,
      isMine: true,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      audioDuration: audioDuration,
    );

    _milestones.insert(0, item);
    _milestones.sort((a, b) => b.rawDate.compareTo(a.rawDate));
    notifyListeners();

    // 1. Dual-Sync: Save to Supabase
    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('milestones').insert(item.toJson(spaceId: spaceId, author: author));
      }
    } catch (e) {
      debugPrint('Supabase milestone insert fallback: $e');
    }

    // 2. Dual-Sync: Save to Firebase Firestore
    try {
      await FirebaseService.firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('milestones')
          .doc(newId)
          .set(item.toJson(spaceId: spaceId, author: author));
    } catch (e) {
      debugPrint('Firestore milestone insert error: $e');
    }
  }

  Future<void> deleteMilestone(String spaceId, String milestoneId) async {
    _milestones.removeWhere((m) => m.id == milestoneId);
    notifyListeners();

    // 1. Delete from Supabase
    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('milestones').delete().eq('id', milestoneId);
      }
    } catch (_) {}

    // 2. Delete from Firebase Firestore
    try {
      await FirebaseService.firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('milestones')
          .doc(milestoneId)
          .delete();
    } catch (_) {}
  }
}
