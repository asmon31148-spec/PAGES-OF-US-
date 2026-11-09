import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class WatchVideoItem {
  final String id;
  final String title;
  final String channel;
  final int durationMs;
  final String thumbnailUrl;

  const WatchVideoItem({
    required this.id,
    required this.title,
    required this.channel,
    required this.durationMs,
    required this.thumbnailUrl,
  });

  String get durationFormatted {
    if (durationMs <= 0) return 'Video';
    final duration = Duration(milliseconds: durationMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class WatchVideoService {
  WatchVideoService._();
  static final instance = WatchVideoService._();

  YoutubeExplode? _yt;
  YoutubeExplode get _client => _yt ??= YoutubeExplode();

  // In-memory stream URL cache to avoid redundant network extraction during room setup
  final Map<String, String> _streamCache = {};
  final Map<String, DateTime> _streamCacheTime = {};

  /// Parse YouTube Video ID from any query, URL, embed, or short link
  String? extractYouTubeId(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return null;

    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(clean)) {
      return clean;
    }

    try {
      final videoId = VideoId(clean);
      return videoId.value;
    } catch (_) {
      final regExp = RegExp(
        r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(clean);
      return match?.group(1);
    }
  }

  /// Search YouTube videos or fetch direct URL details
  Future<List<WatchVideoItem>> searchYouTube(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    final directId = extractYouTubeId(clean);
    if (directId != null && (clean.contains('youtu.be') || clean.contains('youtube.com') || RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(clean))) {
      try {
        final video = await _client.videos.get(directId);
        return [
          WatchVideoItem(
            id: video.id.value,
            title: video.title,
            channel: video.author,
            durationMs: video.duration?.inMilliseconds ?? 0,
            thumbnailUrl: video.thumbnails.highResUrl,
          ),
        ];
      } catch (e) {
        debugPrint('[WatchVideoService] Direct YouTube link fetch note: $e');
      }
    }

    try {
      final searchList = await _client.search.search(clean);
      final items = <WatchVideoItem>[];
      for (final video in searchList.take(25)) {
        items.add(
          WatchVideoItem(
            id: video.id.value,
            title: video.title,
            channel: video.author,
            durationMs: video.duration?.inMilliseconds ?? 0,
            thumbnailUrl: video.thumbnails.highResUrl,
          ),
        );
      }
      return items;
    } catch (e) {
      debugPrint('[WatchVideoService] YouTube search error: $e');
      return [];
    }
  }

  /// Resolve direct playable stream URL for a YouTube video on the local device
  Future<String?> getYouTubeVideoStreamUrl(String videoId) async {
    // Check local session cache (valid for 2 hours)
    final cached = _streamCache[videoId];
    final cachedTime = _streamCacheTime[videoId];
    if (cached != null && cachedTime != null && DateTime.now().difference(cachedTime).inMinutes < 120) {
      return cached;
    }

    try {
      final manifest = await _client.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.ios,
          YoutubeApiClient.androidVr,
          YoutubeApiClient.safari,
        ],
      ).timeout(const Duration(seconds: 12));

      // 1. First priority: Muxed MP4 (Video + Audio combined, best hardware decoding on Android)
      final mp4Muxed = manifest.muxed.where(
        (s) => s.container.name.toLowerCase() == 'mp4' || s.codec.mimeType.contains('mp4'),
      );
      if (mp4Muxed.isNotEmpty) {
        final bestStream = mp4Muxed.withHighestVideoQuality();
        final url = bestStream.url.toString();
        _streamCache[videoId] = url;
        _streamCacheTime[videoId] = DateTime.now();
        return url;
      }

      // 2. Secondary priority: Any muxed container (WebM/MP4)
      if (manifest.muxed.isNotEmpty) {
        final bestStream = manifest.muxed.withHighestVideoQuality();
        final url = bestStream.url.toString();
        _streamCache[videoId] = url;
        _streamCacheTime[videoId] = DateTime.now();
        return url;
      }
    } catch (e) {
      debugPrint('[WatchVideoService] getYouTubeVideoStreamUrl error for $videoId: $e');
      try {
        _yt?.close();
      } catch (_) {}
      _yt = null;
    }
    return null;
  }
}
