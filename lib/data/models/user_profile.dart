class UserProfile {
  final String id;
  final String email;
  final String nickname;
  final String? avatarUrl;
  final String? thought;
  final String? spaceId;
  final String? fcmToken;
  final String? createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.nickname,
    this.avatarUrl,
    this.thought,
    this.spaceId,
    this.fcmToken,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      nickname: json['nickname'] as String? ?? 'Partner',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String? ?? json['photoURL'] as String?,
      thought: json['thought'] as String?,
      spaceId: json['spaceId'] as String? ?? json['space_id'] as String?,
      fcmToken: json['fcmToken'] as String? ?? json['fcm_token'] as String?,
      createdAt: json['createdAt'] as String? ?? json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nickname': nickname,
      'avatarUrl': avatarUrl,
      'thought': thought,
      'spaceId': spaceId,
      if (spaceId != null) 'space_id': spaceId,
      if (fcmToken != null) 'fcmToken': fcmToken,
      'createdAt': createdAt,
    };
  }

  UserProfile copyWith({
    String? nickname,
    String? avatarUrl,
    String? thought,
    String? spaceId,
    String? fcmToken,
  }) {
    return UserProfile(
      id: id,
      email: email,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      thought: thought ?? this.thought,
      spaceId: spaceId ?? this.spaceId,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
    );
  }
}
