import 'dart:convert';
import 'package:flutter/services.dart';
import '../utils/telemetry_math.dart';

class DeviceBatteryStatus {
  final int level;
  final bool isCharging;
  final String updatedAt;

  const DeviceBatteryStatus({
    required this.level,
    required this.isCharging,
    required this.updatedAt,
  });

  factory DeviceBatteryStatus.fromJson(Map<String, dynamic> json) {
    return DeviceBatteryStatus(
      level: (json['level'] as num?)?.toInt() ?? (json['batteryLevel'] as num?)?.toInt() ?? -1,
      isCharging: json['isCharging'] == true,
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'level': level,
        'batteryLevel': level,
        'isCharging': isCharging,
        'updatedAt': updatedAt,
      };
}

/// 100% genuine Android device telemetry snapshot (mutually shared).
class DeviceTelemetry {
  final int batteryLevel;
  final bool isCharging;
  final DateTime? batteryUpdatedAt;
  final bool isScreenOn;
  final bool isDeviceUnlocked;
  final DateTime? firstUnlockedAt;
  final DateTime? lastUnlockedAt;
  final DateTime? lastLockedAt;
  final int? unlockCountToday;
  final int? lockCountToday;
  final int screenTimeSecondsToday;
  final int walkingTimeSecondsToday;
  final int appTimeSecondsToday;
  final int? stepsToday;
  final double? distanceKmToday;
  final String stepSource; // 'health_connect', 'sensor', 'none'
  final DateTime? stepsUpdatedAt;
  final String movementActivity; // 'stationary', 'walking', 'vehicle'
  final List<ScreenEvent> recentScreenEvents;
  final bool hasStepSensor;
  final String networkType; // 'wifi', 'mobile', 'offline', 'online', 'unknown'
  final DateTime? networkUpdatedAt;
  final String? nowPlayingTitle;
  final String? nowPlayingArtist;
  final String dateKey;
  final int? timeZoneOffsetMinutes;
  final bool? isIgnoringBatteryOptimizations;
  final String? healthConnectStatus;
  final String updatedAt;

  const DeviceTelemetry({
    required this.batteryLevel,
    required this.isCharging,
    this.batteryUpdatedAt,
    required this.isScreenOn,
    required this.isDeviceUnlocked,
    this.firstUnlockedAt,
    this.lastUnlockedAt,
    this.lastLockedAt,
    this.unlockCountToday,
    this.lockCountToday,
    this.screenTimeSecondsToday = 0,
    this.walkingTimeSecondsToday = 0,
    this.appTimeSecondsToday = 0,
    this.stepsToday,
    this.distanceKmToday,
    this.stepSource = 'none',
    this.stepsUpdatedAt,
    this.movementActivity = 'stationary',
    this.recentScreenEvents = const [],
    this.hasStepSensor = false,
    required this.networkType,
    this.networkUpdatedAt,
    this.nowPlayingTitle,
    this.nowPlayingArtist,
    this.dateKey = '',
    this.timeZoneOffsetMinutes,
    this.isIgnoringBatteryOptimizations,
    this.healthConnectStatus,
    required this.updatedAt,
  });

  static DateTime? _parseTimestamp(dynamic msVal, dynamic isoVal) {
    if (msVal is num && msVal.toInt() > 0) {
      return DateTime.fromMillisecondsSinceEpoch(msVal.toInt());
    }
    if (isoVal is String && isoVal.isNotEmpty) {
      return DateTime.tryParse(isoVal);
    }
    return null;
  }

