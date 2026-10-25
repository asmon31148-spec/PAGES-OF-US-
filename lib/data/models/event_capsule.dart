class EventCapsule {
  final String id;
  final String creatorId;
  final String creatorName;
  final String title;
  final String eventType; // 'birthday', 'anniversary', 'trip', 'special'
  final String passcode; // 6-digit PIN
  final String? passcodeHint;
  final DateTime? unlockAt; // Time-lock countdown
  final String? videoUrl;
  final List<String> photoUrls;
  final String personalNote;
  final String? scratchSecret; // Scratch-to-reveal gift/promise
  final String? voiceNoteUrl;
  final String? ambientTrack; // Capsule-exclusive soundtrack
  final DateTime createdAt;

  EventCapsule({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    this.eventType = 'special',
    required this.passcode,
    this.passcodeHint,
    this.unlockAt,
    this.videoUrl,
    this.photoUrls = const [],
    required this.personalNote,
    this.scratchSecret,
    this.voiceNoteUrl,
    this.ambientTrack = 'lofi_sanctuary',
    required this.createdAt,
  });

  bool get isTimeLocked =>
      unlockAt != null && DateTime.now().isBefore(unlockAt!);

  Duration get timeRemaining =>
      unlockAt != null && isTimeLocked
          ? unlockAt!.difference(DateTime.now())
          : Duration.zero;

  factory EventCapsule.fromJson(Map<String, dynamic> json) {
    return EventCapsule(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      creatorId: json['creatorId']?.toString() ?? '',
      creatorName: json['creatorName']?.toString() ?? 'Partner',
      title: json['title']?.toString() ?? 'Just for us',
      eventType: json['eventType']?.toString() ?? 'special',
      passcode: json['passcode']?.toString() ?? '251200',
      passcodeHint: json['passcodeHint']?.toString(),
      unlockAt: json['unlockAt'] != null
          ? DateTime.tryParse(json['unlockAt'].toString())
          : null,
      videoUrl: json['videoUrl']?.toString(),
      photoUrls: json['photoUrls'] != null
          ? List<String>.from(json['photoUrls'])
          : [],
      personalNote: json['personalNote']?.toString() ??
          '“No matter how many places we go, this is still my favorite view.”',
      scratchSecret: json['scratchSecret']?.toString(),
      voiceNoteUrl: json['voiceNoteUrl']?.toString(),
      ambientTrack: json['ambientTrack']?.toString() ?? 'lofi_sanctuary',
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
      'eventType': eventType,
      'passcode': passcode,
      'passcodeHint': passcodeHint,
      'unlockAt': unlockAt?.toIso8601String(),
      'videoUrl': videoUrl,
      'photoUrls': photoUrls,
      'personalNote': personalNote,
      'scratchSecret': scratchSecret,
      'voiceNoteUrl': voiceNoteUrl,
      'ambientTrack': ambientTrack,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  EventCapsule copyWith({
    String? id,
    String? creatorId,
    String? creatorName,
    String? title,
    String? eventType,
    String? passcode,
    String? passcodeHint,
    DateTime? unlockAt,
    String? videoUrl,
    List<String>? photoUrls,
    String? personalNote,
    String? scratchSecret,
    String? voiceNoteUrl,
    String? ambientTrack,
    DateTime? createdAt,
  }) {
    return EventCapsule(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      title: title ?? this.title,
      eventType: eventType ?? this.eventType,
      passcode: passcode ?? this.passcode,
      passcodeHint: passcodeHint ?? this.passcodeHint,
      unlockAt: unlockAt ?? this.unlockAt,
      videoUrl: videoUrl ?? this.videoUrl,
      photoUrls: photoUrls ?? this.photoUrls,
      personalNote: personalNote ?? this.personalNote,
      scratchSecret: scratchSecret ?? this.scratchSecret,
      voiceNoteUrl: voiceNoteUrl ?? this.voiceNoteUrl,
      ambientTrack: ambientTrack ?? this.ambientTrack,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
