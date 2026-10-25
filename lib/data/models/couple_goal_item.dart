class CoupleGoalItem {
  final String id;
  final String title;
  final String icon;
  final String category; // 'firsts' | 'future'
  final String? completedDate;
  final String? targetDate;
  final String? note;
  final bool isCompleted;
  final String? completedBy;

  CoupleGoalItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.category,
    this.completedDate,
    this.targetDate,
    this.note,
    this.isCompleted = false,
    this.completedBy,
  });

  factory CoupleGoalItem.fromJson(Map<String, dynamic> json) {
    return CoupleGoalItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '✨',
      category: json['category']?.toString() ?? 'future',
      completedDate: json['completedDate']?.toString(),
      targetDate: json['targetDate']?.toString(),
      note: json['note']?.toString(),
      isCompleted: json['isCompleted'] == true,
      completedBy: json['completedBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'icon': icon,
      'category': category,
      'completedDate': completedDate,
      'targetDate': targetDate,
      'note': note,
      'isCompleted': isCompleted,
      'completedBy': completedBy,
    };
  }

  CoupleGoalItem copyWith({
    String? id,
    String? title,
    String? icon,
    String? category,
    String? completedDate,
    String? targetDate,
    String? note,
    bool? isCompleted,
    String? completedBy,
  }) {
    return CoupleGoalItem(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      completedDate: completedDate ?? this.completedDate,
      targetDate: targetDate ?? this.targetDate,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
      completedBy: completedBy ?? this.completedBy,
    );
  }
}
