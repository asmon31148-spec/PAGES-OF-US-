import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Represents a song result from YouTube Music
class YoutubeTrack {
  final String id;
  final String title;
  final String artist;
  final int durationSeconds;
  final String thumbnailUrl;
  final String? audioStreamUrl;
  final bool isDownloaded;
  final String? localFilePath;

  const YoutubeTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationSeconds,
    required this.thumbnailUrl,
    this.audioStreamUrl,
    this.isDownloaded = false,
    this.localFilePath,
  });

  String get durationFormatted {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  YoutubeTrack copyWith({
    String? id,
    String? title,
    String? artist,
    int? durationSeconds,
    String? thumbnailUrl,
    String? audioStreamUrl,
    bool? isDownloaded,
    String? localFilePath,
  }) {
    return YoutubeTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      audioStreamUrl: audioStreamUrl ?? this.audioStreamUrl,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'durationSeconds': durationSeconds,
      'thumbnailUrl': thumbnailUrl,
      'audioStreamUrl': audioStreamUrl,
      'isDownloaded': isDownloaded,
      'localFilePath': localFilePath,
    };
  }

  factory YoutubeTrack.fromJson(Map<String, dynamic> json) {
    return YoutubeTrack(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown Title',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 180,
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      audioStreamUrl: json['audioStreamUrl'] as String?,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      localFilePath: json['localFilePath'] as String?,
    );
  }
}

/// Core YouTube Music Service: High-speed Search & Audio Stream Extractor
class YoutubeMusicService {
  static final YoutubeMusicService instance = YoutubeMusicService._();
  YoutubeMusicService._();

  YoutubeExplode? _yt;
  YoutubeExplode get _client => _yt ??= YoutubeExplode();

  // In-memory cache for audio stream URLs to prevent redundant network lookups
  final Map<String, String> _streamCache = {};
  final Map<String, DateTime> _streamCacheTime = {};