  static List<ScreenEvent> _parseEvents(dynamic raw) {
    List<dynamic> list = const [];
    if (raw is List) {
      list = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) list = decoded;
      } catch (_) {}
    }
    final out = <ScreenEvent>[];
    for (final item in list) {
      if (item is Map) {
        final ev = ScreenEvent.fromJson(Map<String, dynamic>.from(item));
        if (ev.timestampMs > 0) out.add(ev);
      }
    }
    return out;
  }

  factory DeviceTelemetry.fromJson(Map<String, dynamic> json) {
    final rawSteps = (json['stepsToday'] as num?)?.toInt();
    final saneSteps = (rawSteps != null && rawSteps >= 0 && rawSteps <= 80000) ? rawSteps : null;
    final rawWalkSec = (json['walkingTimeSecondsToday'] as num?)?.toInt() ?? 0;
    final saneWalkSec = (rawWalkSec >= 0 && rawWalkSec <= 43200) ? rawWalkSec : 0;
    return DeviceTelemetry(
      batteryLevel: (json['level'] as num?)?.toInt() ?? (json['batteryLevel'] as num?)?.toInt() ?? -1,
      isCharging: json['isCharging'] == true,
      batteryUpdatedAt: _parseTimestamp(json['batteryUpdatedAtMs'], json['batteryUpdatedAt']),
      isScreenOn: json['isScreenOn'] == true,
      isDeviceUnlocked: json['isDeviceUnlocked'] == true || json['isScreenUnlocked'] == true,
      firstUnlockedAt: _parseTimestamp(json['firstUnlockedAtMs'], json['firstUnlockedAt']),
      lastUnlockedAt: _parseTimestamp(json['lastUnlockedAtMs'], json['lastUnlockedAt']),
      lastLockedAt: _parseTimestamp(json['lastLockedAtMs'], json['lastLockedAt']),
      unlockCountToday: (json['unlockCountToday'] as num?)?.toInt(),
      lockCountToday: (json['lockCountToday'] as num?)?.toInt(),
      screenTimeSecondsToday: (json['screenTimeSecondsToday'] as num?)?.toInt() ?? 0,
      walkingTimeSecondsToday: saneWalkSec,
      appTimeSecondsToday: (json['appTimeSecondsToday'] as num?)?.toInt() ?? 0,
      stepsToday: saneSteps,
      distanceKmToday: (json['distanceKmToday'] as num?)?.toDouble(),
      stepSource: json['stepSource']?.toString() ?? 'none',
      stepsUpdatedAt: _parseTimestamp(json['stepsUpdatedAtMs'], json['stepsUpdatedAt']),
      movementActivity: json['movementActivity']?.toString() ?? 'stationary',
      recentScreenEvents: _parseEvents(json['recentScreenEvents'] ?? json['recentScreenEventsJson']),
      hasStepSensor: json['hasStepSensor'] == true,
      networkType: json['networkType']?.toString() ?? 'unknown',
      networkUpdatedAt: _parseTimestamp(json['networkUpdatedAtMs'], json['networkUpdatedAt']),
      nowPlayingTitle: json['nowPlayingTitle']?.toString(),
      nowPlayingArtist: json['nowPlayingArtist']?.toString(),
      dateKey: json['dateKey']?.toString() ?? '',
      timeZoneOffsetMinutes: (json['timeZoneOffsetMinutes'] as num?)?.toInt(),
      isIgnoringBatteryOptimizations: json['isIgnoringBatteryOptimizations'] as bool?,
      healthConnectStatus: json['healthConnectStatus']?.toString(),
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'batteryLevel': batteryLevel,
        'level': batteryLevel,
        'isCharging': isCharging,
        if (batteryUpdatedAt != null) 'batteryUpdatedAtMs': batteryUpdatedAt!.millisecondsSinceEpoch,
        if (batteryUpdatedAt != null) 'batteryUpdatedAt': batteryUpdatedAt!.toUtc().toIso8601String(),
        'isScreenOn': isScreenOn,
        'isDeviceUnlocked': isDeviceUnlocked,
        if (firstUnlockedAt != null) 'firstUnlockedAtMs': firstUnlockedAt!.millisecondsSinceEpoch,
        if (lastUnlockedAt != null) 'lastUnlockedAtMs': lastUnlockedAt!.millisecondsSinceEpoch,
        if (lastLockedAt != null) 'lastLockedAtMs': lastLockedAt!.millisecondsSinceEpoch,
        if (unlockCountToday != null) 'unlockCountToday': unlockCountToday,
        if (lockCountToday != null) 'lockCountToday': lockCountToday,
        'screenTimeSecondsToday': screenTimeSecondsToday,
        'walkingTimeSecondsToday': walkingTimeSecondsToday,
        'appTimeSecondsToday': appTimeSecondsToday,
        if (stepsToday != null) 'stepsToday': stepsToday,
        if (distanceKmToday != null) 'distanceKmToday': distanceKmToday,
        'stepSource': stepSource,
        if (stepsUpdatedAt != null) 'stepsUpdatedAtMs': stepsUpdatedAt!.millisecondsSinceEpoch,
        'movementActivity': movementActivity,
        if (recentScreenEvents.isNotEmpty)
          'recentScreenEvents': recentScreenEvents.map((e) => e.toJson()).toList(),
        'hasStepSensor': hasStepSensor,
        'networkType': networkType,
        if (networkUpdatedAt != null) 'networkUpdatedAtMs': networkUpdatedAt!.millisecondsSinceEpoch,
        if (networkUpdatedAt != null) 'networkUpdatedAt': networkUpdatedAt!.toUtc().toIso8601String(),
        if (nowPlayingTitle != null && nowPlayingTitle!.isNotEmpty) 'nowPlayingTitle': nowPlayingTitle,
        if (nowPlayingArtist != null && nowPlayingArtist!.isNotEmpty) 'nowPlayingArtist': nowPlayingArtist,
        if (dateKey.isNotEmpty) 'dateKey': dateKey,
        if (timeZoneOffsetMinutes != null) 'timeZoneOffsetMinutes': timeZoneOffsetMinutes,
        if (isIgnoringBatteryOptimizations != null)
          'isIgnoringBatteryOptimizations': isIgnoringBatteryOptimizations,
        if (healthConnectStatus != null) 'healthConnectStatus': healthConnectStatus,
        'updatedAt': updatedAt,
      };

  DeviceTelemetry copyWith({
    String? nowPlayingTitle,
    String? nowPlayingArtist,
    bool clearNowPlaying = false,
  }) {
    return DeviceTelemetry(
      batteryLevel: batteryLevel,
      isCharging: isCharging,
      batteryUpdatedAt: batteryUpdatedAt,
      isScreenOn: isScreenOn,
      isDeviceUnlocked: isDeviceUnlocked,
      firstUnlockedAt: firstUnlockedAt,
      lastUnlockedAt: lastUnlockedAt,
      lastLockedAt: lastLockedAt,
      unlockCountToday: unlockCountToday,
      lockCountToday: lockCountToday,
      screenTimeSecondsToday: screenTimeSecondsToday,
      walkingTimeSecondsToday: walkingTimeSecondsToday,
      appTimeSecondsToday: appTimeSecondsToday,
      stepsToday: stepsToday,
      distanceKmToday: distanceKmToday,
      stepSource: stepSource,
      stepsUpdatedAt: stepsUpdatedAt,
      movementActivity: movementActivity,
      recentScreenEvents: recentScreenEvents,
      hasStepSensor: hasStepSensor,
      networkType: networkType,
      networkUpdatedAt: networkUpdatedAt,
      nowPlayingTitle: clearNowPlaying ? null : (nowPlayingTitle ?? this.nowPlayingTitle),
      nowPlayingArtist: clearNowPlaying ? null : (nowPlayingArtist ?? this.nowPlayingArtist),
      dateKey: dateKey,
      timeZoneOffsetMinutes: timeZoneOffsetMinutes,
      isIgnoringBatteryOptimizations: isIgnoringBatteryOptimizations,
      healthConnectStatus: healthConnectStatus,
      updatedAt: updatedAt,
    );
  }
}

