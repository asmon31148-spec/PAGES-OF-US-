/// Dark-romance one-time "Burn After Reading" Secret Whisper synced via Supabase app_content.
class SecretWhisper {
  final String id;
  final String senderId;
  final String senderNickname;
  final String text;
  final String createdAt;
  final bool isBurned;
  final String? burnedAt;
  final String? burnedById;

  const SecretWhisper({
    required this.id,
    required this.senderId,
    required this.senderNickname,
    required this.text,
    required this.createdAt,
    this.isBurned = false,
    this.burnedAt,
    this.burnedById,
  });

  factory SecretWhisper.fromJson(Map<String, dynamic> json) {
    return SecretWhisper(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderNickname: json['senderNickname']?.toString() ?? 'Partner',
      text: json['text']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      isBurned: json['isBurned'] == true,
      burnedAt: json['burnedAt']?.toString(),
      burnedById: json['burnedById']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderNickname': senderNickname,
        'text': text,
        'createdAt': createdAt,
        'isBurned': isBurned,
        if (burnedAt != null) 'burnedAt': burnedAt,
        if (burnedById != null) 'burnedById': burnedById,
      };

  SecretWhisper burn(String readerId) => SecretWhisper(
        id: id,
        senderId: senderId,
        senderNickname: senderNickname,
        text: '', // Wipe plaintext once read & sealed
        createdAt: createdAt,
        isBurned: true,
        burnedAt: DateTime.now().toUtc().toIso8601String(),
        burnedById: readerId,
      );
}
