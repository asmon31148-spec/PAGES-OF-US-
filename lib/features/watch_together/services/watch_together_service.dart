/// Service managing Firebase Realtime Database sync for Watch Together.
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/supabase_service.dart';
import '../models/watch_room_model.dart';

class WatchTogetherService {
  static final WatchTogetherService instance = WatchTogetherService._internal();
  WatchTogetherService._internal() {
    _initServerTimeOffset();
  }

  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  int _serverTimeOffset = 0;
  StreamSubscription? _offsetSubscription;
  int _localActionSeq = 0;
  RealtimeChannel? _supaRoomChannel;
  String? _supaRoomCode;
  StreamController<WatchPlayback>? _dualPlaybackController;
  StreamSubscription? _rtdbPlaybackSub;

  // Allowed character set for 6-character room codes (no 0, O, 1, I)
  static const String _charset = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  Future<void> _ensureAuth() async {
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        debugPrint('WatchTogether auth check error: $e');
      }
    }
  }

  void _initServerTimeOffset() {
    try {
      _offsetSubscription = _rtdb.ref('.info/serverTimeOffset').onValue.listen((event) {
        final offset = event.snapshot.value;
        if (offset is num) {
          _serverTimeOffset = offset.toInt();
        }
      });
    } catch (e) {
      debugPrint('WatchTogether serverTimeOffset error: $e');
    }
  }

  /// Calculates current server timestamp compensated for local clock drift
  int get currentServerTime =>
      DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;

  /// Generates a random 6-character code
  String _generateRandomCode() {
    final random = Random();
    return List.generate(6, (_) => _charset[random.nextInt(_charset.length)]).join();
  }

  /// Creates a unique room code not currently active in RTDB
  Future<String> createUniqueRoomCode() async {
    await _ensureAuth();
    for (int i = 0; i < 5; i++) {
      final code = _generateRandomCode();
      try {
        final snapshot = await _rtdb.ref('watchRooms/$code').get();
        if (!snapshot.exists) {
          return code;
        }
      } catch (_) {
        return code;
      }
    }
    // Fallback with random code if collision or read error occurs
    return _generateRandomCode();
  }

  /// Screen 1: Creates a new room with host metadata
  Future<String> createRoom({
    required String hostUid,
    required String hostName,
  }) async {
    await _ensureAuth();

    // 1. Opportunistic cleanup of stale rooms older than 24 hours
    cleanupStaleRooms();

    // 2. Generate unique 6-character code
    final roomCode = await createUniqueRoomCode();
    final roomRef = _rtdb.ref('watchRooms/$roomCode');

    // 3. Write initial room state
    await roomRef.set({
      'hostUid': hostUid,
      'guestUid': '',
      'createdAt': ServerValue.timestamp,
      'members': {
        hostUid: {
          'name': hostName,
          'fileName': '',
          'durationMs': 0,
          'ready': false,
          'online': true,
        },
      },
      'playback': {
        'isPlaying': false,
        'positionMs': 0,
        'updatedAt': ServerValue.timestamp,
        'updatedBy': hostUid,
        'speed': 1.0,
        'buffering': false,
      },
    });

    // 4. Configure automatic offline status on disconnect
    try {
      await roomRef.child('members/$hostUid/online').onDisconnect().set(false);
    } catch (_) {}

    return roomCode;
  }

  /// Screen 1: Joins an existing room
  Future<void> joinRoom({
    required String roomCode,
    required String guestUid,
    required String guestName,
  }) async {
    await _ensureAuth();
    final cleanCode = roomCode.trim().toUpperCase();
    final roomRef = _rtdb.ref('watchRooms/$cleanCode');
    final snapshot = await roomRef.get();

    if (!snapshot.exists) {
      throw Exception('Room not found. Check code and try again.');
    }

    final data = snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) {
      throw Exception('Room not found.');
    }

    final existingGuest = data['guestUid']?.toString() ?? '';
    final hostUid = data['hostUid']?.toString() ?? '';

    // If already joined as host, just reconnect
    if (hostUid == guestUid) {
      await roomRef.child('members/$guestUid/online').set(true);
      return;
    }

    // If another guest already occupies the room
    if (existingGuest.isNotEmpty && existingGuest != guestUid) {
      throw Exception('Room is full. Two people are already connected.');
    }

    // Set guestUid and register member
    await roomRef.update({'guestUid': guestUid});
    await roomRef.child('members/$guestUid').set({
      'name': guestName,
      'fileName': '',
      'durationMs': 0,
      'ready': false,
      'online': true,
    });

    // Configure automatic offline status on disconnect
    try {
      await roomRef.child('members/$guestUid/online').onDisconnect().set(false);
    } catch (_) {}
  }

  /// Stream continuous room updates
  Stream<WatchRoom?> streamRoom(String roomCode) {
    return _rtdb.ref('watchRooms/$roomCode').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return null;
      }
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      return WatchRoom.fromMap(roomCode, data);
    });
  }

  /// Dual-channel low-latency playback stream: merges Firebase RTDB + Supabase Realtime broadcast
  Stream<WatchPlayback> streamPlayback(String roomCode) {
    _rtdbPlaybackSub?.cancel();
    _dualPlaybackController?.close();
    _cleanupSupaRoomChannel();

    final controller = StreamController<WatchPlayback>.broadcast();
    _dualPlaybackController = controller;

    // Channel 1: Firebase RTDB persistent listener
    _rtdbPlaybackSub = _rtdb.ref('watchRooms/$roomCode/playback').onValue.listen((event) {
      if (controller.isClosed) return;
      if (!event.snapshot.exists || event.snapshot.value == null) {
        controller.add(const WatchPlayback());
        return;
      }
      controller.add(WatchPlayback.fromMap(event.snapshot.value as Map<dynamic, dynamic>));
    }, onError: (_) {});

    // Channel 2: Supabase Realtime ultra-low-latency broadcast (resilient on mobile carriers)
    final client = SupabaseService.client;
    if (client != null && roomCode.isNotEmpty) {
      try {
        _supaRoomCode = roomCode;
        final ch = client.channel(
          'watch_sync_$roomCode',
          opts: const RealtimeChannelConfig(ack: false, self: false),
        );
        ch.onBroadcast(
          event: 'PLAYBACK_SYNC',
          callback: (payload) {
            if (controller.isClosed) return;
            controller.add(WatchPlayback.fromMap(payload));
          },
        );
        ch.subscribe();
        _supaRoomChannel = ch;
      } catch (e) {
        debugPrint('Supabase WatchTogether sync channel note: $e');
      }
    }

    return controller.stream;
  }

  void _cleanupSupaRoomChannel() {
    final ch = _supaRoomChannel;
    _supaRoomChannel = null;
    _supaRoomCode = null;
    if (ch != null) {
      try {
        SupabaseService.client?.removeChannel(ch);
      } catch (_) {}
    }
  }

  /// Stream last 50 chat messages
  Stream<List<WatchMessage>> streamChat(String roomCode) {
    return _rtdb
        .ref('watchRooms/$roomCode/chat')
        .limitToLast(50)
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <WatchMessage>[];
      }
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final list = <WatchMessage>[];
      data.forEach((key, val) {
        if (val is Map) {
          list.add(WatchMessage.fromMap(key.toString(), val));
        }
      });
      list.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return list;
    });
  }

  /// Screen 2: Update room's shared video source (YouTube or Web URL or Local)
  Future<void> updateRoomVideoSource({
    required String roomCode,
    required WatchVideoSource videoSource,
  }) async {
    await _rtdb.ref('watchRooms/$roomCode/videoSource').set(videoSource.toMap());
  }

  /// Screen 2: Update member's local movie file details
  Future<void> updateMemberFile({
    required String roomCode,
    required String uid,
    required String fileName,
    required int durationMs,
  }) async {
    await _rtdb.ref('watchRooms/$roomCode/members/$uid').update({
      'fileName': fileName,
      'durationMs': durationMs,
    });
  }

  /// Screen 2: Update ready status
  Future<void> updateMemberReady({
    required String roomCode,
    required String uid,
    required bool ready,
  }) async {
    await _rtdb.ref('watchRooms/$roomCode/members/$uid/ready').set(ready);
  }

  /// Screen 2: Reset ready status for "Watch Another"
  Future<void> resetRoomForAnother({
    required String roomCode,
    required String uid,
  }) async {
    await _rtdb.ref('watchRooms/$roomCode/members/$uid').update({
      'fileName': '',
      'durationMs': 0,
      'ready': false,
    });
    await _rtdb.ref('watchRooms/$roomCode/playback').update({
      'isPlaying': false,
      'positionMs': 0,
      'updatedAt': ServerValue.timestamp,
      'updatedBy': uid,
    });
    try {
      await _rtdb.ref('watchRooms/$roomCode/videoSource').remove();
    } catch (_) {}
  }

  /// Update online state
  Future<void> updateMemberOnline({
    required String roomCode,
    required String uid,
    required bool online,
  }) async {
    try {
      await _rtdb.ref('watchRooms/$roomCode/members/$uid/online').set(online);
    } catch (_) {}
  }

  /// Screen 3: Dual-transport playback state write (Supabase Realtime instant + RTDB durable)
  Future<void> updatePlayback({
    required String roomCode,
    required String uid,
    required bool isPlaying,
    required int positionMs,
    double speed = 1.0,
    bool buffering = false,
  }) async {
    _localActionSeq++;
    final clientMs = currentServerTime;
    final supaPayload = <String, dynamic>{
      'isPlaying': isPlaying,
      'positionMs': positionMs,
      'updatedAt': clientMs,
      'updatedBy': uid,
      'speed': speed,
      'buffering': buffering,
      'actionSeq': _localActionSeq,
    };

    // Fire Supabase Realtime broadcast immediately (<50ms)
    final ch = _supaRoomChannel;
    if (ch != null && _supaRoomCode == roomCode) {
      try {
        unawaited(ch.sendBroadcastMessage(
          event: 'PLAYBACK_SYNC',
          payload: supaPayload,
        ));
      } catch (_) {}
    }

    // Write authoritative state to Firebase RTDB
    await _rtdb.ref('watchRooms/$roomCode/playback').update({
      'isPlaying': isPlaying,
      'positionMs': positionMs,
      'updatedAt': ServerValue.timestamp,
      'updatedBy': uid,
      'speed': speed,
      'buffering': buffering,
      'actionSeq': _localActionSeq,
    });
  }

  /// Screen 3: Stream total message count
  Stream<int> streamMessageCount(String roomCode) {
    return _rtdb.ref('watchRooms/$roomCode/messageCount').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return 0;
      return (event.snapshot.value as num?)?.toInt() ?? 0;
    });
  }

  /// Screen 3: Send chat message
  Future<void> sendChatMessage({
    required String roomCode,
    required String uid,
    required String name,
    required String text,
    String avatarUrl = '',
  }) async {
    if (text.trim().isEmpty) return;
    final chatRef = _rtdb.ref('watchRooms/$roomCode/chat').push();
    await chatRef.set({
      'uid': uid,
      'name': name,
      'avatarUrl': avatarUrl,
      'text': text.trim(),
      'type': 'text',
      'sentAt': ServerValue.timestamp,
    });
    // Increment message count for counter badge
    try {
      await _rtdb.ref('watchRooms/$roomCode/messageCount').set(ServerValue.increment(1));
    } catch (_) {}
  }

  /// Screen 3: Send emoji reaction
  Future<void> sendReaction({
    required String roomCode,
    required String uid,
    required String name,
    required String emoji,
  }) async {
    final chatRef = _rtdb.ref('watchRooms/$roomCode/chat').push();
    await chatRef.set({
      'uid': uid,
      'name': name,
      'text': emoji,
      'type': 'reaction',
      'sentAt': ServerValue.timestamp,
    });
  }

  /// Screen 2: Delete room explicitly (e.g. host leaves waiting room)
  Future<void> deleteRoom(String roomCode) async {
    try {
      final cleanCode = roomCode.trim().toUpperCase();
      await _rtdb.ref('watchRooms/$cleanCode').remove();
    } catch (e) {
      debugPrint('[WatchTogetherService] deleteRoom error: $e');
    }
  }

  /// Cleanup: Leave room and dismantle when both have exited
  Future<void> leaveRoom({
    required String roomCode,
    required String uid,
    required bool isHost,
  }) async {
    _rtdbPlaybackSub?.cancel();
    _rtdbPlaybackSub = null;
    _cleanupSupaRoomChannel();
    try {
      final cleanCode = roomCode.trim().toUpperCase();
      final roomRef = _rtdb.ref('watchRooms/$cleanCode');
      
      // 1. Mark this user as offline
      await roomRef.child('members/$uid/online').set(false);

      // 2. Fetch current members to check if ANY other member is still online
      final snapshot = await roomRef.get();
      if (!snapshot.exists || snapshot.value == null) return;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final members = data['members'] as Map<dynamic, dynamic>? ?? {};

      bool anyOtherMemberOnline = false;
      members.forEach((mUid, mData) {
        if (mUid != uid && mData is Map && mData['online'] == true) {
          anyOtherMemberOnline = true;
        }
      });

      // If no other member is online (both have exited), permanently wipe the room and all messages!
      if (!anyOtherMemberOnline) {
        await roomRef.remove();
      }
    } catch (e) {
      debugPrint('leaveRoom error: $e');
    }
  }

  /// Cleanup rooms older than 24 hours
  Future<void> cleanupStaleRooms() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
      final snapshot = await _rtdb.ref('watchRooms').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, val) {
        if (val is Map) {
          final createdAt = (val['createdAt'] as num?)?.toInt() ?? 0;
          if (createdAt > 0 && createdAt < cutoff) {
            _rtdb.ref('watchRooms/$key').remove();
          }
        }
      });
    } catch (e) {
      debugPrint('cleanupStaleRooms error: $e');
    }
  }

  void dispose() {
    _offsetSubscription?.cancel();
  }
}
