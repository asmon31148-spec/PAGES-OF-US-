class DailyCareItem {
  final String id;
  final String title;
  final String icon;
  final String scheduledTime; // e.g. "08:30 AM", "01:00 PM"
  final String timeSlot; // 'morning' | 'afternoon' | 'evening' | 'night'
  final String caringNote; // e.g. "Don't forget your vitamins love! ❤️"
  final String targetUserId; // Who this care checkup is for (partner's ID or user's ID)
  final String? targetUserName;
  final String createdById;
  final String createdByName;
  final bool isCompletedToday;
  final String? completedAt; // ISO timestamp
  final String? completedDateKey; // e.g. "2026-10-28" for daily reset
  final String? completedByName;
  final int reminderNudgeCount;
  final String? lastNudgedAt;

  DailyCareItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.scheduledTime,
    required this.timeSlot,
    this.caringNote = '',
    required this.targetUserId,
    this.targetUserName,
    required this.createdById,
    required this.createdByName,
    this.isCompletedToday = false,
    this.completedAt,
    this.completedDateKey,
    this.completedByName,
    this.reminderNudgeCount = 0,
    this.lastNudgedAt,
  });

  /// Check whether this item was completed today based on local date
  bool isCompletedForDate(String todayKey) {
    return isCompletedToday && completedDateKey == todayKey;
  }

  factory DailyCareItem.fromJson(Map<String, dynamic> json) {
    final todayKey = DateTime.now().toIso8601String().split('T')[0];
    final dateKey = json['completedDateKey']?.toString();
    final rawCompleted = json['isCompletedToday'] == true;

    // Reset completion flag if completed date is not today
    final isActuallyCompletedToday = rawCompleted && (dateKey == todayKey);

    return DailyCareItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '💖',
      scheduledTime: json['scheduledTime']?.toString() ?? '09:00 AM',
      timeSlot: json['timeSlot']?.toString() ?? 'morning',
      caringNote: json['caringNote']?.toString() ?? '',
      targetUserId: json['targetUserId']?.toString() ?? '',
      targetUserName: json['targetUserName']?.toString(),
      createdById: json['createdById']?.toString() ?? '',
      createdByName: json['createdByName']?.toString() ?? 'Partner',
      isCompletedToday: isActuallyCompletedToday,
      completedAt: isActuallyCompletedToday ? json['completedAt']?.toString() : null,
      completedDateKey: dateKey,
      completedByName: isActuallyCompletedToday ? json['completedByName']?.toString() : null,
      reminderNudgeCount: (json['reminderNudgeCount'] as num?)?.toInt() ?? 0,
      lastNudgedAt: json['lastNudgedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'icon': icon,
      'scheduledTime': scheduledTime,
      'timeSlot': timeSlot,
      'caringNote': caringNote,
      'targetUserId': targetUserId,
      'targetUserName': targetUserName,
      'createdById': createdById,
      'createdByName': createdByName,
      'isCompletedToday': isCompletedToday,
      'completedAt': completedAt,
      'completedDateKey': completedDateKey,
      'completedByName': completedByName,
      'reminderNudgeCount': reminderNudgeCount,
      'lastNudgedAt': lastNudgedAt,
    };
  }

  DailyCareItem copyWith({
    String? id,
    String? title,
    String? icon,
    String? scheduledTime,
    String? timeSlot,
    String? caringNote,
    String? targetUserId,
    String? targetUserName,
    String? createdById,
    String? createdByName,
    bool? isCompletedToday,
    String? completedAt,
    String? completedDateKey,
    String? completedByName,
    int? reminderNudgeCount,
    String? lastNudgedAt,
  }) {
    return DailyCareItem(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      timeSlot: timeSlot ?? this.timeSlot,
      caringNote: caringNote ?? this.caringNote,
      targetUserId: targetUserId ?? this.targetUserId,
      targetUserName: targetUserName ?? this.targetUserName,
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      completedAt: completedAt ?? this.completedAt,
      completedDateKey: completedDateKey ?? this.completedDateKey,
      completedByName: completedByName ?? this.completedByName,
      reminderNudgeCount: reminderNudgeCount ?? this.reminderNudgeCount,
      lastNudgedAt: lastNudgedAt ?? this.lastNudgedAt,
    );
  }
}
