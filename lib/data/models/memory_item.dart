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

    final isAudio = (mUrl.isEmpty && (thumb != null && thumb.isNotEmpty)) ||
        mUrl.contains('.m4a') ||
        mUrl.contains('.mp3') ||
        mUrl.contains('.wav') ||
        mUrl.contains('.aac') ||
        mUrl.contains('audio/') ||
        mUrl.contains('vault_voice') ||
        mUrl.contains('memories_voice');

    final isVideo = !isAudio && (mUrl.contains('.mp4') ||
        mUrl.contains('.mov') ||
        mUrl.contains('.webm') ||
        mUrl.contains('video/'));

    final mediaType = isAudio
        ? 'audio'
        : isVideo
            ? 'video'
            : 'photo';

    String? resolvedVoiceUrl;
    if (isAudio) {
      resolvedVoiceUrl = (thumb != null && thumb.isNotEmpty) ? thumb : mUrl;
    } else if (thumb != null && (thumb.startsWith('http') || thumb.startsWith('data:audio') || thumb.contains('.m4a') || thumb.contains('.mp3'))) {
      resolvedVoiceUrl = thumb;
    }

    return MemoryItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ??
          (isAudio
              ? 'Voice Whisper'
              : isVideo
                  ? 'Video Moment'
                  : 'Photo Moment'),
      caption: json['caption']?.toString() ?? '',
      mediaUrl: isAudio ? '' : mUrl,
      voiceUrl: resolvedVoiceUrl,
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
