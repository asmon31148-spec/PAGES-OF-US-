class MilestoneItem {
  final String id;
  final String title;
  final String date;
  final String rawDate;
  final String story;
  final String addedBy;
  final bool isMine;

  MilestoneItem({
    required this.id,
    required this.title,
    required this.date,
    required this.rawDate,
    required this.story,
    required this.addedBy,
    required this.isMine,
  });

  factory MilestoneItem.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
    String? partnerNickname,
  }) {
    final authorStr = json['author']?.toString() ?? '';
    final isMine = currentUserId != null && authorStr.contains(currentUserId);
    final authorName = isMine ? 'You' : (partnerNickname ?? 'Partner');

    final raw = json['event_date']?.toString() ??
        json['created_at']?.toString() ??
        DateTime.now().toIso8601String().split('T')[0];

    return MilestoneItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      date: raw,
      rawDate: raw,
      story: json['story']?.toString() ?? '',
      addedBy: authorName,
      isMine: isMine,
    );
  }

  Map<String, dynamic> toJson({required String spaceId, required String author}) {
    return {
      'id': id,
      'space_id': spaceId,
      'title': title,
      'event_date': rawDate,
      'story': story,
      'author': author,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
