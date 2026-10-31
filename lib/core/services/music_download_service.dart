import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'youtube_music_service.dart';

/// In-App Music Downloader & Offline Storage Manager
class MusicDownloadService extends ChangeNotifier {
  static final MusicDownloadService instance = MusicDownloadService._();
  MusicDownloadService._() {
    _init();
  }

  static const String _prefsKey = 'downloaded_music_manifest_v1';
  final Map<String, YoutubeTrack> _downloadedTracks = {};
  final Map<String, double> _downloadProgress = {};

  bool _initialized = false;
  bool get isInitialized => _initialized;

  List<YoutubeTrack> get downloadedTracks => _downloadedTracks.values.toList();
  Map<String, double> get activeDownloads => Map.unmodifiable(_downloadProgress);

  Future<void> _init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          final track = YoutubeTrack.fromJson(item as Map<String, dynamic>);
          // Verify file still exists on disk
          if (track.localFilePath != null && File(track.localFilePath!).existsSync()) {
            _downloadedTracks[track.id] = track;
          }
        }
      }
    } catch (e) {
      debugPrint('[MusicDownloadService] Init error: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  bool isDownloaded(String videoId) {
    final track = _downloadedTracks[videoId];
    if (track == null || track.localFilePath == null) return false;
    return File(track.localFilePath!).existsSync();
  }

  double? getDownloadProgress(String videoId) {
    return _downloadProgress[videoId];
  }

  String? getLocalFilePath(String videoId) {
    final track = _downloadedTracks[videoId];
    if (track?.localFilePath != null && File(track!.localFilePath!).existsSync()) {
      return track.localFilePath;
    }
    return null;
  }

  /// Downloads a YouTube Music track directly to local app storage with atomic file writing
  Future<bool> downloadTrack(
    YoutubeTrack track, {
    void Function(double progress)? onProgress,
  }) async {
    if (isDownloaded(track.id)) return true;

    File? tempFile;
    try {
      _downloadProgress[track.id] = 0.05;
      notifyListeners();
      onProgress?.call(0.05);

      final dir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${dir.path}/downloaded_music');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      tempFile = File('${musicDir.path}/${track.id}.tmp');
      final finalFile = File('${musicDir.path}/${track.id}.m4a');

      // 1. Resolve audio stream URL with priority to direct high-bitrate stream
      String? streamUrl = track.audioStreamUrl;
      if (streamUrl == null || streamUrl.isEmpty) {
        streamUrl = await YoutubeMusicService.instance.getAudioStreamUrl(track.id);
      }

      Stream<List<int>>? audioStream;
      int actualContentLength = -1;

      if (streamUrl != null && streamUrl.isNotEmpty) {
        try {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 15);
          final request = await client.getUrl(Uri.parse(streamUrl));
          request.headers.set(
            'User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          );
          request.headers.set('Accept', '*/*');
          final response = await request.close();
          if (response.statusCode >= 200 && response.statusCode < 300) {
            audioStream = response;
            actualContentLength = response.contentLength;
          }
        } catch (e) {
          debugPrint('[MusicDownloadService] Direct stream connection failed: $e');
        }
      }

      // Fallback if direct stream was not resolved
      audioStream ??= await YoutubeMusicService.instance.getDownloadAudioStream(track.id);

      if (audioStream == null) {
        _downloadProgress.remove(track.id);
        notifyListeners();
        return false;
      }

      // 2. Stream chunks to temp disk file with throttled progress tracking (max ~8-10 updates/sec)
      final fileSink = tempFile.openWrite();
      int receivedBytes = 0;
      final estimatedTotalBytes = actualContentLength > 0
          ? actualContentLength
          : ((track.durationSeconds > 0 ? track.durationSeconds : 200) * 16000);

      int lastNotifyMs = 0;
      double lastNotifiedProg = 0.05;

      await for (final chunk in audioStream) {
        fileSink.add(chunk);
        receivedBytes += chunk.length;
        final prog = (receivedBytes / estimatedTotalBytes).clamp(0.05, 0.95);
        _downloadProgress[track.id] = prog;

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs - lastNotifyMs >= 150 || (prog - lastNotifiedProg) >= 0.03) {
          lastNotifyMs = nowMs;
          lastNotifiedProg = prog;
          notifyListeners();
          onProgress?.call(prog);
        }
      }

      await fileSink.flush();
      await fileSink.close();

      // Ensure file has content (> 10 KB)
      if (await tempFile.length() < 10240) {
        throw Exception('Downloaded file too small: ${await tempFile.length()} bytes');
      }

      // 3. Atomically promote to final .m4a file
      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tempFile.rename(finalFile.path);

      // 4. Mark complete and save to manifest
      final completedTrack = track.copyWith(
        isDownloaded: true,
        localFilePath: finalFile.path,
      );

      _downloadedTracks[track.id] = completedTrack;
      _downloadProgress.remove(track.id);
      await _saveManifest();

      notifyListeners();
      onProgress?.call(1.0);
      return true;
    } catch (e) {
      debugPrint('[MusicDownloadService] Download failed for ${track.id}: $e');
      if (tempFile != null && tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
      _downloadProgress.remove(track.id);
      notifyListeners();
      return false;
    }
  }

  /// Deletes a downloaded track to free up device space
  Future<void> deleteTrack(String videoId) async {
    final track = _downloadedTracks[videoId];
    if (track?.localFilePath != null) {
      try {
        final f = File(track!.localFilePath!);
        if (await f.exists()) {
          await f.delete();
        }
      } catch (e) {
        debugPrint('[MusicDownloadService] Delete file error: $e');
      }
    }
    _downloadedTracks.remove(videoId);
    await _saveManifest();
    notifyListeners();
  }

  /// Calculates total offline storage occupied in MB
  Future<double> getTotalStorageUsedMb() async {
    double totalBytes = 0;
    for (final track in _downloadedTracks.values) {
      if (track.localFilePath != null) {
        final f = File(track.localFilePath!);
        if (f.existsSync()) {
          totalBytes += f.lengthSync();
        }
      }
    }
    return totalBytes / (1024 * 1024);
  }

  Future<void> _saveManifest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _downloadedTracks.values.map((t) => t.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[MusicDownloadService] Save manifest error: $e');
    }
  }
}
