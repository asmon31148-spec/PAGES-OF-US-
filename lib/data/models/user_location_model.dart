class UserLocationData {
  final String userId;
  final String nickname;
  final String? avatarUrl;
  final double lat;
  final double lng;
  final String? placeName;
  final String? neighborhood;
  final String? city;
  final String? customLabel;
  final double? accuracy;
  final bool isSharingEnabled;
  final String updatedAt;

  UserLocationData({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.lat,
    required this.lng,
    this.placeName,
    this.neighborhood,
    this.city,
    this.customLabel,
    this.accuracy,
    this.isSharingEnabled = true,
    required this.updatedAt,
  });

  factory UserLocationData.fromJson(Map<String, dynamic> json) {
    return UserLocationData(
      userId: json['userId']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? 'Partner',
      avatarUrl: json['avatarUrl']?.toString(),
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      placeName: json['placeName']?.toString(),
      neighborhood: json['neighborhood']?.toString(),
      city: json['city']?.toString(),
      customLabel: json['customLabel']?.toString(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      isSharingEnabled: json['isSharingEnabled'] != false,
      updatedAt: json['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'nickname': nickname,
      'avatarUrl': avatarUrl,
      'lat': lat,
      'lng': lng,
      'placeName': placeName,
      'neighborhood': neighborhood,
      'city': city,
      'customLabel': customLabel,
      'accuracy': accuracy,
      'isSharingEnabled': isSharingEnabled,
      'updatedAt': updatedAt,
    };
  }

  UserLocationData copyWith({
    String? userId,
    String? nickname,
    String? avatarUrl,
    double? lat,
    double? lng,
    String? placeName,
    String? neighborhood,
    String? city,
    String? customLabel,
    double? accuracy,
    bool? isSharingEnabled,
    String? updatedAt,
  }) {
    return UserLocationData(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      placeName: placeName ?? this.placeName,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      customLabel: customLabel ?? this.customLabel,
      accuracy: accuracy ?? this.accuracy,
      isSharingEnabled: isSharingEnabled ?? this.isSharingEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
