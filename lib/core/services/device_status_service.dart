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

/// Reads 100% genuine Android hardware battery level & charging state via MethodChannel.
class DeviceStatusService {
  static const MethodChannel _channel = MethodChannel('com.pagesofus.app/device_status');

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
}
