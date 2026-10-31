import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Represents a song result from YouTube Music / Sanctuary Music
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

/// Pure Dart DES ECB Decryptor (Zero dependencies, 100% platform-agnostic)
class _DesEcb {
  static const List<int> _ip = [
    58, 50, 42, 34, 26, 18, 10, 2,
    60, 52, 44, 36, 28, 20, 12, 4,
    62, 54, 46, 38, 30, 22, 14, 6,
    64, 56, 48, 40, 32, 24, 16, 8,
    57, 49, 41, 33, 25, 17, 9, 1,
    59, 51, 43, 35, 27, 19, 11, 3,
    61, 53, 45, 37, 29, 21, 13, 5,
    63, 55, 47, 39, 31, 23, 15, 7,
  ];

  static const List<int> _fp = [
    40, 8, 48, 16, 56, 24, 64, 32,
    39, 7, 47, 15, 55, 23, 63, 31,
    38, 6, 46, 14, 54, 22, 62, 30,
    37, 5, 45, 13, 53, 21, 61, 29,
    36, 4, 44, 12, 52, 20, 60, 28,
    35, 3, 43, 11, 51, 19, 59, 27,
    34, 2, 42, 10, 50, 18, 58, 26,
    33, 1, 41, 9, 49, 17, 57, 25,
  ];

  static const List<int> _pc1 = [
    57, 49, 41, 33, 25, 17, 9,
    1, 58, 50, 42, 34, 26, 18,
    10, 2, 59, 51, 43, 35, 27,
    19, 11, 3, 60, 52, 44, 36,
    63, 55, 47, 39, 31, 23, 15,
    7, 62, 54, 46, 38, 30, 22,
    14, 6, 61, 53, 45, 37, 29,
    21, 13, 5, 28, 20, 12, 4,
  ];

  static const List<int> _pc2 = [
    14, 17, 11, 24, 1, 5,
    3, 28, 15, 6, 21, 10,
    23, 19, 12, 4, 26, 8,
    16, 7, 27, 20, 13, 2,
    41, 52, 31, 37, 47, 55,
    30, 40, 51, 45, 33, 48,
    44, 49, 39, 56, 34, 53,
    46, 42, 50, 36, 29, 32,
  ];

