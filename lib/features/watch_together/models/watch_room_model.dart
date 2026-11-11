/// Models for the Watch Together real-time local sync feature.
import 'package:flutter/foundation.dart';

class WatchMember {
  final String uid;
  final String name;
  final String fileName;
  final int durationMs;
  final bool ready;
  final bool online;

  WatchMember({
    required this.uid,
    required this.name,
    this.fileName = '',
    this.durationMs = 0,
    this.ready = false,
    this.online = true,
  });

  factory WatchMember.fromMap(String uid, Map<dynamic, dynamic>? map) {
    if (map == null) {
      return WatchMember(uid: uid, name: 'Partner');
    }
    return WatchMember(
      uid: uid,
      name: map['name']?.toString() ?? 'Partner',
      fileName: map['fileName']?.toString() ?? '',
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      ready: map['ready'] == true,
      online: map['online'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'fileName': fileName,
        'durationMs': durationMs,
        'ready': ready,
        'online': online,
      };

  WatchMember copyWith({
    String? name,
    String? fileName,
    int? durationMs,
    bool? ready,
    bool? online,
  }) {
    return WatchMember(
      uid: uid,
      name: name ?? this.name,
      fileName: fileName ?? this.fileName,
      durationMs: durationMs ?? this.durationMs,
      ready: ready ?? this.ready,
      online: online ?? this.online,
    );
  }
}

class WatchPlayback {
  final bool isPlaying;
  final int positionMs;
  final int updatedAt; // Milliseconds timestamp
  final String updatedBy;
  final double speed;
  final bool buffering;
  final int actionSeq;

  const WatchPlayback({
    this.isPlaying = false,
    this.positionMs = 0,
    this.updatedAt = 0,
    this.updatedBy = '',
    this.speed = 1.0,
    this.buffering = false,
    this.actionSeq = 0,
  });

  factory WatchPlayback.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const WatchPlayback();
    return WatchPlayback(
      isPlaying: map['isPlaying'] == true,
      positionMs: (map['positionMs'] as num?)?.toInt() ?? 0,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? 0,
      updatedBy: map['updatedBy']?.toString() ?? '',
      speed: (map['speed'] as num?)?.toDouble() ?? 1.0,
      buffering: map['buffering'] == true,
      actionSeq: (map['actionSeq'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'isPlaying': isPlaying,
        'positionMs': positionMs,
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
        'speed': speed,
        'buffering': buffering,
        'actionSeq': actionSeq,
      };
}

class WatchMessage {
  final String id;
  final String uid;
  final String name;
  final String avatarUrl;
  final String text;
  final String type; // 'text' or 'reaction'
  final int sentAt;

  WatchMessage({
    required this.id,
    required this.uid,
    required this.name,
    this.avatarUrl = '',
    required this.text,
    this.type = 'text',
    required this.sentAt,
  });

  factory WatchMessage.fromMap(String id, Map<dynamic, dynamic>? map) {
    if (map == null) {
      return WatchMessage(id: id, uid: '', name: '', text: '', sentAt: 0);
    }
    return WatchMessage(
      id: id,
      uid: map['uid']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Partner',
      avatarUrl: map['avatarUrl']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      sentAt: (map['sentAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'avatarUrl': avatarUrl,
        'text': text,
        'type': type,
        'sentAt': sentAt,
      };
}

class WatchVideoSource {
  final String type; // 'local', 'youtube', 'web_url'
  final String title;
  final String? youtubeId;
  final String? webUrl;
  final String? thumbnailUrl;
  final int durationMs;
  final String selectedBy;

  const WatchVideoSource({
    required this.type,
    required this.title,
    this.youtubeId,
    this.webUrl,
    this.thumbnailUrl,
    this.durationMs = 0,
    this.selectedBy = '',
  });

  factory WatchVideoSource.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const WatchVideoSource(type: 'local', title: '');
    }
    return WatchVideoSource(
      type: map['type']?.toString() ?? 'local',
      title: map['title']?.toString() ?? '',
      youtubeId: map['youtubeId']?.toString(),
      webUrl: map['webUrl']?.toString(),
      thumbnailUrl: map['thumbnailUrl']?.toString(),
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      selectedBy: map['selectedBy']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'title': title,
        if (youtubeId != null) 'youtubeId': youtubeId,
        if (webUrl != null) 'webUrl': webUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        'durationMs': durationMs,
        'selectedBy': selectedBy,
      };

  bool get isOnline => type == 'youtube' || type == 'web_url';
  bool get isYouTube => type == 'youtube';
  bool get isWebUrl => type == 'web_url';
  bool get isLocal => type == 'local';
}

class WatchRoom {
  final String roomCode;
  final String hostUid;
  final String? guestUid;
  final int createdAt;
  final Map<String, WatchMember> members;
  final WatchPlayback playback;
  final List<WatchMessage> chat;
  final WatchVideoSource? videoSource;

  WatchRoom({
    required this.roomCode,
    required this.hostUid,
    this.guestUid,
    required this.createdAt,
    this.members = const {},
    this.playback = const WatchPlayback(),
    this.chat = const [],
    this.videoSource,
  });

  factory WatchRoom.fromMap(String roomCode, Map<dynamic, dynamic> map) {
    final membersMap = <String, WatchMember>{};
    if (map['members'] is Map) {
      (map['members'] as Map).forEach((key, val) {
        membersMap[key.toString()] = WatchMember.fromMap(
          key.toString(),
          val is Map ? val : null,
        );
      });
    }

    final chatList = <WatchMessage>[];
    if (map['chat'] is Map) {
      (map['chat'] as Map).forEach((key, val) {
        if (val is Map) {
          chatList.add(WatchMessage.fromMap(key.toString(), val));
        }
      });
      chatList.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    }

    final videoSourceData = map['videoSource'] is Map ? map['videoSource'] as Map : null;

    return WatchRoom(
      roomCode: roomCode,
      hostUid: map['hostUid']?.toString() ?? '',
      guestUid: map['guestUid']?.toString(),
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      members: membersMap,
      playback: WatchPlayback.fromMap(map['playback'] is Map ? map['playback'] : null),
      chat: chatList,
      videoSource: videoSourceData != null ? WatchVideoSource.fromMap(videoSourceData) : null,
    );
  }
}
