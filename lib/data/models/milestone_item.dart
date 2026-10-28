class MilestoneItem {
  final String id;
  final String title;
  final String date;
  final String rawDate;
  final String story;
  final String addedBy;
  final String? authorId;
  final bool isMine;
  final String? imageUrl;
  final String? audioUrl;
  final int? audioDuration;

  MilestoneItem({
    required this.id,
    required this.title,
    required this.date,
    required this.rawDate,
    required this.story,
    required this.addedBy,
    this.authorId,
    required this.isMine,
    this.imageUrl,
    this.audioUrl,
    this.audioDuration,
  });

  /// Formatted date string in strict DD/MM/YYYY format as requested by user
  String get formattedDisplayDate {
    try {
      final dt = DateTime.parse(rawDate);
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      return '$dd/$mm/$yyyy';
    } catch (_) {
      final parts = rawDate.split('-');
      if (parts.length >= 3) {
        final yyyy = parts[0];
        final mm = parts[1].padLeft(2, '0');
        final dd = parts[2].split('T')[0].padLeft(2, '0');
        return '$dd/$mm/$yyyy';
      }
      return rawDate;
    }
  }

  /// Date is primary title if no custom title is provided
  String get displayTitle {
    if (title.trim().isNotEmpty) {
      return title.trim();
    }
    return formattedDisplayDate;
  }

  int get year {
    try {
      return DateTime.parse(rawDate).year;
    } catch (_) {
      final match = RegExp(r'^(\d{4})').firstMatch(rawDate);
      if (match != null) {
        return int.tryParse(match.group(1)!) ?? DateTime.now().year;
      }
      return DateTime.now().year;
    }
  }

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;
  bool get hasAudio => audioUrl != null && audioUrl!.trim().isNotEmpty;

  String get relativeTime {
    try {
      final dt = DateTime.parse(rawDate);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0 && dt.day == now.day) {
        return 'Today';
      } else if (diff.inDays == 1 || (diff.inDays == 0 && dt.day == now.day - 1)) {
        return 'Yesterday';
      } else if (diff.inDays > 1 && diff.inDays < 30) {
        return '${diff.inDays} days ago';
      } else if (diff.inDays >= 30 && diff.inDays < 365) {
        final months = (diff.inDays / 30).floor();
        return '$months ${months == 1 ? "month" : "months"} ago';
      } else if (diff.inDays >= 365) {
        final years = (diff.inDays / 365).floor();
        return '$years ${years == 1 ? "year" : "years"} ago';
      }
    } catch (_) {}
    return '';
  }

  factory MilestoneItem.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
    String? partnerNickname,
  }) {
    final authorStr = json['author_id']?.toString() ?? json['author']?.toString() ?? '';
    final isMine = currentUserId != null &&
        (authorStr == currentUserId ||
         (authorStr.isNotEmpty && authorStr.contains(currentUserId)) ||
         json['is_mine'] == true);
    final authorName = isMine ? 'You' : (partnerNickname ?? 'Partner');

    final raw = json['event_date']?.toString() ??
        json['date']?.toString() ??
        json['created_at']?.toString() ??
        DateTime.now().toIso8601String().split('T')[0];

    return MilestoneItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      date: raw,
      rawDate: raw,
      story: json['story']?.toString() ?? json['description']?.toString() ?? '',
      addedBy: authorName,
      authorId: authorStr,
      isMine: isMine,
      imageUrl: json['image_url']?.toString() ?? json['imageUrl']?.toString(),
      audioUrl: json['audio_url']?.toString() ?? json['audioUrl']?.toString(),
      audioDuration: json['audio_duration'] is int
          ? json['audio_duration']
          : int.tryParse(json['audio_duration']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson({required String spaceId, required String author}) {
    return {
      'id': id,
      'space_id': spaceId,
      'title': title,
      'event_date': rawDate,
      'date': rawDate,
      'story': story,
      'author': author,
      'author_id': author,
      'image_url': imageUrl,
      'imageUrl': imageUrl,
      'audio_url': audioUrl,
      'audioUrl': audioUrl,
      'audio_duration': audioDuration,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
