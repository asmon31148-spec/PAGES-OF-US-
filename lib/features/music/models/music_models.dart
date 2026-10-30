import 'package:flutter/material.dart';

class SongItem {
  final String id;
  final String title;
  final String artist;
  final int durationSeconds;
  final String audioUrl;
  final Color coverColor;
  final bool isLocal;
  final String addedBy;
  final String? thumbnailUrl;
  final String? youtubeId;

  SongItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationSeconds,
    required this.audioUrl,
    required this.coverColor,
    this.isLocal = false,
    this.addedBy = 'Sanctuary',
    this.thumbnailUrl,
    this.youtubeId,
  });

  String get durationFormatted {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'durationSeconds': durationSeconds,
      'audioUrl': audioUrl,
      'coverColor': coverColor.value,
      'isLocal': isLocal,
      'addedBy': addedBy,
      'thumbnailUrl': thumbnailUrl,
      'youtubeId': youtubeId,
    };
  }

  factory SongItem.fromJson(Map<String, dynamic> json) {
    return SongItem(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      durationSeconds: json['durationSeconds'] as int? ?? 180,
      audioUrl: json['audioUrl'] as String,
      coverColor: Color(json['coverColor'] as int? ?? 0xFF86EFAC),
      isLocal: json['isLocal'] as bool? ?? false,
      addedBy: json['addedBy'] as String? ?? 'Sanctuary',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      youtubeId: json['youtubeId'] as String?,
    );
  }
}

class PlaylistItem {
  final String id;
  final String title;
  final Color coverColor;
  final List<String> songIds;

  PlaylistItem({
    required this.id,
    required this.title,
    required this.coverColor,
    required this.songIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverColor': coverColor.value,
      'songIds': songIds,
    };
  }

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    return PlaylistItem(
      id: json['id'] as String,
      title: json['title'] as String,
      coverColor: Color(json['coverColor'] as int? ?? 0xFF2DD4BF),
      songIds: (json['songIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class AtmosphereStem {
  final String id;
  final String title;
  final IconData icon;
  final String audioUrl;
  final Color iconColor;
  double volume; // 0.0 to 1.0

  AtmosphereStem({
    required this.id,
    required this.title,
    required this.icon,
    required this.audioUrl,
    required this.iconColor,
    this.volume = 0.5,
  });
}