  static const List<int> _shifts = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1];

  static const List<int> _e = [
    32, 1, 2, 3, 4, 5,
    4, 5, 6, 7, 8, 9,
    8, 9, 10, 11, 12, 13,
    12, 13, 14, 15, 16, 17,
    16, 17, 18, 19, 20, 21,
    20, 21, 22, 23, 24, 25,
    24, 25, 26, 27, 28, 29,
    28, 29, 30, 31, 32, 1,
  ];

  static const List<List<List<int>>> _s = [
    [
      [14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7],
      [0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8],
      [4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0],
      [15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13],
    ],
    [
      [15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10],
      [3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5],
      [0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15],
      [13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9],
    ],
    [
      [10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8],
      [13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1],
      [13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7],
      [1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12],
    ],
    [
      [7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15],
      [13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9],
      [10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4],
      [3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14],
    ],
    [
      [2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9],
      [14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6],
      [4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14],
      [11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3],
    ],
    [
      [12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11],
      [10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8],
      [9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6],
      [4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13],
    ],
    [
      [4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1],
      [13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6],
      [1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2],
      [6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12],
    ],
    [
      [13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7],
      [1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2],
      [7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8],
      [2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11],
    ],
  ];

  static const List<int> _p = [
    16, 7, 20, 21, 29, 12, 28, 17,
    1, 15, 23, 26, 5, 18, 31, 10,
    2, 8, 24, 14, 32, 27, 3, 9,
    19, 13, 30, 6, 22, 11, 4, 25,
  ];

  static List<int> _bytesToBits(List<int> bytes) {
    final bits = <int>[];
    for (int i = 0; i < bytes.length; i++) {
      for (int b = 7; b >= 0; b--) {
        bits.add((bytes[i] >> b) & 1);
      }
    }
    return bits;
  }

  static List<int> _bitsToBytes(List<int> bits) {
    final bytes = <int>[];
    for (int i = 0; i < bits.length; i += 8) {
      int byte = 0;
      for (int b = 0; b < 8; b++) {
        byte = (byte << 1) | bits[i + b];
      }
      bytes.add(byte);
    }
    return bytes;
  }

  static List<int> _permute(List<int> bits, List<int> table) {
    return List.generate(table.length, (i) => bits[table[i] - 1]);
  }

  static List<List<int>> _generateSubkeys(List<int> keyBytes) {
    final keyBits = _bytesToBits(keyBytes);
    final permutedKey = _permute(keyBits, _pc1);
    var c = permutedKey.sublist(0, 28);
    var d = permutedKey.sublist(28, 56);
    final subkeys = <List<int>>[];

    for (int i = 0; i < 16; i++) {
      final shift = _shifts[i];
      c = [...c.sublist(shift), ...c.sublist(0, shift)];
      d = [...d.sublist(shift), ...d.sublist(0, shift)];
      subkeys.add(_permute([...c, ...d], _pc2));
    }
    return subkeys;
  }

  static List<int> _feistel(List<int> r, List<int> subkey) {
    final expanded = _permute(r, _e);
    final xored = List.generate(48, (i) => expanded[i] ^ subkey[i]);
    final sOutput = <int>[];

    for (int i = 0; i < 8; i++) {
      final block = xored.sublist(i * 6, (i + 1) * 6);
      final row = (block[0] << 1) | block[5];
      final col = (block[1] << 3) | (block[2] << 2) | (block[3] << 1) | block[4];
      final val = _s[i][row][col];
      for (int b = 3; b >= 0; b--) {
        sOutput.add((val >> b) & 1);
      }
    }
    return _permute(sOutput, _p);
  }

  static List<int> _decryptBlock(List<int> blockBytes, List<List<int>> subkeys) {
    final bits = _permute(_bytesToBits(blockBytes), _ip);
    var l = bits.sublist(0, 32);
    var r = bits.sublist(32, 64);

    for (int i = 15; i >= 0; i--) {
      final f = _feistel(r, subkeys[i]);
      final nextL = r;
      final nextR = List.generate(32, (idx) => l[idx] ^ f[idx]);
      l = nextL;
      r = nextR;
    }

    final preOutput = [...r, ...l];
    return _bitsToBytes(_permute(preOutput, _fp));
  }

  static String decrypt(String base64Encrypted, String keyUtf8) {
    try {
      final cipherBytes = base64.decode(base64Encrypted);
      final keyBytes = utf8.encode(keyUtf8);
      final subkeys = _generateSubkeys(keyBytes);
      final decryptedBytes = <int>[];

      for (int i = 0; i < cipherBytes.length; i += 8) {
        if (i + 8 <= cipherBytes.length) {
          final block = cipherBytes.sublist(i, i + 8);
          decryptedBytes.addAll(_decryptBlock(block, subkeys));
        }
      }

      if (decryptedBytes.isEmpty) return '';

      // PKCS7 Unpadding
      final pad = decryptedBytes.last;
      int length = decryptedBytes.length;
      if (pad > 0 && pad <= 8 && length >= pad) {
        bool validPad = true;
        for (int p = length - pad; p < length; p++) {
          if (decryptedBytes[p] != pad) {
            validPad = false;
            break;
          }
        }
        if (validPad) {
          length -= pad;
        }
      }

      return utf8.decode(decryptedBytes.sublist(0, length));
    } catch (e) {
      debugPrint('[DesEcb] Decryption error: $e');
      return '';
    }
  }
}

/// Core Music Streaming & Discovery Service (High-Speed Sanctuary Engine)
class YoutubeMusicService {
  static final YoutubeMusicService instance = YoutubeMusicService._();
  YoutubeMusicService._();

  YoutubeExplode? _yt;
  YoutubeExplode get _client => _yt ??= YoutubeExplode();

  // In-memory cache for audio stream URLs (valid across session)
  final Map<String, String> _streamCache = {};
  final Map<String, DateTime> _streamCacheTime = {};

  static String _unescapeHtml(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }

  /// Filter out spam duplicates so every result has a unique, distinct title
  List<YoutubeTrack> _deduplicateTracks(List<YoutubeTrack> tracks) {
    final seenTitles = <String>{};
    final unique = <YoutubeTrack>[];

    for (final t in tracks) {
      final cleanTitle = t.title
          .toLowerCase()
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .replaceAll(RegExp(r'\[[^\]]*\]'), '')
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .trim();

      // Only allow unique song titles - never repeat identical titles!
      if (!seenTitles.contains(cleanTitle) && cleanTitle.isNotEmpty) {
        seenTitles.add(cleanTitle);
        unique.add(t);
      }
    }
    return unique;
  }

