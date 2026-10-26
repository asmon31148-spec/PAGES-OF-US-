class VaultItem {
  final String id;
  final String creatorId;
  final String creatorName;
  final String title;
  final String? coverImageUrl;
  final String emblemShape; // 'circle', 'arch', 'diamond', 'square'
  final int colorValue;
  final DateTime? specialDate;
  final String accessMode; // 'open', 'timer', 'pin'
  final String? pinCode;
  final String? videoUrl;
  final List<String> photoUrls;
  final String letter;
  final String? voiceNoteUrl;
  final int? voiceNoteDurationSeconds;
  final String? backgroundSong; // Audio asset or remote stream
  final DateTime createdAt;

  VaultItem({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    this.coverImageUrl,
    this.emblemShape = 'circle',
    this.colorValue = 0xFF721D38,
    this.specialDate,
    this.accessMode = 'open',
    this.pinCode,
    this.videoUrl,
    this.photoUrls = const [],
    this.letter = '',
    this.voiceNoteUrl,
    this.voiceNoteDurationSeconds,
    this.backgroundSong,
    required this.createdAt,
  });

  bool isLockedFor(String currentUserId, Set<String> unlockedSessionIds) {
    // Creator can ALWAYS access their own vault
    if (creatorId.isEmpty || creatorId == currentUserId) return false;

    // If unlocked during this app session
    if (unlockedSessionIds.contains(id)) return false;

    if (accessMode == 'open') return false;

    if (accessMode == 'timer') {
      if (specialDate == null) return false;
      return DateTime.now().isBefore(specialDate!);
    }

    if (accessMode == 'pin') {
      return pinCode != null && pinCode!.isNotEmpty;
    }

    return false;
  }

  int get daysRemaining {
    if (specialDate == null) return 0;
    final diff = specialDate!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  int get totalMemoriesCount {
    int count = photoUrls.length;
    if (videoUrl != null && videoUrl!.isNotEmpty) count++;
    if (voiceNoteUrl != null && voiceNoteUrl!.isNotEmpty) count++;
    if (letter.isNotEmpty) count++;
    return count > 0 ? count : 1;
  }

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      creatorId: json['creatorId']?.toString() ?? '',
      creatorName: json['creatorName']?.toString() ?? 'Partner',
      title: json['title']?.toString() ?? 'Our Vault',
      coverImageUrl: json['coverImageUrl']?.toString(),
      emblemShape: json['emblemShape']?.toString() ?? 'circle',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF721D38,
      specialDate: json['specialDate'] != null ? DateTime.tryParse(json['specialDate'].toString()) : null,
      accessMode: json['accessMode']?.toString() ?? 'open',
      pinCode: json['pinCode']?.toString(),
      videoUrl: json['videoUrl']?.toString(),
      photoUrls: json['photoUrls'] != null ? List<String>.from(json['photoUrls']) : [],
      letter: json['letter']?.toString() ?? (json['personalNote']?.toString() ?? ''),
      voiceNoteUrl: json['voiceNoteUrl']?.toString(),
      voiceNoteDurationSeconds: (json['voiceNoteDurationSeconds'] as num?)?.toInt(),
      backgroundSong: json['backgroundSong']?.toString() ?? json['ambientTrack']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'title': title,
      'coverImageUrl': coverImageUrl,
      'emblemShape': emblemShape,
      'colorValue': colorValue,
      'specialDate': specialDate?.toIso8601String(),
      'accessMode': accessMode,
      'pinCode': pinCode,
      'videoUrl': videoUrl,
      'photoUrls': photoUrls,
      'letter': letter,
      'voiceNoteUrl': voiceNoteUrl,
      'voiceNoteDurationSeconds': voiceNoteDurationSeconds,
      'backgroundSong': backgroundSong,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  VaultItem copyWith({
    String? id,
    String? creatorId,
    String? creatorName,
    String? title,
    String? coverImageUrl,
    String? emblemShape,
    int? colorValue,
    DateTime? specialDate,
    String? accessMode,
    String? pinCode,
    String? videoUrl,
    List<String>? photoUrls,
    String? letter,
    String? voiceNoteUrl,
    int? voiceNoteDurationSeconds,
    String? backgroundSong,
    DateTime? createdAt,
  }) {
    return VaultItem(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      title: title ?? this.title,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      emblemShape: emblemShape ?? this.emblemShape,
      colorValue: colorValue ?? this.colorValue,
      specialDate: specialDate ?? this.specialDate,
      accessMode: accessMode ?? this.accessMode,
      pinCode: pinCode ?? this.pinCode,
      videoUrl: videoUrl ?? this.videoUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      letter: letter ?? this.letter,
      voiceNoteUrl: voiceNoteUrl ?? this.voiceNoteUrl,
      voiceNoteDurationSeconds: voiceNoteDurationSeconds ?? this.voiceNoteDurationSeconds,
      backgroundSong: backgroundSong ?? this.backgroundSong,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
