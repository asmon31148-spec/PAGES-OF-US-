import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class LocalCacheService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('LocalCacheService must be initialized before use');
    }
    return _prefs!;
  }

  // User Profile
  static Map<String, dynamic>? getCachedUser() {
    final str = _prefs?.getString(AppConstants.prefUser);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCachedUser(Map<String, dynamic>? user) async {
    if (user == null) {
      await _prefs?.remove(AppConstants.prefUser);
    } else {
      await _prefs?.setString(AppConstants.prefUser, jsonEncode(user));
    }
  }

  // Space Data
  static Map<String, dynamic>? getCachedSpace() {
    final str = _prefs?.getString(AppConstants.prefSpace);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCachedSpace(Map<String, dynamic>? space) async {
    if (space == null) {
      await _prefs?.remove(AppConstants.prefSpace);
    } else {
      await _prefs?.setString(AppConstants.prefSpace, jsonEncode(space));
    }
  }

  // Partner Profile
  static Map<String, dynamic>? getCachedPartner() {
    final str = _prefs?.getString(AppConstants.prefPartner);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCachedPartner(Map<String, dynamic>? partner) async {
    if (partner == null) {
      await _prefs?.remove(AppConstants.prefPartner);
    } else {
      await _prefs?.setString(AppConstants.prefPartner, jsonEncode(partner));
    }
  }

  // Anniversary
  static String? getCachedAnniversary() =>
      _prefs?.getString(AppConstants.prefAnniversary);

  static Future<void> setCachedAnniversary(String? date) async {
    if (date == null) {
      await _prefs?.remove(AppConstants.prefAnniversary);
    } else {
      await _prefs?.setString(AppConstants.prefAnniversary, date);
    }
  }

  // Moods
  static Map<String, dynamic>? getCachedMyMood() {
    final str = _prefs?.getString(AppConstants.prefMyMood);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCachedMyMood(Map<String, dynamic>? mood) async {
    if (mood == null) {
      await _prefs?.remove(AppConstants.prefMyMood);
    } else {
      await _prefs?.setString(AppConstants.prefMyMood, jsonEncode(mood));
    }
  }

  static Map<String, dynamic>? getCachedPartnerMood() {
    final str = _prefs?.getString(AppConstants.prefPartnerMood);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCachedPartnerMood(Map<String, dynamic>? mood) async {
    if (mood == null) {
      await _prefs?.remove(AppConstants.prefPartnerMood);
    } else {
      await _prefs?.setString(AppConstants.prefPartnerMood, jsonEncode(mood));
    }
  }

  // Daily Prompt & Checkin
  static Map<String, dynamic>? getCachedDailyPrompt() {
    final str = _prefs?.getString(AppConstants.prefDailyPrompt);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCachedDailyPrompt(Map<String, dynamic>? prompt) async {
    if (prompt == null) {
      await _prefs?.remove(AppConstants.prefDailyPrompt);
    } else {
      await _prefs?.setString(AppConstants.prefDailyPrompt, jsonEncode(prompt));
    }
  }

  // Pinned Notes
  static Map<String, dynamic>? getCachedPinnedNotes() {
    final str = _prefs?.getString(AppConstants.prefPinnedNotes);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCachedPinnedNotes(Map<String, dynamic>? notes) async {
    if (notes == null) {
      await _prefs?.remove(AppConstants.prefPinnedNotes);
    } else {
      await _prefs?.setString(AppConstants.prefPinnedNotes, jsonEncode(notes));
    }
  }

  // Theme
  static bool? getCachedIsDark() => _prefs?.getBool(AppConstants.prefIsDark);

  static Future<void> setCachedIsDark(bool isDark) async {
    await _prefs?.setBool(AppConstants.prefIsDark, isDark);
  }

  // Music Songs & Deleted IDs (Persistent across app restarts)
  static List<Map<String, dynamic>>? getCachedSongs() {
    final str = _prefs?.getString('cached_music_songs');
    if (str == null || str.isEmpty) return null;
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCachedSongs(List<Map<String, dynamic>> songs) async {
    await _prefs?.setString('cached_music_songs', jsonEncode(songs));
  }

  static List<String> getCachedDeletedSongIds() {
    return _prefs?.getStringList('cached_deleted_song_ids') ?? [];
  }

  static Future<void> setCachedDeletedSongIds(List<String> ids) async {
    await _prefs?.setStringList('cached_deleted_song_ids', ids);
  }

  // Clear cache on logout
  static Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
