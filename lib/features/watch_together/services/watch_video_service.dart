import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class WatchStreamSource {
  final String url;
  final Map<String, String> headers;
  final String label;

  const WatchStreamSource({
    required this.url,
    this.headers = const {},
    this.label = 'direct',
  });
}

class _ClientProfile {
  final String name;
  final YoutubeApiClient client;
  final Map<String, String> headers;

  const _ClientProfile({
    required this.name,
    required this.client,
    required this.headers,
  });
}

class _ProxyTarget {
  final String url;
  final Map<String, String> headers;
  final String contentType;

  const _ProxyTarget({
    required this.url,
    required this.headers,
    this.contentType = 'video/mp4',
  });
}

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

  // In-memory stream cache to avoid redundant network extraction during room setup
  final Map<String, List<WatchStreamSource>> _sourcesCache = {};
  final Map<String, DateTime> _streamCacheTime = {};

  // Local HTTP Range proxy (eliminates ExoPlayer redirect/User-Agent 403 Source errors)
  HttpServer? _proxyServer;
  int? _proxyPort;
  final Map<String, _ProxyTarget> _proxyTargets = {};

  static const List<_ClientProfile> _clientProfiles = [
    _ClientProfile(
      name: 'androidVr',
      client: YoutubeApiClient.androidVr,
      headers: {
        'User-Agent':
            'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1)',
      },
    ),
    _ClientProfile(
      name: 'tv',
      client: YoutubeApiClient.tv,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (SMART-TV; Linux; Tizen 6.0) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/4.0 Chrome/76.0.3809.109 TV Safari/537.36',
        'Origin': 'https://www.youtube.com',
        'Referer': 'https://www.youtube.com/',
      },
    ),
    _ClientProfile(
      name: 'safari',
      client: YoutubeApiClient.safari,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15',
        'Origin': 'https://www.youtube.com',
        'Referer': 'https://www.youtube.com/',
      },
    ),
    _ClientProfile(
      name: 'ios',
      client: YoutubeApiClient.ios,
      headers: {
        'User-Agent': 'com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X)',
      },
    ),
  ];

  bool _isUrlFresh(String url) {
    try {
      final expStr = Uri.parse(url).queryParameters['expire'];
      if (expStr != null) {
        final expEpochSec = int.tryParse(expStr);
        if (expEpochSec != null) {
          final expiry = DateTime.fromMillisecondsSinceEpoch(expEpochSec * 1000);
          return DateTime.now().isBefore(expiry.subtract(const Duration(minutes: 10)));
        }
      }
    } catch (_) {}
    return true;
  }

  /// Ensures local loopback HTTP Range proxy is listening for ExoPlayer fallback.
  Future<int?> _ensureProxyRunning() async {
    if (_proxyServer != null && _proxyPort != null) return _proxyPort;
    try {
      _proxyServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _proxyPort = _proxyServer!.port;
      _proxyServer!.listen(_handleProxyRequest);
      return _proxyPort;
    } catch (e) {
      debugPrint('[WatchVideoService] Proxy start note: $e');
      return null;
    }
  }

  Future<void> _handleProxyRequest(HttpRequest req) async {
    final key = req.uri.queryParameters['key'];
    final target = key != null ? _proxyTargets[key] : null;
    if (target == null) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
      return;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final upstreamReq = req.method == 'HEAD'
          ? await client.headUrl(Uri.parse(target.url))
          : await client.getUrl(Uri.parse(target.url));

      upstreamReq.followRedirects = true;
      upstreamReq.maxRedirects = 5;
      target.headers.forEach((k, v) => upstreamReq.headers.set(k, v));

      final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
      if (rangeHeader != null && rangeHeader.isNotEmpty) {
        upstreamReq.headers.set(HttpHeaders.rangeHeader, rangeHeader);
      }

      final upstreamRes = await upstreamReq.close().timeout(const Duration(seconds: 10));
      req.response.statusCode = upstreamRes.statusCode;
      req.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      req.response.headers.set(
        HttpHeaders.contentTypeHeader,
        upstreamRes.headers.value(HttpHeaders.contentTypeHeader) ?? target.contentType,
      );
      final contentLen = upstreamRes.headers.value(HttpHeaders.contentLengthHeader);
      if (contentLen != null) {
        req.response.headers.set(HttpHeaders.contentLengthHeader, contentLen);
      }
      final contentRange = upstreamRes.headers.value(HttpHeaders.contentRangeHeader);
      if (contentRange != null) {
        req.response.headers.set(HttpHeaders.contentRangeHeader, contentRange);
      }

      if (req.method != 'HEAD') {
        await req.response.addStream(upstreamRes);
      }
      await req.response.close();
    } catch (e) {
      try {
        req.response.statusCode = HttpStatus.badGateway;
        await req.response.close();
      } catch (_) {}
    } finally {
      try {
        client.close(force: false);
      } catch (_) {}
    }
  }

  String _registerProxyTarget(String key, _ProxyTarget target, int port) {
    _proxyTargets[key] = target;
    return 'http://127.0.0.1:$port/stream?key=$key';
  }

  /// Verifies stream URL actually yields bytes (HTTP 200 or 206) and finds working headers.
  Future<Map<String, String>?> _probePlayableHeaders(
    String url,
    Map<String, String> preferredHeaders,
  ) async {
    final headerOptions = <Map<String, String>>[
      if (preferredHeaders.isNotEmpty) preferredHeaders,
      const <String, String>{},
      const <String, String>{
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      },
    ];

    for (final headers in headerOptions) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      try {
        final req = await client.getUrl(Uri.parse(url));
        req.followRedirects = true;
        req.maxRedirects = 5;
        headers.forEach((k, v) => req.headers.set(k, v));
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1023');

        final res = await req.close().timeout(const Duration(seconds: 5));
        final code = res.statusCode;
        await res.drain<void>();
        if (code == 200 || code == 206) {
          return headers;
        }
      } catch (_) {
        // Try next header profile
      } finally {
        client.close(force: true);
      }
    }
    return null;
  }

  /// Resolve ranked, HTTP-verified stream sources (Direct + Local Range Proxy across clients).
  Future<List<WatchStreamSource>> getPlayableYouTubeSources(
    String videoId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _sourcesCache[videoId];
      final cachedTime = _streamCacheTime[videoId];
      if (cached != null &&
          cached.isNotEmpty &&
          cachedTime != null &&
          DateTime.now().difference(cachedTime).inMinutes < 90 &&
          _isUrlFresh(cached.first.url)) {
        return cached;
      }
    } else {
      _sourcesCache.remove(videoId);
      _streamCacheTime.remove(videoId);
    }

    final sources = <WatchStreamSource>[];
    final seenUrls = <String>{};
    final proxyPort = await _ensureProxyRunning();
    int verifiedClients = 0;

    for (final profile in _clientProfiles) {
      try {
        final manifest = await _client.videos.streamsClient.getManifest(
          videoId,
          ytClients: [profile.client],
        ).timeout(const Duration(seconds: 8));

        final mp4Muxed = manifest.muxed
            .where((s) => s.container.name.toLowerCase() == 'mp4' || s.codec.mimeType.contains('mp4'))
            .toList()
          ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

        final otherMuxed = manifest.muxed
            .where((s) => !mp4Muxed.contains(s))
            .toList()
          ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

        // Prefer highest bitrate + lowest (e.g. 360p) compatibility fallback from this client
        final pool = mp4Muxed.isNotEmpty ? mp4Muxed : otherMuxed;
        final candidates = <MuxedStreamInfo>[
          if (pool.isNotEmpty) pool.first,
          if (pool.length > 1) pool.last,
        ];

        bool clientAdded = false;
        for (int i = 0; i < candidates.length; i++) {
          final stream = candidates[i];
          final url = stream.url.toString();
          if (seenUrls.contains(url)) continue;
          seenUrls.add(url);

          final workingHeaders = await _probePlayableHeaders(url, profile.headers);
          if (workingHeaders == null) continue;

          clientAdded = true;
          // 1. Verified direct playback with exact headers
          sources.add(
            WatchStreamSource(
              url: url,
              headers: workingHeaders,
              label: '${profile.name}_direct_$i',
            ),
          );

          // 2. Local Range Proxy (handles 302 redirects & TLS headers safely if ExoPlayer rejects direct)
          if (proxyPort != null) {
            final key = '${videoId}_${profile.name}_$i';
            final proxyUrl = _registerProxyTarget(
              key,
              _ProxyTarget(
                url: url,
                headers: workingHeaders,
                contentType: stream.codec.mimeType.isNotEmpty ? stream.codec.mimeType : 'video/mp4',
              ),
              proxyPort,
            );
            sources.add(
              WatchStreamSource(
                url: proxyUrl,
                headers: const {},
                label: '${profile.name}_proxy_$i',
              ),
            );
          }
        }

        if (clientAdded) {
          verifiedClients++;
          if (verifiedClients >= 2) break;
        }
      } catch (e) {
        debugPrint('[WatchVideoService] Client ${profile.name} manifest note for $videoId: $e');
        if (profile.name == _clientProfiles.last.name && sources.isEmpty) {
          try {
            _yt?.close();
          } catch (_) {}
          _yt = null;
        }
      }
    }

    if (sources.isNotEmpty) {
      _sourcesCache[videoId] = sources;
      _streamCacheTime[videoId] = DateTime.now();
    }
    return sources;
  }

  /// Backward-compatible helper returning primary playable URL.
  Future<String?> getYouTubeVideoStreamUrl(String videoId) async {
    final sources = await getPlayableYouTubeSources(videoId);
    return sources.isNotEmpty ? sources.first.url : null;
  }
}

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
}
