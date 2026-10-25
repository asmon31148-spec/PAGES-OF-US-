class PinnedPlace {
  final String id;
  final String name;
  final String icon;
  final double lat;
  final double lng;
  final double radiusMeters;
  final String createdById;
  final String createdAt;

  PinnedPlace({
    required this.id,
    required this.name,
    required this.icon,
    required this.lat,
    required this.lng,
    required this.radiusMeters,
    required this.createdById,
    required this.createdAt,
  });

  factory PinnedPlace.fromJson(Map<String, dynamic> json) {
    return PinnedPlace(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Special Place',
      icon: json['icon']?.toString() ?? '🏡',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 150.0,
      createdById: json['createdById']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'lat': lat,
      'lng': lng,
      'radiusMeters': radiusMeters,
      'createdById': createdById,
      'createdAt': createdAt,
    };
  }
}
