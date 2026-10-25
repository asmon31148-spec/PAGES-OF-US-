class MemoryItem {
  final String id;
  final String title;
  final String caption;
  final String mediaUrl;
  final String? voiceUrl;
  final String mediaType; // 'photo' | 'video' | 'audio'
  final String createdAt;
  final String? rawDate;
  final String author;
  final String authorName;
  final bool isMine;
  final int likesCount;

  MemoryItem({
    required this.id,
    required this.title,
    required this.caption,
    required this.mediaUrl,
    this.voiceUrl,
    required this.mediaType,
    required this.createdAt,
    this.rawDate,
    required this.author,
    required this.authorName,
    required this.isMine,
    this.likesCount = 0,
  });

  factory MemoryItem.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
    String? partnerNickname,
  }) {
    final authorStr = json['author']?.toString() ?? '';
    final isMine = currentUserId != null && authorStr.contains(currentUserId);
    final authorName = isMine ? 'You' : (partnerNickname ?? 'Partner');

    final mUrl = json['media_url']?.toString() ?? '';
    final thumb = json['thumbnail_url']?.toString();

    final isVideo = mUrl.contains('.mp4') ||
        mUrl.contains('.mov') ||
        mUrl.contains('.webm') ||
        mUrl.contains('video/');
    final isAudioOnly = (mUrl.isEmpty) && (thumb != null && thumb.isNotEmpty);

    final mediaType = isAudioOnly
        ? 'audio'
        : isVideo
            ? 'video'
            : 'photo';

    return MemoryItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ??
          (isAudioOnly
              ? 'Voice Whisper'
              : isVideo
                  ? 'Video Moment'
                  : 'Photo Moment'),
      caption: json['caption']?.toString() ?? '',
      mediaUrl: mUrl,
      voiceUrl: thumb != null && (thumb.startsWith('http') || thumb.startsWith('data:audio'))
          ? thumb
          : null,
      mediaType: mediaType,
      createdAt: json['created_at']?.toString() ?? '',
      rawDate: json['created_at']?.toString(),
      author: authorStr,
      authorName: authorName,
      isMine: isMine,
      likesCount: json['likes_count'] is int ? json['likes_count'] as int : 0,
    );
  }

  Map<String, dynamic> toJson({required String spaceId}) {
    return {
      'id': id,
      'space_id': spaceId,
      'title': title,
      'caption': caption,
      'media_url': mediaUrl,
      'thumbnail_url': voiceUrl,
      'author': author,
      'created_at': createdAt,
    };
  }
}
