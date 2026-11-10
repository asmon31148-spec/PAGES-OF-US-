/// Shared Couple Date Bucket List item (100% real places saved from Date Planner or Map Search).
class BucketPlace {
  final String id;
  final String name;
  final String category;
  final String icon;
  final String address;
  final double lat;
  final double lng;
  final String googleMapsUrl;
  final String addedById;
  final String addedByNickname;
  final String addedAt;
  final bool isVisited;
  final String? visitedAt;
  final String? note;

  const BucketPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.address,
    required this.lat,
    required this.lng,
    required this.googleMapsUrl,
    required this.addedById,
    required this.addedByNickname,
    required this.addedAt,
    this.isVisited = false,
    this.visitedAt,
    this.note,
  });

  factory BucketPlace.fromJson(Map<String, dynamic> json) {
    return BucketPlace(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Special Spot',
      category: json['category']?.toString() ?? 'place',
      icon: json['icon']?.toString() ?? '⭐',
      address: json['address']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      googleMapsUrl: json['googleMapsUrl']?.toString() ?? '',
      addedById: json['addedById']?.toString() ?? '',
      addedByNickname: json['addedByNickname']?.toString() ?? 'Partner',
      addedAt: json['addedAt']?.toString() ?? '',
      isVisited: json['isVisited'] == true,
      visitedAt: json['visitedAt']?.toString(),
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'icon': icon,
      'address': address,
      'lat': lat,
      'lng': lng,
      'googleMapsUrl': googleMapsUrl,
      'addedById': addedById,
      'addedByNickname': addedByNickname,
      'addedAt': addedAt,
      'isVisited': isVisited,
      if (visitedAt != null) 'visitedAt': visitedAt,
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }

  BucketPlace copyWith({
    bool? isVisited,
    String? visitedAt,
    String? note,
  }) {
    return BucketPlace(
      id: id,
      name: name,
      category: category,
      icon: icon,
      address: address,
      lat: lat,
      lng: lng,
      googleMapsUrl: googleMapsUrl,
      addedById: addedById,
      addedByNickname: addedByNickname,
      addedAt: addedAt,
      isVisited: isVisited ?? this.isVisited,
      visitedAt: visitedAt ?? this.visitedAt,
      note: note ?? this.note,
    );
  }
}
