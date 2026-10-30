import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AudioCacheService {
  static final Map<String, String> _memoryCache = {};
  static bool _isCleaning = false;
  static final Set<String> _prefetchingUrls = {};

  // 50 MB total cache ceiling, purges down to 35 MB on breach
  static const int maxCacheBytes = 50 * 1024 * 1024;
  static const int targetCacheBytes = 35 * 1024 * 1024;

  /// Returns whether the given audio URL is already stored on local device disk.
  static Future<bool> isCached(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return false;
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      return true;
    }

    if (_memoryCache.containsKey(cleanUrl)) {
      final cachedPath = _memoryCache[cleanUrl]!;
      if (File(cachedPath).existsSync()) return true;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/audio_cache');
      if (!cacheDir.existsSync()) return false;

      final filename = _generateFilename(cleanUrl);
      final file = File('${cacheDir.path}/$filename');
      return file.existsSync() && file.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }

  /// Returns a local cached file path for the given audio URL.
  /// If not yet cached, downloads it to the app's cache directory and returns the local path.
  /// Gracefully falls back to the original remote URL on network/disk error.
  static Future<String> getCachedAudioPath(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return cleanUrl;

    // Already a local device file or asset
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      return cleanUrl.replaceFirst('file://', '');
    }

    // Check fast in-memory cache
    if (_memoryCache.containsKey(cleanUrl)) {
      final cachedPath = _memoryCache[cleanUrl]!;
      final file = File(cachedPath);
      if (file.existsSync() && file.lengthSync() > 0) {
        return cachedPath;
      }
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/audio_cache');
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }

      final filename = _generateFilename(cleanUrl);
      final file = File('${cacheDir.path}/$filename');

      if (file.existsSync() && file.lengthSync() > 0) {
        _memoryCache[cleanUrl] = file.path;
        return file.path;
      }

      // Download and save locally
      final response = await http.get(Uri.parse(cleanUrl));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(response.bodyBytes);
        _memoryCache[cleanUrl] = file.path;

        // Background LRU cleanup check if storage exceeded
        _checkAndCleanCache(cacheDir);

        return file.path;
      }
    } catch (e) {
      debugPrint('AudioCacheService getCachedAudioPath error: $e');
    }

    // Safe fallback to original remote URL if caching fails
    return cleanUrl;
  }

  /// Silently pre-fetches a list of voice audio URLs in the background without blocking UI
  static void prefetchList(List<String> urls) {
    if (urls.isEmpty) return;

    Future.microtask(() async {
      for (final rawUrl in urls) {
        final cleanUrl = rawUrl.trim();
        if (cleanUrl.isEmpty ||
            (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://'))) {
          continue;
        }

        if (_prefetchingUrls.contains(cleanUrl) || _memoryCache.containsKey(cleanUrl)) {
          continue;
        }

        try {
          _prefetchingUrls.add(cleanUrl);
          await getCachedAudioPath(cleanUrl);
        } catch (_) {
        } finally {
          _prefetchingUrls.remove(cleanUrl);
        }
      }
    });
  }

  static String _generateFilename(String url) {
    final ext = url.contains('.m4a')
        ? '.m4a'
        : (url.contains('.mp3')
            ? '.mp3'
            : (url.contains('.wav') ? '.wav' : '.m4a'));
    return '${url.hashCode.abs()}$ext';
  }

  /// Least-Recently-Used (LRU) automatic storage maintenance
  static Future<void> _checkAndCleanCache(Directory cacheDir) async {
    if (_isCleaning) return;
    _isCleaning = true;

    try {
      if (!cacheDir.existsSync()) return;

      final files = cacheDir.listSync().whereType<File>().toList();
      int totalBytes = 0;
      for (final f in files) {
        try {
          totalBytes += f.lengthSync();
        } catch (_) {}
      }

      if (totalBytes > maxCacheBytes) {
        // Sort files by oldest modified time first
        files.sort((a, b) {
          try {
            return a.lastModifiedSync().compareTo(b.lastModifiedSync());
          } catch (_) {
            return 0;
          }
        });

        int currentBytes = totalBytes;
        for (final f in files) {
          if (currentBytes <= targetCacheBytes) break;
          try {
            final sz = f.lengthSync();
            f.deleteSync();
            currentBytes -= sz;
          } catch (_) {}
        }
      }
    } catch (_) {
    } finally {
      _isCleaning = false;
    }
  }
}
