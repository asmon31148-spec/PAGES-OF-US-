import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Source;
import '../data/models/memory_item.dart';
import '../data/models/letter_item.dart';
import '../data/models/milestone_item.dart';
import '../core/utils/author_identity.dart';
import '../core/utils/ownership_helper.dart';
import '../data/services/supabase_service.dart';
import '../data/services/firebase_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/audio_cache_service.dart';
import '../core/services/deleted_ids_store.dart';
import '../core/services/device_status_service.dart';
import '../core/services/media_upload_service.dart';
import 'audio_provider.dart';
import 'auth_provider.dart';
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
    AuthProvider.registerSignOutHook(resetState);
    _voiceService.addListener(_onVoicePlaybackChanged);
  }

  void _onVoicePlaybackChanged() {
    notifyListeners();
  }

  /// Wipes ALL in-memory state when user logs out.
  /// Called by AuthProvider.signOut() before FirebaseService.signOut().
  void resetState() {
    _firestoreMilestonesSub?.cancel();
    _firestoreMilestonesSub = null;
    final supabase = SupabaseService.client;
    if (supabase != null) {
      if (_memoriesChannel != null) supabase.removeChannel(_memoriesChannel!);
      if (_lettersChannel != null) supabase.removeChannel(_lettersChannel!);
      if (_milestonesChannel != null) supabase.removeChannel(_milestonesChannel!);
    }
    _memoriesChannel = null;
    _lettersChannel = null;
    _milestonesChannel = null;
    _memories = [];
    _letters = [];
    _milestones = [];
    _mediaFilter = 'all';
    _searchQuery = '';
    _activeStackIndex = 0;
    _currentUserId = null;
    _currentUserNickname = null;
    _currentPartnerId = null;
    _currentPartnerNickname = null;
    _currentSpaceId = null;
    _lastPreservedMemoryId = null;
    _lastSentLetterId = null;
    _isLoading = false;
    try { _voiceService.stop(); } catch (_) {}
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

  String? _currentUserNickname;
  String? _currentPartnerId;
  String? _currentPartnerNickname;
  String? _currentSpaceId;
  final Set<String> _discoveredMyLegacyUids = {};
  final Set<String> _discoveredPartnerLegacyUids = {};

  void clearPartnerState() {
    _currentPartnerId = null;
    _currentPartnerNickname = null;
    _discoveredPartnerLegacyUids.clear();
    final uid = _currentUserId ?? '';
    if (uid.isNotEmpty) {
      _memories = _memories.where((m) => _isMyItem(m.author)).toList();
      _letters = _letters.where((l) => _isMyItem(l.author)).toList();
      _milestones = _milestones.where((m) => _isMyItem(m.authorId)).toList();
    } else {
      _memories = [];
      _letters = [];
      _milestones = [];
    }
    notifyListeners();
  }

  bool _isMyItem(String? rawAuthor) {
    final uid = _currentUserId ?? '';
    if (uid.isEmpty) return false;
    return OwnershipHelper.isOwner(
      ownerUid: OwnershipHelper.extractOwnerUid(rawAuthor),
      legacyAuthor: rawAuthor,
      myUid: uid,
      myNickname: _currentUserNickname,
      myLegacyUids: _discoveredMyLegacyUids,
      partnerUid: _currentPartnerId,
      activeSpaceId: _currentSpaceId,
    );
  }

  bool _canViewRawAuthor(String? rawAuthor, {String? partnerId, String? partnerNickname, String? itemSpaceId}) {
    final uid = _currentUserId ?? '';
    if (uid.isEmpty) return false;
    final pid = partnerId ?? _currentPartnerId;
    final pNick = partnerNickname ?? _currentPartnerNickname;
    return OwnershipHelper.canViewItem(
      ownerUid: OwnershipHelper.extractOwnerUid(rawAuthor),
      legacyAuthor: rawAuthor,
      myUid: uid,
      myNickname: _currentUserNickname,
      myLegacyUids: _discoveredMyLegacyUids,
      partnerUid: pid,
      partnerNickname: pNick,
      partnerLegacyUids: _discoveredPartnerLegacyUids,
      activeSpaceId: _currentSpaceId,
      itemSpaceId: itemSpaceId,
    );
  }

  bool _canDeleteRawAuthor(String? rawAuthor) {
    final uid = _currentUserId ?? '';
    if (uid.isEmpty) return false;
    return OwnershipHelper.canDeleteItem(
      ownerUid: OwnershipHelper.extractOwnerUid(rawAuthor),
      legacyAuthor: rawAuthor,
      myUid: uid,
      myNickname: _currentUserNickname,
      myLegacyUids: _discoveredMyLegacyUids,
      partnerUid: _currentPartnerId,
      activeSpaceId: _currentSpaceId,
    );
  }

  bool _learnLegacyAliases(
    List<dynamic> rows, {
    required String currentUserId,
    String? currentUserNickname,
    String? partnerId,
    String? partnerNickname,
    required String spaceId,
  }) {
    final beforeCount = _discoveredMyLegacyUids.length + _discoveredPartnerLegacyUids.length;
    OwnershipHelper.collectLegacyUidAliases(
      rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      myUid: currentUserId,
      myNickname: currentUserNickname ?? _currentUserNickname,
      partnerUid: partnerId ?? _currentPartnerId,
      partnerNickname: partnerNickname ?? _currentPartnerNickname,
      activeSpaceId: spaceId,
      myLegacyUids: _discoveredMyLegacyUids,
      partnerLegacyUids: _discoveredPartnerLegacyUids,
    );
    return (_discoveredMyLegacyUids.length + _discoveredPartnerLegacyUids.length) > beforeCount;
  }

  bool _isSharedSpace({required String spaceId, String? partnerId}) {
    if (spaceId.isEmpty || spaceId == 'default_space') return false;
    return (partnerId != null && partnerId.isNotEmpty) ||
        !spaceId.startsWith('solo_');
  }

  Future<void> initMemoriesSync({
    required String spaceId,
    required String currentUserId,
    String? currentUserNickname,
    String? partnerId,
    String? partnerNickname,
  }) async {
    if (spaceId.isEmpty || spaceId == 'default_space' || currentUserId.isEmpty) {
      return;
    }
    AuthProvider.registerDisconnectHook(clearPartnerState);

    if (_currentUserId == null || _currentUserId != currentUserId) {
      _discoveredMyLegacyUids.clear();
      _discoveredPartnerLegacyUids.clear();
    }
    if (partnerId == null || partnerId.isEmpty || _currentPartnerId != partnerId) {
      _discoveredPartnerLegacyUids.clear();
    }

    _currentUserId = currentUserId;
    if (currentUserNickname != null && currentUserNickname.trim().isNotEmpty) {
      _currentUserNickname = currentUserNickname.trim();
    }
    _currentPartnerId = partnerId;
    _currentPartnerNickname = partnerNickname;
    _currentSpaceId = spaceId;
    if (partnerId == null || partnerId.isEmpty) {
      _memories = _memories.where((m) => _isMyItem(m.author)).toList();
      _letters = _letters.where((l) => _isMyItem(l.author)).toList();
      _milestones = _milestones.where((m) => _isMyItem(m.authorId)).toList();
    }
    _isLoading = true;
    notifyListeners();

    final prevAliasCount = _discoveredMyLegacyUids.length + _discoveredPartnerLegacyUids.length;
    await Future.wait([
      fetchMemories(
        spaceId: spaceId,
        currentUserId: currentUserId,
        currentUserNickname: _currentUserNickname,
        partnerId: partnerId,
        partnerNickname: partnerNickname,
      ),
      fetchLetters(
        spaceId: spaceId,
        currentUserId: currentUserId,
        currentUserNickname: _currentUserNickname,
        partnerId: partnerId,
        partnerNickname: partnerNickname,
      ),
      fetchMilestones(
        spaceId: spaceId,
        currentUserId: currentUserId,
        currentUserNickname: _currentUserNickname,
        partnerId: partnerId,
        partnerNickname: partnerNickname,
      ),
    ]);

    // If first pass uncovered legacy prior UIDs (e.g. Nickname:::OldUid), re-fetch once
    // so bare historical UID rows in earlier spaces also appear immediately.
    if (_discoveredMyLegacyUids.length + _discoveredPartnerLegacyUids.length > prevAliasCount) {
      await Future.wait([
        fetchMemories(
          spaceId: spaceId,
          currentUserId: currentUserId,
          currentUserNickname: _currentUserNickname,
          partnerId: partnerId,
          partnerNickname: partnerNickname,
        ),
        fetchLetters(
          spaceId: spaceId,
          currentUserId: currentUserId,
          currentUserNickname: _currentUserNickname,
          partnerId: partnerId,
          partnerNickname: partnerNickname,
        ),
        fetchMilestones(
          spaceId: spaceId,
          currentUserId: currentUserId,
          currentUserNickname: _currentUserNickname,
          partnerId: partnerId,
          partnerNickname: partnerNickname,
        ),
      ]);
    }

    _isLoading = false;
    notifyListeners();

    // Setup Supabase Realtime Channels
    final supabase = SupabaseService.client;
    if (supabase != null) {
      if (_memoriesChannel != null) {
        await supabase.removeChannel(_memoriesChannel!);
        _memoriesChannel = null;
      }
      if (_lettersChannel != null) {
        await supabase.removeChannel(_lettersChannel!);
        _lettersChannel = null;
      }
      if (_milestonesChannel != null) {
        await supabase.removeChannel(_milestonesChannel!);
        _milestonesChannel = null;
      }

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
            callback: (_) => fetchMemories(
              spaceId: _currentSpaceId ?? spaceId,
              currentUserId: _currentUserId ?? currentUserId,
              currentUserNickname: _currentUserNickname,
              partnerId: _currentPartnerId,
              partnerNickname: _currentPartnerNickname,
            ),
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
            callback: (_) => fetchLetters(
              spaceId: _currentSpaceId ?? spaceId,
              currentUserId: _currentUserId ?? currentUserId,
              currentUserNickname: _currentUserNickname,
              partnerId: _currentPartnerId,
              partnerNickname: _currentPartnerNickname,
            ),
          )
          .subscribe();

      _milestonesChannel = supabase
          .channel('milestones_$spaceId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'milestones',
            callback: (_) => fetchMilestones(
              spaceId: _currentSpaceId ?? spaceId,
              currentUserId: _currentUserId ?? currentUserId,
              currentUserNickname: _currentUserNickname,
              partnerId: _currentPartnerId,
              partnerNickname: _currentPartnerNickname,
            ),
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
            final uid = _currentUserId ?? currentUserId;
            final pid = _currentPartnerId ?? partnerId;
            final myNick = _currentUserNickname ?? currentUserNickname;
            final pNick = _currentPartnerNickname ?? partnerNickname;
            final tombstones = DeletedIdsStore.getIds('milestones');
            final rawRows = snapshot.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              data['space_id'] ??= spaceId;
              return data;
            }).toList();
            _learnLegacyAliases(
              rawRows,
              currentUserId: uid,
              currentUserNickname: myNick,
              partnerId: pid,
              partnerNickname: pNick,
              spaceId: spaceId,
            );
            final incoming = rawRows
                .where((d) => !tombstones.contains(d['id']?.toString()))
                .where((d) {
                  final rawAuthor = (d['author'] ?? d['author_id'])?.toString();
                  return _canViewRawAuthor(
                    rawAuthor,
                    partnerId: pid,
                    partnerNickname: pNick,
                    itemSpaceId: d['space_id']?.toString(),
                  );
                })
                .map((data) => MilestoneItem.fromJson(
                      data,
                      currentUserId: uid,
                      currentUserNickname: myNick,
                      partnerId: pid,
                      partnerNickname: pNick,
                      myLegacyUids: _discoveredMyLegacyUids,
                      partnerLegacyUids: _discoveredPartnerLegacyUids,
                    ))
                .toList();
            _mergeMilestones(incoming);
          }, onError: (err) {
            debugPrint('Firestore milestones listener err: $err');
          });
    } catch (_) {}
  }

  /// Re-fetches all shared memories, letters, and milestones for the active space.
  Future<void> refreshAll() async {
    final spaceId = _currentSpaceId;
    final userId = _currentUserId;
    if (spaceId == null || spaceId.isEmpty || spaceId == 'default_space' || userId == null) {
      return;
    }
    await Future.wait([
      fetchMemories(
        spaceId: spaceId,
        currentUserId: userId,
        currentUserNickname: _currentUserNickname,
        partnerId: _currentPartnerId,
        partnerNickname: _currentPartnerNickname,
      ),
      fetchLetters(
        spaceId: spaceId,
        currentUserId: userId,
        currentUserNickname: _currentUserNickname,
        partnerId: _currentPartnerId,
        partnerNickname: _currentPartnerNickname,
      ),
      fetchMilestones(
        spaceId: spaceId,
        currentUserId: userId,
        currentUserNickname: _currentUserNickname,
        partnerId: _currentPartnerId,
        partnerNickname: _currentPartnerNickname,
      ),
    ]);
  }

  String _buildCoupleOrFilter({
    required String spaceId,
    required String currentUserId,
    String? partnerId,
  }) {
    final clauses = <String>[];
    if (spaceId.isNotEmpty && spaceId != 'default_space') {
      clauses.add('space_id.eq.$spaceId');
    }
    if (currentUserId.isNotEmpty) {
      clauses.add('author.ilike.%$currentUserId%');
    }
    for (final legacyUid in _discoveredMyLegacyUids) {
      if (legacyUid.isNotEmpty) {
        clauses.add('author.ilike.%$legacyUid%');
      }
    }
    final nick = (_currentUserNickname ?? '').trim();
    if (nick.length >= 3) {
      clauses.add('author.ilike.%$nick%');
    }
    if (partnerId != null && partnerId.isNotEmpty) {
      clauses.add('author.ilike.%$partnerId%');
      for (final pLegacy in _discoveredPartnerLegacyUids) {
        if (pLegacy.isNotEmpty) {
          clauses.add('author.ilike.%$pLegacy%');
        }
      }
    }
    return clauses.join(',');
  }

  void _healOrphanedRowSpaceIds(
    SupabaseClient supabase,
    String table,
    List<dynamic> rows, {
    required String spaceId,
    required String currentUserId,
    String? partnerId,
  }) {
    // Client-side recovery must NEVER silently mutate existing DB rows;
    // DB space/owner backfill runs strictly via user-approved SQL migration.
  }

  Future<void> _healSingleRowSpaceId(
    SupabaseClient supabase,
    String table,
    String rowId,
    String spaceId,
  ) async {
    try {
      await supabase.from(table).update({'space_id': spaceId}).eq('id', rowId);
    } catch (_) {}
  }

  Future<void> fetchMemories({
    required String spaceId,
    required String currentUserId,
    String? currentUserNickname,
    String? partnerId,
    String? partnerNickname,
  }) async {
    try {
      final supabase = SupabaseService.client;
      if (supabase == null) return;

      final orFilter = _buildCoupleOrFilter(
        spaceId: spaceId,
        currentUserId: currentUserId,
        partnerId: partnerId,
      );
      if (orFilter.isEmpty) return;

      final data = await supabase
          .from('memories')
          .select()
          .or(orFilter)
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(const Duration(seconds: 12));

      final rows = data as List;
      _healOrphanedRowSpaceIds(
        supabase,
        'memories',
        rows,
        spaceId: spaceId,
        currentUserId: currentUserId,
        partnerId: partnerId,
      );

      _learnLegacyAliases(
        rows,
        currentUserId: currentUserId,
        currentUserNickname: currentUserNickname ?? _currentUserNickname,
        partnerId: partnerId,
        partnerNickname: partnerNickname ?? _currentPartnerNickname,
        spaceId: spaceId,
      );

      final tombstones = DeletedIdsStore.getIds('memories');
      final effectivePid = partnerId ?? _currentPartnerId;
      final effectivePNick = partnerNickname ?? _currentPartnerNickname;
      _memories = rows
          .where((r) => r is Map && !tombstones.contains(r['id']?.toString()))
          .where((r) {
            final map = r as Map;
            final rawAuthor = (map['author'] ?? map['author_id'])?.toString();
            final itemSpace = map['space_id']?.toString();
            return _canViewRawAuthor(
              rawAuthor,
              partnerId: effectivePid,
              partnerNickname: effectivePNick,
              itemSpaceId: itemSpace,
            );
          })
          .map((row) => MemoryItem.fromJson(
                row as Map<String, dynamic>,
                currentUserId: currentUserId,
                currentUserNickname: currentUserNickname ?? _currentUserNickname,
                partnerId: effectivePid,
                partnerNickname: effectivePNick,
                myLegacyUids: _discoveredMyLegacyUids,
                partnerLegacyUids: _discoveredPartnerLegacyUids,
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
    } catch (e) {
      await DeviceStatusService.recordSyncError('fetch_memories', e.toString());
    }
  }

  Future<void> fetchLetters({
    required String spaceId,
    required String currentUserId,
    String? currentUserNickname,
    String? partnerId,
    String? partnerNickname,
  }) async {
    try {
      final supabase = SupabaseService.client;
      if (supabase == null) return;

      final orFilter = _buildCoupleOrFilter(
        spaceId: spaceId,
        currentUserId: currentUserId,
        partnerId: partnerId,
      );
      if (orFilter.isEmpty) return;

      final data = await supabase
          .from('letters')
          .select()
          .or(orFilter)
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(const Duration(seconds: 12));

      final rows = data as List;
      _healOrphanedRowSpaceIds(
        supabase,
        'letters',
        rows,
        spaceId: spaceId,
        currentUserId: currentUserId,
        partnerId: partnerId,
      );

      _learnLegacyAliases(
        rows,
        currentUserId: currentUserId,
        currentUserNickname: currentUserNickname ?? _currentUserNickname,
        partnerId: partnerId,
        partnerNickname: partnerNickname ?? _currentPartnerNickname,
        spaceId: spaceId,
      );

      final tombstones = DeletedIdsStore.getIds('letters');
      final effectivePid = partnerId ?? _currentPartnerId;
      final effectivePNick = partnerNickname ?? _currentPartnerNickname;
      _letters = rows
          .where((r) => r is Map && !tombstones.contains(r['id']?.toString()))
          .where((r) {
            final map = r as Map;
            final rawAuthor = (map['author'] ?? map['author_id'])?.toString();
            final itemSpace = map['space_id']?.toString();
            return _canViewRawAuthor(
              rawAuthor,
              partnerId: effectivePid,
              partnerNickname: effectivePNick,
              itemSpaceId: itemSpace,
            );
          })
          .map((row) => LetterItem.fromJson(
                row as Map<String, dynamic>,
                currentUserId: currentUserId,
                currentUserNickname: currentUserNickname ?? _currentUserNickname,
                partnerId: effectivePid,
                partnerNickname: effectivePNick,
                myLegacyUids: _discoveredMyLegacyUids,
                partnerLegacyUids: _discoveredPartnerLegacyUids,
              ))
          .toList();
      notifyListeners();
    } catch (e) {
      await DeviceStatusService.recordSyncError('fetch_letters', e.toString());
    }
  }

  Future<void> fetchMilestones({
    required String spaceId,
    required String currentUserId,
    String? currentUserNickname,
    String? partnerId,
    String? partnerNickname,
  }) async {
    try {
      final supabase = SupabaseService.client;
      if (supabase == null) return;

      final orFilter = _buildCoupleOrFilter(
        spaceId: spaceId,
        currentUserId: currentUserId,
        partnerId: partnerId,
      );
      if (orFilter.isEmpty) return;

      final data = await supabase
          .from('milestones')
          .select()
          .or(orFilter)
          .order('event_date', ascending: false)
          .limit(100)
          .timeout(const Duration(seconds: 12));

      final rows = data as List;
      _healOrphanedRowSpaceIds(
        supabase,
        'milestones',
        rows,
        spaceId: spaceId,
        currentUserId: currentUserId,
        partnerId: partnerId,
      );

      _learnLegacyAliases(
        rows,
        currentUserId: currentUserId,
        currentUserNickname: currentUserNickname ?? _currentUserNickname,
        partnerId: partnerId,
        partnerNickname: partnerNickname ?? _currentPartnerNickname,
        spaceId: spaceId,
      );

      final tombstones = DeletedIdsStore.getIds('milestones');
      final effectivePid = partnerId ?? _currentPartnerId;
      final effectivePNick = partnerNickname ?? _currentPartnerNickname;
      final list = rows
          .where((r) => r is Map && !tombstones.contains(r['id']?.toString()))
          .where((r) {
            final map = r as Map;
            final rawAuthor = (map['author'] ?? map['author_id'])?.toString();
            final itemSpace = map['space_id']?.toString();
            return _canViewRawAuthor(
              rawAuthor,
              partnerId: effectivePid,
              partnerNickname: effectivePNick,
              itemSpaceId: itemSpace,
            );
          })
          .map((row) => MilestoneItem.fromJson(
                row as Map<String, dynamic>,
                currentUserId: currentUserId,
                currentUserNickname: currentUserNickname ?? _currentUserNickname,
                partnerId: effectivePid,
                partnerNickname: effectivePNick,
                myLegacyUids: _discoveredMyLegacyUids,
                partnerLegacyUids: _discoveredPartnerLegacyUids,
              ))
          .toList();
      // Replace authoritatively with server list minus tombstones rather than resurrecting deleted entries
      _milestones = list..sort((a, b) => b.rawDate.compareTo(a.rawDate));
      notifyListeners();
    } catch (e) {
      await DeviceStatusService.recordSyncError('fetch_milestones', e.toString());
    }
  }

  void _mergeMilestones(List<MilestoneItem> incoming) {
    final tombstones = DeletedIdsStore.getIds('milestones');
    final filtered = incoming.where((m) {
      if (tombstones.contains(m.id)) return false;
      return _canViewRawAuthor(m.authorId) ||
          (OwnershipHelper.extractOwnerUid(m.authorId).isEmpty && m.isMine);
    }).toList();

    final Map<String, MilestoneItem> map = {
      for (final m in _milestones)
        if (!tombstones.contains(m.id)) m.id: m,
    };
    for (final item in filtered) {
      map[item.id] = item;
    }
    _milestones = map.values.where((m) {
      return _canViewRawAuthor(m.authorId) ||
          (OwnershipHelper.extractOwnerUid(m.authorId).isEmpty && m.isMine);
    }).toList()
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

  Future<bool> deleteMemory(String spaceId, String memoryId) async {
    final idx = _memories.indexWhere((m) => m.id == memoryId);
    final target = idx != -1 ? _memories[idx] : null;
    if (target != null && _currentUserId != null && _currentUserId!.isNotEmpty) {
      final ownerUid = OwnershipHelper.extractOwnerUid(target.author);
      if (ownerUid.isNotEmpty && !_canDeleteRawAuthor(target.author)) {
        return false;
      }
    }

    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('memories').delete().eq('id', memoryId);
      }
      if (target != null) {
        await MediaUploadService.deleteRemoteFiles([target.mediaUrl, target.voiceUrl]);
        if (target.voiceUrl != null && target.voiceUrl!.isNotEmpty) {
          await AudioCacheService.deleteCached(target.voiceUrl!);
        }
        if (target.mediaUrl.isNotEmpty) {
          await AudioCacheService.deleteCached(target.mediaUrl);
        }
      }
      await DeletedIdsStore.markDeleted('memories', memoryId);
      _memories.removeWhere((m) => m.id == memoryId);
      notifyListeners();
      return true;
    } catch (e) {
      await DeviceStatusService.recordSyncError('delete_memory', e.toString());
      return false;
    }
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

  Future<bool> deleteLetter(String spaceId, String letterId) async {
    final idx = _letters.indexWhere((l) => l.id == letterId);
    final target = idx != -1 ? _letters[idx] : null;
    if (target != null && _currentUserId != null && _currentUserId!.isNotEmpty) {
      final ownerUid = OwnershipHelper.extractOwnerUid(target.author);
      if (ownerUid.isNotEmpty && !_canDeleteRawAuthor(target.author)) {
        return false;
      }
    }

    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('letters').delete().eq('id', letterId);
      }
      await DeletedIdsStore.markDeleted('letters', letterId);
      _letters.removeWhere((l) => l.id == letterId);
      notifyListeners();
      return true;
    } catch (e) {
      await DeviceStatusService.recordSyncError('delete_letter', e.toString());
      return false;
    }
  }

  Future<void> addMilestone({
    required String spaceId,
    required String title,
    required String date,
    required String story,
    required String author,
    String? authorNickname,
    String? imageUrl,
    String? audioUrl,
    int? audioDuration,
  }) async {
    final newId = 'mls_${DateTime.now().millisecondsSinceEpoch}';
    final canonicalAuthor = AuthorIdentity.formatAuthorToken(
      userId: author,
      userNickname: authorNickname ?? _currentUserNickname,
    );

    final item = MilestoneItem(
      id: newId,
      title: title,
      date: date,
      rawDate: date,
      story: story,
      addedBy: 'You',
      authorId: canonicalAuthor,
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
        await supabase.from('milestones').insert(item.toJson(spaceId: spaceId, author: canonicalAuthor));
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
          .set(item.toJson(spaceId: spaceId, author: canonicalAuthor));
    } catch (e) {
      debugPrint('Firestore milestone insert error: $e');
    }
  }

  Future<bool> deleteMilestone(String spaceId, String milestoneId) async {
    final idx = _milestones.indexWhere((m) => m.id == milestoneId);
    final target = idx != -1 ? _milestones[idx] : null;
    if (target != null && _currentUserId != null && _currentUserId!.isNotEmpty) {
      final ownerUid = OwnershipHelper.extractOwnerUid(target.authorId);
      if (ownerUid.isNotEmpty && !_canDeleteRawAuthor(target.authorId)) {
        return false;
      }
    }

    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('milestones').delete().eq('id', milestoneId);
      }
      try {
        await FirebaseService.firestore
            .collection('spaces')
            .doc(spaceId)
            .collection('milestones')
            .doc(milestoneId)
            .delete();
      } catch (e) {
        await DeviceStatusService.recordSyncError('delete_milestone_fs', e.toString());
      }
      if (target != null) {
        await MediaUploadService.deleteRemoteFiles([target.imageUrl, target.audioUrl]);
        if (target.audioUrl != null && target.audioUrl!.isNotEmpty) {
          await AudioCacheService.deleteCached(target.audioUrl!);
        }
      }
      await DeletedIdsStore.markDeleted('milestones', milestoneId);
      _milestones.removeWhere((m) => m.id == milestoneId);
      notifyListeners();
      return true;
    } catch (e) {
      await DeviceStatusService.recordSyncError('delete_milestone', e.toString());
      return false;
    }
  }
}
