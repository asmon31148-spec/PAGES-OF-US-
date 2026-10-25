class LetterItem {
  final String id;
  final String title;
  final String body;
  final String author;
  final String authorName;
  final bool isMine;
  final String createdAt;
  final String writtenDate;
  final String sealType; // 'green', 'terra', 'slate', 'rose'
  final String category;
  final String? sealedUntilDate; // YYYY-MM-DD
  final bool isRead;
  final String? voiceUrl;

  LetterItem({
    required this.id,
    required this.title,
    required this.body,
    required this.author,
    required this.authorName,
    required this.isMine,
    required this.createdAt,
    required this.writtenDate,
    this.sealType = 'green',
    this.category = 'For a quiet day',
    this.sealedUntilDate,
    this.isRead = false,
    this.voiceUrl,
  });

  factory LetterItem.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
    String? partnerNickname,
  }) {
    final authorStr = json['author']?.toString() ?? '';
    final isMine = currentUserId != null && authorStr.contains(currentUserId);
    final authorName = isMine ? 'You' : (partnerNickname ?? 'Partner');

    final envelope = json['envelope_color']?.toString() ?? 'green:For a quiet day';
    final parts = envelope.split(':');
    final seal = parts.isNotEmpty ? parts[0] : 'green';
    final cat = parts.length > 1 ? parts.sublist(1).join(':') : 'For a quiet day';

    final createdStr = json['created_at']?.toString() ?? '';
    final sealedUntil = json['sealed_until']?.toString();

    return LetterItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Sealed Letter',
      body: json['body']?.toString() ?? '',
      author: authorStr,
      authorName: authorName,
      isMine: isMine,
      createdAt: createdStr,
      writtenDate: createdStr,
      sealType: seal,
      category: cat,
      sealedUntilDate: sealedUntil != null && sealedUntil.isNotEmpty ? sealedUntil : null,
      isRead: json['is_read'] == true,
      voiceUrl: json['voice_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson({required String spaceId}) {
    return {
      'id': id,
      'space_id': spaceId,
      'title': title,
      'body': body,
      'author': author,
      'envelope_color': '$sealType:$category',
      'sealed_until': sealedUntilDate,
      'is_read': isRead,
      'created_at': createdAt,
    };
  }
}
