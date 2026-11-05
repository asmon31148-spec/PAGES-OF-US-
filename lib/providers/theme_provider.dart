import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/local_cache_service.dart';
import '../data/services/supabase_service.dart';
import '../core/theme/theme_registry.dart';
import '../core/theme/models/app_theme_data.dart';
import '../core/theme/models/theme_palette.dart';

/// Central state manager for the Shared Live Couple Theme System.
/// Features:
/// - Instant 0ms boot from LocalCacheService
/// - Real-time Supabase replication across partner phones
/// - Optimistic local mutations with conflict resolution
/// - Dynamic WCAG AA compliant palette tokens
class ThemeProvider extends ChangeNotifier {
  String _themeId = ThemeRegistry.defaultThemeId;
  late AppThemeData _currentTheme;
  String _brightnessMode = 'system'; // 'light' | 'dark' | 'system'
  bool _isDark = false;
  ThemePerformanceLevel _performanceLevel = ThemePerformanceLevel.full;

  String? _lastUpdatedByName;
  DateTime? _lastUpdatedAt;

  String? _activeSpaceId;
  String? _activeUserId;
  RealtimeChannel? _realtimeChannel;

  // Stream controller for partner theme update notifications (e.g. toasts)
  final _partnerThemeUpdates = StreamController<String>.broadcast();
  Stream<String> get partnerThemeUpdates => _partnerThemeUpdates.stream;

  // Getters
  String get themeId => _themeId;
  AppThemeData get currentTheme => _currentTheme;
  String get brightnessMode => _brightnessMode;
  bool get isDark => _isDark;
  ThemePerformanceLevel get performanceLevel => _performanceLevel;
  String? get lastUpdatedByName => _lastUpdatedByName;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  /// Active dynamic palette for the current brightness mode
  ThemePalette get currentPalette => _currentTheme.palette(_isDark);

  ThemeProvider() {
    _loadFromLocalCache();
  }

  void _loadFromLocalCache() {
    // 1. Theme ID
    final cachedId = LocalCacheService.getCachedThemeId();
    if (cachedId != null && cachedId.isNotEmpty) {
      _themeId = cachedId;
    }
    _currentTheme = ThemeRegistry.getById(_themeId);

    // 2. Brightness Mode ('light', 'dark', 'system')
    final cachedBrightness = LocalCacheService.getCachedBrightnessMode();
    if (cachedBrightness != null && cachedBrightness.isNotEmpty) {
      _brightnessMode = cachedBrightness;
    }

    // 3. Evaluate isDark
    _resolveBrightness();

    // 4. Performance Level
    final cachedPerf = LocalCacheService.getCachedPerformanceLevel();
    if (cachedPerf != null) {
      _performanceLevel = ThemePerformanceLevel.fromString(cachedPerf);
    }

    // 5. Partner Metadata
    _lastUpdatedByName = LocalCacheService.getCachedThemeUpdatedByName();
    final cachedDate = LocalCacheService.getCachedThemeUpdatedAt();
    if (cachedDate != null && cachedDate.isNotEmpty) {
      _lastUpdatedAt = DateTime.tryParse(cachedDate);
    }
  }

  void _resolveBrightness() {
    if (_brightnessMode == 'dark') {
      _isDark = true;
    } else if (_brightnessMode == 'light') {
      _isDark = false;
    } else {
      // 'system' mode: follow system platform brightness
      final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      _isDark = platformBrightness == Brightness.dark;
    }
  }

