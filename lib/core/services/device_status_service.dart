import 'package:flutter/services.dart';

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
      level: (json['level'] as num?)?.toInt() ?? -1,
      isCharging: json['isCharging'] == true,
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'level': level,
        'isCharging': isCharging,
        'updatedAt': updatedAt,
      };
}

/// 100% genuine Android device telemetry snapshot (mutually shared).
class DeviceTelemetry {
  final int batteryLevel;
  final bool isCharging;
  final bool isScreenOn;
  final bool isDeviceUnlocked;
  final DateTime? lastUnlockedAt;
  final int? unlockCountToday;
  final int? stepsToday;
  final bool hasStepSensor;
  final String networkType; // 'wifi', 'mobile', 'offline', 'online', 'unknown'
  final String? nowPlayingTitle;
  final String? nowPlayingArtist;
  final String updatedAt;

  const DeviceTelemetry({
    required this.batteryLevel,
    required this.isCharging,
    required this.isScreenOn,
    required this.isDeviceUnlocked,
    this.lastUnlockedAt,
    this.unlockCountToday,
    this.stepsToday,
    this.hasStepSensor = false,
    required this.networkType,
    this.nowPlayingTitle,
    this.nowPlayingArtist,
    required this.updatedAt,
  });

  factory DeviceTelemetry.fromJson(Map<String, dynamic> json) {
    final ms = (json['lastUnlockedAtMs'] as num?)?.toInt();
    return DeviceTelemetry(
      batteryLevel: (json['level'] as num?)?.toInt() ?? (json['batteryLevel'] as num?)?.toInt() ?? -1,
      isCharging: json['isCharging'] == true,
      isScreenOn: json['isScreenOn'] == true,
      isDeviceUnlocked: json['isDeviceUnlocked'] == true,
      lastUnlockedAt: ms != null && ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null,
      unlockCountToday: (json['unlockCountToday'] as num?)?.toInt(),
      stepsToday: (json['stepsToday'] as num?)?.toInt(),
      hasStepSensor: json['hasStepSensor'] == true,
      networkType: json['networkType']?.toString() ?? 'unknown',
      nowPlayingTitle: json['nowPlayingTitle']?.toString(),
      nowPlayingArtist: json['nowPlayingArtist']?.toString(),
      updatedAt: json['updatedAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'batteryLevel': batteryLevel,
        'level': batteryLevel,
        'isCharging': isCharging,
        'isScreenOn': isScreenOn,
        'isDeviceUnlocked': isDeviceUnlocked,
        if (lastUnlockedAt != null) 'lastUnlockedAtMs': lastUnlockedAt!.millisecondsSinceEpoch,
        if (unlockCountToday != null) 'unlockCountToday': unlockCountToday,
        if (stepsToday != null) 'stepsToday': stepsToday,
        'hasStepSensor': hasStepSensor,
        'networkType': networkType,
        if (nowPlayingTitle != null && nowPlayingTitle!.isNotEmpty) 'nowPlayingTitle': nowPlayingTitle,
        if (nowPlayingArtist != null && nowPlayingArtist!.isNotEmpty) 'nowPlayingArtist': nowPlayingArtist,
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
      isScreenOn: isScreenOn,
      isDeviceUnlocked: isDeviceUnlocked,
      lastUnlockedAt: lastUnlockedAt,
      unlockCountToday: unlockCountToday,
      stepsToday: stepsToday,
      hasStepSensor: hasStepSensor,
      networkType: networkType,
      nowPlayingTitle: clearNowPlaying ? null : (nowPlayingTitle ?? this.nowPlayingTitle),
      nowPlayingArtist: clearNowPlaying ? null : (nowPlayingArtist ?? this.nowPlayingArtist),
      updatedAt: updatedAt,
    );
  }
}

/// Reads 100% genuine Android hardware battery, screen lock state, & network transport via MethodChannel.
class DeviceStatusService {
  static const MethodChannel _channel = MethodChannel('com.pagesofus.app/device_status');

  static String? currentNowPlayingTitle;
  static String? currentNowPlayingArtist;
  static void Function()? onNowPlayingChanged;

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
      final level = (res['level'] as num?)?.toInt() ?? -1;
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
      final ms = (res['lastUnlockedAtMs'] as num?)?.toInt();
      return DeviceTelemetry(
        batteryLevel: (res['level'] as num?)?.toInt() ?? -1,
        isCharging: res['isCharging'] == true,
        isScreenOn: res['isScreenOn'] == true,
        isDeviceUnlocked: res['isDeviceUnlocked'] == true,
        lastUnlockedAt: ms != null && ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null,
        unlockCountToday: (res['unlockCountToday'] as num?)?.toInt(),
        stepsToday: (res['stepsToday'] as num?)?.toInt(),
        hasStepSensor: res['hasStepSensor'] == true,
        networkType: res['networkType']?.toString() ?? 'unknown',
        nowPlayingTitle: nowPlayingTitle,
        nowPlayingArtist: nowPlayingArtist,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
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
}