  /// Fast song search using InnerTube WEB_REMIX with automatic fallback to YoutubeExplode
  Future<List<YoutubeTrack>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      // 1. Primary: High-speed InnerTube WEB_REMIX API
      final results = await _searchInnerTube(cleanQuery);
      if (results.isNotEmpty) return results;
    } catch (e) {
      debugPrint('[YoutubeMusicService] InnerTube search fallback: $e');
    }

    try {
      // 2. Secondary fallback: YoutubeExplode search
      final searchList = await _client.search.search(cleanQuery);
      final tracks = <YoutubeTrack>[];

      for (final video in searchList.take(20)) {
        tracks.add(
          YoutubeTrack(
            id: video.id.value,
            title: video.title,
            artist: video.author,
            durationSeconds: video.duration?.inSeconds ?? 180,
            thumbnailUrl: video.thumbnails.highResUrl,
          ),
        );
      }
      return tracks;
    } catch (e) {
      debugPrint('[YoutubeMusicService] YoutubeExplode search error: $e');
      return [];
    }
  }

  /// InnerTube WEB_REMIX endpoint implementation (Echo Music style)
  Future<List<YoutubeTrack>> _searchInnerTube(String query) async {
    final postData = jsonEncode({
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20231204.01.00',
          'hl': 'en',
          'gl': 'US',
        }
      },
      'query': query,
    });

    final res = await http.post(
      Uri.parse('https://music.youtube.com/youtubei/v1/search'),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
      body: postData,
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) return [];

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final sectionList = json['contents']?['tabbedSearchResultsRenderer']?['tabs']
            ?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents']
        as List?;

    if (sectionList == null) return [];

    final tracks = <YoutubeTrack>[];

    for (final s in sectionList) {
      // Top result card shelf
      if (s is Map<String, dynamic> && s.containsKey('musicCardShelfRenderer')) {
        final card = s['musicCardShelfRenderer'] as Map<String, dynamic>;
        final title = (card['title']?['runs'] as List?)?.firstOrNull?['text']?.toString() ?? '';
        final subtitle = (card['subtitle']?['runs'] as List?)
            ?.map((r) => r['text']?.toString() ?? '')
            .join('') ?? '';
        final videoId = card['onTap']?['watchEndpoint']?['videoId']?.toString() ??
            card['title']?['runs']?[0]?['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString();
        final thumbs = card['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List?;
        final thumb = thumbs?.isNotEmpty == true ? thumbs!.last['url']?.toString() ?? '' : '';

        if (title.isNotEmpty && videoId != null && videoId.isNotEmpty) {
          final artist = subtitle.contains('•') ? subtitle.split('•')[1].trim() : subtitle;
          tracks.add(
            YoutubeTrack(
              id: videoId,
              title: title,
              artist: artist.isNotEmpty ? artist : 'YouTube Music',
              durationSeconds: 210,
              thumbnailUrl: thumb,
            ),
          );
        }
      }

      // Responsive list items
      if (s is Map<String, dynamic> && s.containsKey('itemSectionRenderer')) {
        final contents = s['itemSectionRenderer']?['contents'] as List?;
        if (contents != null) {
          for (final c in contents) {
            if (c is Map<String, dynamic> && c.containsKey('musicResponsiveListItemRenderer')) {
              final item = c['musicResponsiveListItemRenderer'] as Map<String, dynamic>;
              final flexCols = item['flexColumns'] as List?;
              if (flexCols == null || flexCols.isEmpty) continue;

              final titleRuns = flexCols[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List?;
              final title = titleRuns?.map((r) => r['text']?.toString() ?? '').join('') ?? '';

              final subRuns = flexCols.length > 1
                  ? flexCols[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List?
                  : null;
              final subtitle = subRuns?.map((r) => r['text']?.toString() ?? '').join('') ?? '';

              final thumbs = item['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List?;
              final thumb = thumbs?.isNotEmpty == true ? thumbs!.last['url']?.toString() ?? '' : '';

              final videoId = item['overlay']?['musicItemThumbnailOverlayRenderer']?['content']
                          ?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']
                          ?['videoId']
                      ?.toString() ??
                  item['playlistItemData']?['videoId']?.toString() ??
                  item['navigationEndpoint']?['watchEndpoint']?['videoId']?.toString();

              if (title.isNotEmpty && videoId != null && videoId.isNotEmpty) {
                final artist = subtitle.contains('•') ? subtitle.split('•')[1].trim() : subtitle;
                tracks.add(
                  YoutubeTrack(
                    id: videoId,
                    title: title,
                    artist: artist.isNotEmpty ? artist : 'YouTube Music',
                    durationSeconds: 200,
                    thumbnailUrl: thumb,
                  ),
                );
              }
            }
          }
        }
      }
    }

    return tracks;
  }

  /// Extracts direct audio-only stream URL (up to 256kbps AAC / Opus)
  Future<String?> getAudioStreamUrl(String videoId) async {
    // Check in-memory cache (valid for 4 hours before URL expires)
    if (_streamCache.containsKey(videoId)) {
      final cacheTime = _streamCacheTime[videoId];
      if (cacheTime != null && DateTime.now().difference(cacheTime).inHours < 4) {
        return _streamCache[videoId];
      }
    }

    try {
      final manifest = await _client.videos.streamsClient.getManifest(
        videoId,
        ytClients: [
          YoutubeApiClient.androidVr,
          YoutubeApiClient.safari,
          YoutubeApiClient.ios,
        ],
      );

      final audioStream = manifest.audioOnly.withHighestBitrate();
      final streamUrl = audioStream.url.toString();

      _streamCache[videoId] = streamUrl;
      _streamCacheTime[videoId] = DateTime.now();

      return streamUrl;
    } catch (e) {
      debugPrint('[YoutubeMusicService] Failed to extract audio stream for $videoId: $e');
      return null;
    }
  }

  /// Retrieves an audio stream for downloading
  Future<Stream<List<int>>?> getDownloadAudioStream(String videoId) async {
    try {
      final manifest = await _client.videos.streamsClient.getManifest(videoId);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      return _client.videos.streamsClient.get(audioStream);
    } catch (e) {
      debugPrint('[YoutubeMusicService] Failed to get download stream for $videoId: $e');
      return null;
    }
  }

  void dispose() {
    _yt?.close();
    _yt = null;
  }
}
