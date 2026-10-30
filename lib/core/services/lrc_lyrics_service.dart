import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A single timestamped line of lyrics
class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({
    required this.timestamp,
    required this.text,
  });
}

/// Synchronized Lyrics Service using open LRCLIB
class LrcLyricsService {
  static final LrcLyricsService instance = LrcLyricsService._();
  LrcLyricsService._();

  final Map<String, List<LyricLine>> _cache = {};

  /// Fetches synchronized lyrics for a song and parses timestamped lines
  Future<List<LyricLine>> fetchLyrics({
    required String title,
    required String artist,
    int? durationSeconds,
  }) async {
    final cacheKey = '$title::$artist'.toLowerCase();
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // Clean title and artist of extra text (e.g. "(Official Music Video)", "ft.", etc.)
      final cleanTitle = _cleanSongTitle(title);
      final cleanArtist = _cleanArtistName(artist);

      final uri = Uri.https('lrclib.net', '/api/get', {
        'track_name': cleanTitle,
        'artist_name': cleanArtist,
        if (durationSeconds != null && durationSeconds > 0)
          'duration': durationSeconds.toString(),
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final syncedRaw = json['syncedLyrics']?.toString();
        if (syncedRaw != null && syncedRaw.isNotEmpty) {
          final lines = parseLrc(syncedRaw);
          _cache[cacheKey] = lines;
          return lines;
        }

        // Fallback to plain lyrics if synced not available
        final plainRaw = json['plainLyrics']?.toString();
        if (plainRaw != null && plainRaw.isNotEmpty) {
          final lines = plainRaw
              .split('\n')
              .where((l) => l.trim().isNotEmpty)
              .map((l) => LyricLine(timestamp: Duration.zero, text: l.trim()))
              .toList();
          _cache[cacheKey] = lines;
          return lines;
        }
      }
    } catch (e) {
      debugPrint('[LrcLyricsService] Fetch lyrics error: $e');
    }

    return [];
  }

  /// Parses standard LRC timestamp format: [mm:ss.xx] Lyric text
  static List<LyricLine> parseLrc(String lrc) {
    final lines = <LyricLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.?(\d{2,3})?\](.*)');

    for (final rawLine in lrc.split('\n')) {
      final match = regex.firstMatch(rawLine.trim());
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final millisRaw = match.group(3) ?? '0';
        final millis = int.tryParse(millisRaw.padRight(3, '0').substring(0, 3)) ?? 0;

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );
        final text = (match.group(4) ?? '').trim();
        if (text.isNotEmpty) {
          lines.add(LyricLine(timestamp: duration, text: text));
        }
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  static String _cleanSongTitle(String title) {
    return title
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .replaceAll(RegExp(r'ft\..*|feat\..*|official.*|video.*|audio.*', caseSensitive: false), '')
        .trim();
  }

  static String _cleanArtistName(String artist) {
    return artist.split(',')[0].split('&')[0].split('•')[0].trim();
  }
}
