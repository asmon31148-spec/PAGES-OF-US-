import 'package:intl/intl.dart';

/// Represents a visited stay point / stop throughout the day.
/// Recorded when a user stays within ~40-60m area for at least 15 minutes.
class StayPoint {
  final String id;
  final String userId;
  final String placeName;
  final double lat;
  final double lng;
  final DateTime arrivalTime;
  DateTime? departureTime;
  bool isCurrent;
  final String icon;

  StayPoint({
    required this.id,
    required this.userId,
    required this.placeName,
    required this.lat,
    required this.lng,
    required this.arrivalTime,
    this.departureTime,
    this.isCurrent = false,
    this.icon = '📍',
  });

  String get durationText {
    final end = departureTime ?? DateTime.now();
    final diff = end.difference(arrivalTime);
    if (diff.inMinutes < 2) return 'Just arrived';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }

  String get timeRangeText {
    final format = DateFormat('h:mm a');
    final startStr = format.format(arrivalTime);
    if (isCurrent || departureTime == null) {
      return 'Since $startStr · Current';
    }
    final endStr = format.format(departureTime!);
    return '$startStr – $endStr';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'placeName': placeName,
        'lat': lat,
        'lng': lng,
        'arrivalTime': arrivalTime.toIso8601String(),
        'departureTime': departureTime?.toIso8601String(),
        'isCurrent': isCurrent,
        'icon': icon,
      };

  factory StayPoint.fromJson(Map<String, dynamic> json) => StayPoint(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        placeName: json['placeName'] as String? ?? 'Place',
        lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
        arrivalTime: json['arrivalTime'] != null
            ? DateTime.parse(json['arrivalTime'] as String)
            : DateTime.now(),
        departureTime: json['departureTime'] != null
            ? DateTime.parse(json['departureTime'] as String)
            : null,
        isCurrent: json['isCurrent'] as bool? ?? false,
        icon: json['icon'] as String? ?? '📍',
      );
}
