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
  final double? journeyKmToday;
  final int? stepsToday;
  final int? activeMinutesToday;
  final String? departurePlace;
  final int? timeZoneOffsetMinutes;
  final double? speedMps;

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
    this.journeyKmToday,
    this.stepsToday,
    this.activeMinutesToday,
    this.departurePlace,
    this.timeZoneOffsetMinutes,
    this.speedMps,
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
      updatedAt: json['updatedAt']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      journeyKmToday: (json['journeyKmToday'] as num?)?.toDouble(),
      stepsToday: (json['stepsToday'] as num?)?.toInt(),
      activeMinutesToday: (json['activeMinutesToday'] as num?)?.toInt(),
      departurePlace: json['departurePlace']?.toString(),
      timeZoneOffsetMinutes: (json['timeZoneOffsetMinutes'] as num?)?.toInt(),
      speedMps: (json['speedMps'] as num?)?.toDouble(),
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
      if (journeyKmToday != null) 'journeyKmToday': journeyKmToday,
      if (stepsToday != null) 'stepsToday': stepsToday,
      if (activeMinutesToday != null) 'activeMinutesToday': activeMinutesToday,
      if (departurePlace != null) 'departurePlace': departurePlace,
      if (timeZoneOffsetMinutes != null) 'timeZoneOffsetMinutes': timeZoneOffsetMinutes,
      if (speedMps != null) 'speedMps': speedMps,
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
    double? journeyKmToday,
    int? stepsToday,
    int? activeMinutesToday,
    String? departurePlace,
    int? timeZoneOffsetMinutes,
    double? speedMps,
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
      journeyKmToday: journeyKmToday ?? this.journeyKmToday,
      stepsToday: stepsToday ?? this.stepsToday,
      activeMinutesToday: activeMinutesToday ?? this.activeMinutesToday,
      departurePlace: departurePlace ?? this.departurePlace,
      timeZoneOffsetMinutes: timeZoneOffsetMinutes ?? this.timeZoneOffsetMinutes,
      speedMps: speedMps ?? this.speedMps,
    );
  }
}
