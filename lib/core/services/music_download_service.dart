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

  /// Downloads a YouTube Music track directly to local app storage
  Future<bool> downloadTrack(
    YoutubeTrack track, {
    void Function(double progress)? onProgress,
  }) async {
    if (isDownloaded(track.id)) return true;

    try {
      _downloadProgress[track.id] = 0.05;
      notifyListeners();
      onProgress?.call(0.05);

      final dir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${dir.path}/downloaded_music');
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final targetFile = File('${musicDir.path}/${track.id}.m4a');

      // 1. Fetch audio stream from YouTube
      final audioStream = await YoutubeMusicService.instance.getDownloadAudioStream(track.id);
      if (audioStream == null) {
        _downloadProgress.remove(track.id);
        notifyListeners();
        return false;
      }

      // 2. Stream chunks to disk with progress calculation
      final fileSink = targetFile.openWrite();
      int receivedBytes = 0;
      // Approximate size based on duration (128kbps = 16KB/s)
      final estimatedTotalBytes = (track.durationSeconds > 0 ? track.durationSeconds : 200) * 16000;

      await for (final chunk in audioStream) {
        fileSink.add(chunk);
        receivedBytes += chunk.length;
        final prog = (receivedBytes / estimatedTotalBytes).clamp(0.05, 0.95);
        _downloadProgress[track.id] = prog;
        notifyListeners();
        onProgress?.call(prog);
      }

      await fileSink.flush();
      await fileSink.close();

      // 3. Mark complete and save to manifest
      final completedTrack = track.copyWith(
        isDownloaded: true,
        localFilePath: targetFile.path,
      );

      _downloadedTracks[track.id] = completedTrack;
      _downloadProgress.remove(track.id);
      await _saveManifest();

      notifyListeners();
      onProgress?.call(1.0);
      return true;
    } catch (e) {
      debugPrint('[MusicDownloadService] Download failed for ${track.id}: $e');
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
