/// Genuine timestamped Arrival / Departure event logged when partner GPS crosses a saved zone radius.
class GeofenceEvent {
  final String id;
  final String placeId;
  final String placeName;
  final String placeIcon;
  final String eventType; // 'arrived' | 'departed'
  final String timestamp;
  final double lat;
  final double lng;

  const GeofenceEvent({
    required this.id,
    required this.placeId,
    required this.placeName,
    required this.placeIcon,
    required this.eventType,
    required this.timestamp,
    required this.lat,
    required this.lng,
  });

  factory GeofenceEvent.fromJson(Map<String, dynamic> json) {
    return GeofenceEvent(
      id: json['id']?.toString() ?? '',
      placeId: json['placeId']?.toString() ?? '',
      placeName: json['placeName']?.toString() ?? 'Zone',
      placeIcon: json['placeIcon']?.toString() ?? '📍',
      eventType: json['eventType']?.toString() ?? 'arrived',
      timestamp: json['timestamp']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'placeId': placeId,
        'placeName': placeName,
        'placeIcon': placeIcon,
        'eventType': eventType,
        'timestamp': timestamp,
        'lat': lat,
        'lng': lng,
      };
}
