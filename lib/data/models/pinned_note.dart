class PinnedNote {
  final String userId;
  final String authorNickname;
  final String text;
  final String updatedAt;

  String get content => text;

  PinnedNote({
    required this.userId,
    required this.authorNickname,
    required this.text,
    required this.updatedAt,
  });

  factory PinnedNote.fromJson(Map<String, dynamic> json) {
    return PinnedNote(
      userId: json['userId'] as String? ?? '',
      authorNickname: json['authorNickname'] as String? ?? 'Partner',
      text: json['text'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'authorNickname': authorNickname,
      'text': text,
      'updatedAt': updatedAt,
    };
  }
}
