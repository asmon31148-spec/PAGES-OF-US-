import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Source;
import '../data/models/memory_item.dart';
import '../data/models/letter_item.dart';
import '../data/models/milestone_item.dart';
import '../data/services/supabase_service.dart';
import '../data/services/firebase_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/audio_cache_service.dart';
import 'audio_provider.dart';
import '../core/services/voice_playback_service.dart';

class MemoriesProvider extends ChangeNotifier {
  List<MemoryItem> _memories = [];
  List<LetterItem> _letters = [];
  List<MilestoneItem> _milestones = [];
  bool _isLoading = false;
  String _mediaFilter = 'all'; // 'all', 'photos', 'videos', 'audio'
  String _searchQuery = '';
  int _activeStackIndex = 0;

  // Voice whisper playback via VoicePlaybackService
  VoicePlaybackService get _voiceService => VoicePlaybackService.instance;
  String? get playingVoiceId => _voiceService.activeId;
  Duration get voicePosition => _voiceService.position;
  Duration get voiceDuration => _voiceService.duration;
  bool get isVoicePlaying => _voiceService.isPlaying;
  double get playbackSpeed => _voiceService.playbackSpeed;
  ValueNotifier<Duration> get voicePositionNotifier => _voiceService.positionNotifier;

  List<MemoryItem> get memories => _memories;
  List<LetterItem> get letters => _letters;
  List<MilestoneItem> get milestones => _milestones;
  bool get isLoading => _isLoading;
  String get mediaFilter => _mediaFilter;
  String get searchQuery => _searchQuery;
  int get activeStackIndex => _activeStackIndex;

  StreamSubscription? _voicePosSub;
  StreamSubscription? _voiceDurSub;
  StreamSubscription? _voiceStateSub;
  StreamSubscription? _firestoreMilestonesSub;
  RealtimeChannel? _memoriesChannel;
  RealtimeChannel? _lettersChannel;
  RealtimeChannel? _milestonesChannel;

  String? _currentUserId;
  String? _lastPreservedMemoryId;
  String? _lastSentLetterId;

  MemoriesProvider() {
    _voiceService.addListener(_onVoicePlaybackChanged);
  }

  void _onVoicePlaybackChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _voiceService.removeListener(_onVoicePlaybackChanged);
    _firestoreMilestonesSub?.cancel();
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
    _currentUserId = currentUserId;
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
      _memoriesChannel = supabase.channel(
        'memories_$spaceId',
        opts: const RealtimeChannelConfig(ack: false, self: false),
      );
      _memoriesChannel!
          .onBroadcast(
            event: 'NEW_MEMORY',
            callback: (rawPayload) {
              final data = (rawPayload['payload'] is Map<String, dynamic>)
                  ? rawPayload['payload'] as Map<String, dynamic>
                  : rawPayload;
              final senderId = data['senderId']?.toString() ?? rawPayload['senderId']?.toString();
              final memoryId = data['id']?.toString() ?? rawPayload['id']?.toString() ?? '';

              // Never notify if sender is the current user or this is the memory we just created
              if (senderId != null &&
                  senderId.isNotEmpty &&
                  senderId != _currentUserId &&
                  memoryId != _lastPreservedMemoryId) {
                NotificationService.showNewMemoryNotification(
                  partnerNickname: partnerNickname ?? 'Partner',
                  type: data['type']?.toString() ?? 'photo',
                  title: data['title']?.toString() ?? 'New Memory',
                  caption: data['caption']?.toString() ?? '',
                  id: memoryId,
                );
              }
            },
          )
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

      _lettersChannel = supabase.channel(
        'letters_$spaceId',
        opts: const RealtimeChannelConfig(ack: false, self: false),
      );
      _lettersChannel!
          .onBroadcast(
            event: 'NEW_LETTER',
            callback: (rawPayload) {
              final data = (rawPayload['payload'] is Map<String, dynamic>)
                  ? rawPayload['payload'] as Map<String, dynamic>
                  : rawPayload;
              final senderId = data['senderId']?.toString() ?? rawPayload['senderId']?.toString();
              final letterId = data['id']?.toString() ?? rawPayload['id']?.toString() ?? '';

              // Never notify if sender is the current user or this is the letter we just created
              if (senderId != null &&
                  senderId.isNotEmpty &&
                  senderId != _currentUserId &&
                  letterId != _lastSentLetterId) {
                NotificationService.showNewMemoryNotification(
                  partnerNickname: partnerNickname ?? 'Partner',
                  type: 'letter',
                  title: data['title']?.toString() ?? 'Love Letter',
                  caption: data['caption']?.toString() ?? '',
                  id: letterId,
                );
              }
            },
          )
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

      // Background prefetch for instant 0ms voice whisper playback
      final voiceUrls = _memories
          .where((m) => m.mediaType == 'audio' || (m.voiceUrl != null && m.voiceUrl!.isNotEmpty))
          .map((m) => (m.voiceUrl != null && m.voiceUrl!.isNotEmpty) ? m.voiceUrl! : m.mediaUrl)
          .toList();
      AudioCacheService.prefetchList(voiceUrls);

      // 2nd: Schedule weekly random old memories recap
      if (_memories.isNotEmpty) {
        final randomItem = _memories[Random().nextInt(_memories.length)];
        NotificationService.scheduleWeeklyMemoryRecap(
          memoryId: randomItem.id,
          memoryTitle: randomItem.title,
          memoryCaption: randomItem.caption,
        );
      }

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

  // Voice whisper playback with unified VoicePlaybackService
  Future<void> playVoiceWhisper(
    String id,
    String url, {
    AudioProvider? ambientAudio,
    int? durationSeconds,
  }) async {
    await _voiceService.togglePlay(
      id: id,
      url: url,
      durationSeconds: durationSeconds,
      ambientAudio: ambientAudio,
    );
  }

  Future<void> togglePlaybackSpeed() async {
    await _voiceService.togglePlaybackSpeed();
  }

  Future<void> seekVoiceWhisper(Duration target) async {
    await _voiceService.seek(target);
  }

  Future<void> stopVoiceWhisper({AudioProvider? ambientAudio}) async {
    await _voiceService.stop();
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

    _currentUserId = currentUserId;
    _lastPreservedMemoryId = newId;
    _memories.insert(0, optimisticItem);
    notifyListeners();

    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('memories').insert(optimisticItem.toJson(spaceId: spaceId));
        // 4th: Broadcast new memory event to partner
        try {
          final ch = supabase.channel('memories_$spaceId');
          await ch.sendBroadcastMessage(
            event: 'NEW_MEMORY',
            payload: {
              'senderId': currentUserId,
              'type': optimisticItem.mediaType,
              'title': title,
              'caption': caption,
              'id': newId,
            },
          );
        } catch (_) {}
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

    _currentUserId = author;
    _lastSentLetterId = newId;
    _letters.insert(0, newLetter);
    notifyListeners();

    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('letters').insert(newLetter.toJson(spaceId: spaceId));
        // 4th: Broadcast new letter event to partner
        try {
          final ch = supabase.channel('letters_$spaceId');
          await ch.sendBroadcastMessage(
            event: 'NEW_LETTER',
            payload: {
              'senderId': author,
              'type': 'letter',
              'title': title,
              'caption': body.length > 50 ? '${body.substring(0, 50)}...' : body,
              'id': newId,
            },
          );
        } catch (_) {}
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
