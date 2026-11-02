/// Service managing Firebase Realtime Database sync for Watch Together.
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/watch_room_model.dart';

class WatchTogetherService {
  static final WatchTogetherService instance = WatchTogetherService._internal();
  WatchTogetherService._internal() {
    _initServerTimeOffset();
  }

  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  int _serverTimeOffset = 0;
  StreamSubscription? _offsetSubscription;

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

  /// Stream playback node specifically for ultra-low latency updates
  Stream<WatchPlayback> streamPlayback(String roomCode) {
    return _rtdb.ref('watchRooms/$roomCode/playback').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return const WatchPlayback();
      }
      return WatchPlayback.fromMap(event.snapshot.value as Map<dynamic, dynamic>);
    });
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

  /// Screen 3: Single source of truth playback state write
  Future<void> updatePlayback({
    required String roomCode,
    required String uid,
    required bool isPlaying,
    required int positionMs,
    double speed = 1.0,
    bool buffering = false,
  }) async {
    await _rtdb.ref('watchRooms/$roomCode/playback').update({
      'isPlaying': isPlaying,
      'positionMs': positionMs,
      'updatedAt': ServerValue.timestamp,
      'updatedBy': uid,
      'speed': speed,
      'buffering': buffering,
    });
  }

  /// Screen 3: Send chat message
  Future<void> sendChatMessage({
    required String roomCode,
    required String uid,
    required String name,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    final chatRef = _rtdb.ref('watchRooms/$roomCode/chat').push();
    await chatRef.set({
      'uid': uid,
      'name': name,
      'text': text.trim(),
      'type': 'text',
      'sentAt': ServerValue.timestamp,
    });
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

  /// Cleanup: Leave room and remove if empty or host leaves
  Future<void> leaveRoom({
    required String roomCode,
    required String uid,
    required bool isHost,
  }) async {
    try {
      final roomRef = _rtdb.ref('watchRooms/$roomCode');
      await roomRef.child('members/$uid/online').set(false);

      if (isHost) {
        // Host leaving dismantles the room after a brief grace delay
        await roomRef.remove();
      } else {
        // Guest leaving frees the slot
        await roomRef.child('guestUid').set('');
        await roomRef.child('members/$uid').remove();
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
