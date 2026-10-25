class VaultModel {
  final bool isLocked;
  final String passcode;
  final String title;
  final String subtitle;
  final String? videoUrl;
  final String personalNote;

  VaultModel({
    this.isLocked = true,
    this.passcode = '2512',
    this.title = 'Just for us',
    this.subtitle = 'A moment from the night we promised.',
    this.videoUrl,
    this.personalNote = '“No matter how many places we go, this is still my favorite view.”',
  });

  factory VaultModel.fromJson(Map<String, dynamic> json) {
    return VaultModel(
      isLocked: json['isLocked'] != false,
      passcode: json['passcode']?.toString() ?? '2512',
      title: json['title']?.toString() ?? 'Just for us',
      subtitle: json['subtitle']?.toString() ?? 'A moment from the night we promised.',
      videoUrl: json['videoUrl']?.toString(),
      personalNote: json['personalNote']?.toString() ??
          '“No matter how many places we go, this is still my favorite view.”',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isLocked': isLocked,
      'passcode': passcode,
      'title': title,
      'subtitle': subtitle,
      'videoUrl': videoUrl,
      'personalNote': personalNote,
    };
  }

  VaultModel copyWith({
    bool? isLocked,
    String? passcode,
    String? title,
    String? subtitle,
    String? videoUrl,
    String? personalNote,
  }) {
    return VaultModel(
      isLocked: isLocked ?? this.isLocked,
      passcode: passcode ?? this.passcode,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      videoUrl: videoUrl ?? this.videoUrl,
      personalNote: personalNote ?? this.personalNote,
    );
  }
}