/// Reads 100% genuine Android hardware battery, screen lock state, Health Connect & network transport via MethodChannel.
class DeviceStatusService {
  static const MethodChannel _channel = MethodChannel('com.pagesofus.app/device_status');

  static String? currentNowPlayingTitle;
  static String? currentNowPlayingArtist;
  static void Function()? onNowPlayingChanged;
  static void Function(int stepsToday)? onHardwareStepsUpdated;
  static bool _handlerAttached = false;

  static void ensureStepCallbackAttached() {
    if (_handlerAttached) return;
    _handlerAttached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onStepsChanged') {
        final args = call.arguments;
        if (args is Map && args['stepsToday'] is num) {
          onHardwareStepsUpdated?.call((args['stepsToday'] as num).toInt());
        }
      }
    });
  }

  static void setNowPlaying({String? title, String? artist}) {
    final cleanTitle = title?.trim();
    final cleanArtist = artist?.trim();
    if (currentNowPlayingTitle == cleanTitle && currentNowPlayingArtist == cleanArtist) return;
    currentNowPlayingTitle = cleanTitle;
    currentNowPlayingArtist = cleanArtist;
    onNowPlayingChanged?.call();
  }

  static Future<DeviceBatteryStatus?> getBatteryStatus() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getBatteryStatus');
      if (res == null) return null;
      final level = (res['level'] as num?)?.toInt() ?? (res['batteryLevel'] as num?)?.toInt() ?? -1;
      if (level < 0 || level > 100) return null;
      return DeviceBatteryStatus(
        level: level,
        isCharging: res['isCharging'] == true,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<DeviceTelemetry?> getFullTelemetry({
    String? nowPlayingTitle,
    String? nowPlayingArtist,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getFullTelemetry');
      if (res == null) return null;
      final map = Map<String, dynamic>.from(res);
      map['nowPlayingTitle'] = nowPlayingTitle;
      map['nowPlayingArtist'] = nowPlayingArtist;
      map['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      return DeviceTelemetry.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> syncStepSensor() async {
    try {
      final ok = await _channel.invokeMethod<bool>('syncStepSensor');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<int?> getHardwareStepsToday() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getHardwareStepsToday');
      if (res == null) return null;
      return (res['stepsToday'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getHealthConnectToday() async {
    try {
      return await _channel.invokeMapMethod<String, dynamic>('getHealthConnectToday');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasHealthConnectPermissions() async {
    try {
      return (await _channel.invokeMethod<bool>('hasHealthConnectPermissions')) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestHealthConnectPermissions() async {
    try {
      return (await _channel.invokeMethod<bool>('requestHealthConnectPermissions')) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return (await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations')) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      return (await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations')) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> configureTelemetryUpload({
    required String supabaseUrl,
    required String supabaseKey,
    String? accessToken,
    required String spaceId,
    required String myUserId,
    required String myName,
  }) async {
    try {
      await _channel.invokeMethod('configureTelemetryUpload', {
        'supabaseUrl': supabaseUrl,
        'supabaseKey': supabaseKey,
        'accessToken': accessToken ?? '',
        'spaceId': spaceId,
        'myUserId': myUserId,
        'myName': myName,
      });
    } catch (_) {}
  }

  static Future<void> recordAppLifecycleForeground(bool inForeground) async {
    try {
      await _channel.invokeMethod('recordAppLifecycleForeground', {
        'inForeground': inForeground,
      });
    } catch (_) {}
  }

  static Future<DailyActivitySummary?> consumePendingDailySummary({
    required String userId,
    required String spaceId,
  }) async {
    try {
      final raw = await _channel.invokeMethod<String>('consumePendingDailySummary');
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map['userId'] = userId;
      map['spaceId'] = spaceId;
      return DailyActivitySummary.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getDebugTelemetrySnapshot() async {
    try {
      return await _channel.invokeMapMethod<String, dynamic>('getDebugTelemetrySnapshot');
    } catch (_) {
      return null;
    }
  }

  static Future<void> recordSyncError(String source, String message) async {
    try {
      await _channel.invokeMethod('recordSyncError', {
        'source': source,
        'message': message,
      });
    } catch (_) {}
  }
}