  /// High-speed global song search: JioSaavn 320kbps Primary + YouTube InnerTube Fallback
  Future<List<YoutubeTrack>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      // 1. Primary: JioSaavn High-Quality DRM-Free Music Network (320kbps MP4)
      final saavnResults = await _searchSaavn(cleanQuery);
      if (saavnResults.isNotEmpty) {
        debugPrint('[YoutubeMusicService] Found ${saavnResults.length} tracks via Saavn network');
        return _deduplicateTracks(saavnResults);
      }
    } catch (e) {
      debugPrint('[YoutubeMusicService] Saavn search fallback: $e');
    }

    try {
      // 2. Secondary: InnerTube WEB_REMIX API
      final innerTubeResults = await _searchInnerTube(cleanQuery);
      if (innerTubeResults.isNotEmpty) return _deduplicateTracks(innerTubeResults);
    } catch (e) {
      debugPrint('[YoutubeMusicService] InnerTube search fallback: $e');
    }

    try {
      // 3. Final Fallback: YoutubeExplode search
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
      return _deduplicateTracks(tracks);
    } catch (e) {
      debugPrint('[YoutubeMusicService] Final search fallback error: $e');
      return [];
    }
  }

  /// JioSaavn direct catalog search with instant 320kbps URL extraction
  Future<List<YoutubeTrack>> _searchSaavn(String query) async {
    final url = Uri.parse(
      'https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&cc=in&p=1&n=25&q=${Uri.encodeComponent(query)}',
    );

    final res = await http.get(
      url,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
      },
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) return [];

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final results = json['results'] as List?;
    if (results == null || results.isEmpty) return [];

    final tracks = <YoutubeTrack>[];

    for (final item in results) {
      if (item is! Map<String, dynamic>) continue;

      final rawId = item['id']?.toString() ?? '';
      if (rawId.isEmpty) continue;
      final trackId = 'saavn_$rawId';

      final title = _unescapeHtml(item['song']?.toString() ?? 'Unknown Title');
      final singers = item['singers']?.toString() ?? '';
      final primaryArtists = item['primary_artists']?.toString() ?? '';
      final artist = _unescapeHtml(singers.isNotEmpty ? singers : (primaryArtists.isNotEmpty ? primaryArtists : 'Sanctuary Music'));

      final durationSec = int.tryParse(item['duration']?.toString() ?? '') ?? 210;

      final rawImage = item['image']?.toString() ?? '';
      final thumb = rawImage.replaceAll('150x150', '500x500');

      final encUrl = item['encrypted_media_url']?.toString() ?? '';
      String? streamUrl;
      if (encUrl.isNotEmpty) {
        final decrypted = _DesEcb.decrypt(encUrl, '38346591');
        if (decrypted.isNotEmpty) {
          streamUrl = decrypted.replaceAll('_96.mp4', '_320.mp4').replaceAll('_160.mp4', '_320.mp4');
          _streamCache[trackId] = streamUrl;
          _streamCacheTime[trackId] = DateTime.now();
        }
      }

      tracks.add(
        YoutubeTrack(
          id: trackId,
          title: title,
          artist: artist,
          durationSeconds: durationSec,
          thumbnailUrl: thumb,
          audioStreamUrl: streamUrl,
        ),
      );
    }

    return tracks;
  }

  /// InnerTube WEB_REMIX endpoint implementation
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

      if (s is Map<String, dynamic> && s.containsKey('itemSectionRenderer')) {
        final contents = s['itemSectionRenderer']?['contents'] as List?;
        if (contents != null) {
          for (final c in contents) {
            if (c is Map<String, dynamic> && c.containsKey('musicResponsiveListItemRenderer')) {
              final item = c['musicResponsiveListItemRenderer'] as Map<String, dynamic>;
              final flexCols = item['flexColumns'] as List?;
              if (flexCols == null || flexCols.isEmpty) continue;

              final col0 = flexCols.isNotEmpty && flexCols[0] is Map ? flexCols[0] as Map : null;
              final col0Renderer = col0?['musicResponsiveListItemFlexColumnRenderer'] as Map?;
              final titleRuns = col0Renderer?['text']?['runs'] as List?;
              final title = titleRuns != null
                  ? titleRuns.map((r) => (r is Map ? r['text']?.toString() : null) ?? '').join('')
                  : '';

              final col1 = flexCols.length > 1 && flexCols[1] is Map ? flexCols[1] as Map : null;
              final col1Renderer = col1?['musicResponsiveListItemFlexColumnRenderer'] as Map?;
              final subRuns = col1Renderer?['text']?['runs'] as List?;
              final subtitle = subRuns != null
                  ? subRuns.map((r) => (r is Map ? r['text']?.toString() : null) ?? '').join('')
                  : '';

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

  /// Extracts direct audio stream URL (valid across entire session)
  Future<String?> getAudioStreamUrl(String trackId) async {
    // 1. Check in-memory cache
    if (_streamCache.containsKey(trackId)) {
      final cacheTime = _streamCacheTime[trackId];
      if (cacheTime != null && DateTime.now().difference(cacheTime).inHours < 8) {
        return _streamCache[trackId];
      }
    }

    // 2. If it's a Saavn track ID, fetch song details directly
    if (trackId.startsWith('saavn_')) {
      try {
        final pid = trackId.replaceFirst('saavn_', '');
        final url = Uri.parse(
          'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=$pid&_format=json&_marker=0&cc=in',
        );
        final res = await http.get(url, headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        }).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final songData = json[pid] as Map<String, dynamic>?;
          final encUrl = songData?['encrypted_media_url']?.toString() ?? '';
          if (encUrl.isNotEmpty) {
            final decrypted = _DesEcb.decrypt(encUrl, '38346591');
            if (decrypted.isNotEmpty) {
              final directUrl = decrypted
                  .replaceAll('_96.mp4', '_320.mp4')
                  .replaceAll('_160.mp4', '_320.mp4');
              _streamCache[trackId] = directUrl;
              _streamCacheTime[trackId] = DateTime.now();
              return directUrl;
            }
          }
        }
      } catch (e) {
        debugPrint('[YoutubeMusicService] Error resolving Saavn details for $trackId: $e');
      }
    }

    // 3. Fallback: YouTube Explode stream manifest
    try {
      final manifest = await _client.videos.streamsClient.getManifest(
        trackId,
        ytClients: [
          YoutubeApiClient.ios,
          YoutubeApiClient.androidVr,
          YoutubeApiClient.safari,
        ],
      );

      final mp4Streams = manifest.audioOnly.where(
        (s) =>
            s.container.name.toLowerCase() == 'mp4' ||
            s.codec.mimeType.contains('mp4') ||
            s.codec.mimeType.contains('aac'),
      );
      final audioStream = mp4Streams.isNotEmpty
          ? mp4Streams.withHighestBitrate()
          : manifest.audioOnly.withHighestBitrate();

      final streamUrl = audioStream.url.toString();

      _streamCache[trackId] = streamUrl;
      _streamCacheTime[trackId] = DateTime.now();

      return streamUrl;
    } catch (e) {
      debugPrint('[YoutubeMusicService] Failed to extract YouTube stream for $trackId: $e');
      return null;
    }
  }

  /// Retrieves an audio stream for downloading
  Future<Stream<List<int>>?> getDownloadAudioStream(String trackId) async {
    final streamUrl = await getAudioStreamUrl(trackId);
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
          return response;
        }
      } catch (e) {
        debugPrint('[YoutubeMusicService] HttpClient download stream error: $e');
      }
    }

    // Fallback: YouTube Explode stream client
    try {
      final manifest = await _client.videos.streamsClient.getManifest(
        trackId,
        ytClients: [
          YoutubeApiClient.ios,
          YoutubeApiClient.androidVr,
          YoutubeApiClient.safari,
        ],
      );
      final mp4Streams = manifest.audioOnly.where(
        (s) =>
            s.container.name.toLowerCase() == 'mp4' ||
            s.codec.mimeType.contains('mp4') ||
            s.codec.mimeType.contains('aac'),
      );
      final audioStream = mp4Streams.isNotEmpty
          ? mp4Streams.withHighestBitrate()
          : manifest.audioOnly.withHighestBitrate();

      return _client.videos.streamsClient.get(audioStream);
    } catch (e) {
      debugPrint('[YoutubeMusicService] Final fallback stream error for $trackId: $e');
      return null;
    }
  }

  void dispose() {
    _yt?.close();
    _yt = null;
  }
}
