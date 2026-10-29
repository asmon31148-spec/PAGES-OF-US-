import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AudioCacheService {
  static final Map<String, String> _memoryCache = {};

  /// Returns a local cached file path for the given audio URL.
  /// If not yet cached, downloads it to the app's cache directory and returns the local path.
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
      if (File(cachedPath).existsSync()) {
        return cachedPath;
      }
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/audio_cache');
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }

      // Safe deterministic filename from URL hash and extension
      final ext = cleanUrl.contains('.m4a')
          ? '.m4a'
          : (cleanUrl.contains('.mp3')
              ? '.mp3'
              : (cleanUrl.contains('.wav') ? '.wav' : '.m4a'));
      final filename = '${cleanUrl.hashCode.abs()}$ext';
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
        return file.path;
      }
    } catch (_) {}

    // Fallback to original remote URL if downloading fails
    return cleanUrl;
  }
}