  /// Synchronize with partner's couple theme in Supabase Realtime
  Future<void> initThemeSync(String spaceId, String currentUserId, String currentUserName) async {
    if (_activeSpaceId == spaceId && _activeUserId == currentUserId && _realtimeChannel != null) {
      return;
    }

    _activeSpaceId = spaceId;
    _activeUserId = currentUserId;

    final client = SupabaseService.client;
    if (client == null) return;

    try {
      // 1. Fetch current shared theme from Supabase
      final response = await client
          .from('couple_themes')
          .select()
          .eq('space_id', spaceId)
          .maybeSingle();

      if (response != null) {
        _applyRemotePayload(response, isInitialFetch: true);
      } else {
        // First-time pair initialization: save initial defaults
        await client.from('couple_themes').upsert({
          'space_id': spaceId,
          'theme_id': _themeId,
          'brightness_mode': _brightnessMode,
          'performance_level': _performanceLevel.toDbString(),
          'updated_by': currentUserId,
          'updated_by_name': currentUserName,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      // 2. Subscribe to Realtime Postgres changes
      _realtimeChannel?.unsubscribe();
      final channel = client.channel('couple_theme_$spaceId');
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'couple_themes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'space_id',
          value: spaceId,
        ),
        callback: (payload) {
          final newRecord = payload.newRecord;
          if (newRecord.isNotEmpty) {
            _handleRemoteChange(newRecord, currentUserId);
          }
        },
      ).subscribe();

      _realtimeChannel = channel;
    } catch (e) {
      debugPrint('[ThemeProvider] initThemeSync error: $e');
    }
  }

  void _handleRemoteChange(Map<String, dynamic> record, String currentUserId) {
    final updatedBy = record['updated_by']?.toString();
    // Ignore self-updates (already applied optimistically)
    if (updatedBy == currentUserId) return;

    final remoteTimestampStr = record['updated_at']?.toString();
    final remoteTimestamp = remoteTimestampStr != null ? DateTime.tryParse(remoteTimestampStr) : null;

    // Conflict resolution: accept remote change if timestamp is newer
    if (remoteTimestamp != null && _lastUpdatedAt != null && remoteTimestamp.isBefore(_lastUpdatedAt!)) {
      return;
    }

    _applyRemotePayload(record, isInitialFetch: false);
  }

  void _applyRemotePayload(Map<String, dynamic> record, {required bool isInitialFetch}) {
    final newThemeId = record['theme_id']?.toString() ?? _themeId;
    final newBrightness = record['brightness_mode']?.toString() ?? _brightnessMode;
    final newPerf = record['performance_level']?.toString();
    final updatedByName = record['updated_by_name']?.toString() ?? 'Partner';
    final timestampStr = record['updated_at']?.toString();

    final hasThemeChanged = newThemeId != _themeId;
    final hasBrightnessChanged = newBrightness != _brightnessMode;
    final hasPerfChanged = newPerf != null && newPerf != _performanceLevel.toDbString();

    if (!hasThemeChanged && !hasBrightnessChanged && !hasPerfChanged && isInitialFetch) {
      return;
    }

    _themeId = newThemeId;
    _currentTheme = ThemeRegistry.getById(_themeId);
    _brightnessMode = newBrightness;
    _resolveBrightness();

    if (newPerf != null) {
      _performanceLevel = ThemePerformanceLevel.fromString(newPerf);
    }

    _lastUpdatedByName = updatedByName;
    if (timestampStr != null) {
      _lastUpdatedAt = DateTime.tryParse(timestampStr);
      LocalCacheService.setCachedThemeUpdatedAt(timestampStr);
    }

    // Persist locally
    LocalCacheService.setCachedThemeId(_themeId);
    LocalCacheService.setCachedBrightnessMode(_brightnessMode);
    LocalCacheService.setCachedIsDark(_isDark);
    LocalCacheService.setCachedPerformanceLevel(_performanceLevel.toDbString());
    LocalCacheService.setCachedThemeUpdatedByName(updatedByName);

    notifyListeners();

    if (!isInitialFetch && hasThemeChanged) {
      _partnerThemeUpdates.add('✨ $updatedByName changed theme to ${_currentTheme.name}');
    }
  }

  /// Change theme with optimistic local update and real-time partner sync
  Future<void> updateTheme(
    String newThemeId, {
    required String spaceId,
    required String userId,
    required String userName,
  }) async {
    if (_themeId == newThemeId) return;

    final oldThemeId = _themeId;
    final now = DateTime.now().toUtc();

    // 1. Optimistic local update
    _themeId = newThemeId;
    _currentTheme = ThemeRegistry.getById(_themeId);
    _lastUpdatedByName = userName;
    _lastUpdatedAt = now;

    LocalCacheService.setCachedThemeId(_themeId);
    LocalCacheService.setCachedThemeUpdatedByName(userName);
    LocalCacheService.setCachedThemeUpdatedAt(now.toIso8601String());

    notifyListeners();

    // 2. Upsert to Supabase
    final client = SupabaseService.client;
    if (client != null && spaceId.isNotEmpty) {
      try {
        await client.from('couple_themes').upsert({
          'space_id': spaceId,
          'theme_id': _themeId,
          'brightness_mode': _brightnessMode,
          'performance_level': _performanceLevel.toDbString(),
          'updated_by': userId,
          'updated_by_name': userName,
          'updated_at': now.toIso8601String(),
        });
      } catch (e) {
        debugPrint('[ThemeProvider] Error updating theme to Supabase: $e');
        // Rollback on failure
        _themeId = oldThemeId;
        _currentTheme = ThemeRegistry.getById(_themeId);
        LocalCacheService.setCachedThemeId(_themeId);
        notifyListeners();
      }
    }
  }

  /// Change brightness mode: 'light', 'dark', or 'system'
  Future<void> setBrightnessMode(
    String mode, {
    String? spaceId,
    String? userId,
    String? userName,
  }) async {
    if (_brightnessMode == mode) return;

    _brightnessMode = mode;
    _resolveBrightness();
    LocalCacheService.setCachedBrightnessMode(mode);
    LocalCacheService.setCachedIsDark(_isDark);
    notifyListeners();

    final client = SupabaseService.client;
    final effectiveSpaceId = spaceId ?? _activeSpaceId;
    final effectiveUserId = userId ?? _activeUserId;
    if (client != null && effectiveSpaceId != null && effectiveUserId != null) {
      try {
        await client.from('couple_themes').upsert({
          'space_id': effectiveSpaceId,
          'theme_id': _themeId,
          'brightness_mode': _brightnessMode,
          'performance_level': _performanceLevel.toDbString(),
          'updated_by': effectiveUserId,
          'updated_by_name': userName ?? _lastUpdatedByName ?? 'Partner',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}
    }
  }

  /// Change rendering performance level
  Future<void> setPerformanceLevel(
    ThemePerformanceLevel level, {
    String? spaceId,
    String? userId,
    String? userName,
  }) async {
    if (_performanceLevel == level) return;

    _performanceLevel = level;
    LocalCacheService.setCachedPerformanceLevel(level.toDbString());
    notifyListeners();

    final client = SupabaseService.client;
    final effectiveSpaceId = spaceId ?? _activeSpaceId;
    final effectiveUserId = userId ?? _activeUserId;
    if (client != null && effectiveSpaceId != null && effectiveUserId != null) {
      try {
        await client.from('couple_themes').upsert({
          'space_id': effectiveSpaceId,
          'theme_id': _themeId,
          'brightness_mode': _brightnessMode,
          'performance_level': _performanceLevel.toDbString(),
          'updated_by': effectiveUserId,
          'updated_by_name': userName ?? _lastUpdatedByName ?? 'Partner',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}
    }
  }

  /// Backward-compatible dark/light toggle
  void toggleDarkLight() {
    setBrightnessMode(_isDark ? 'light' : 'dark');
  }

  /// Backward-compatible theme selector
  void setTheme(String id) {
    _themeId = id;
    _currentTheme = ThemeRegistry.getById(_themeId);
    LocalCacheService.setCachedThemeId(_themeId);
    notifyListeners();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _partnerThemeUpdates.close();
    super.dispose();
  }
}
