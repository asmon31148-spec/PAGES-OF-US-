/// Resolves canonical authorship (`isMine`, display name, and author token)
/// across Memories, Letters, and Timeline Milestones without mixing partners
/// even when legacy rows store nickname-only authors or earlier UIDs.
class AuthorIdentity {
  final bool isMine;
  final String displayName;
  final String rawAuthor;

  const AuthorIdentity({
    required this.isMine,
    required this.displayName,
    required this.rawAuthor,
  });

  static final RegExp _rawUidPattern = RegExp(r'^[A-Za-z0-9_-]{20,}$');

  /// Canonical compound author token saved for newly created items.
  static String formatAuthorToken({
    required String userId,
    String? userNickname,
  }) {
    final cleanId = userId.trim();
    final cleanName = userNickname?.trim() ?? '';
    if (cleanName.isNotEmpty && cleanId.isNotEmpty && !cleanId.contains(':::')) {
      return '$cleanName:::$cleanId';
    }
    return cleanId;
  }

  /// Extracts a human-readable nickname prefix if present in an author field.
  static String extractEmbeddedName(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    if (trimmed.contains(':::')) {
      return trimmed.split(':::').first.trim();
    }
    if (!_rawUidPattern.hasMatch(trimmed)) {
      return trimmed;
    }
    return '';
  }

  /// Resolves strict, deterministic ownership across `author` and `author_id`.
  static AuthorIdentity resolve({
    String? rawAuthor,
    String? rawAuthorId,
    String? currentUserId,
    String? currentUserNickname,
    String? partnerId,
    String? partnerNickname,
    bool explicitIsMine = false,
  }) {
    final a = rawAuthor?.trim() ?? '';
    final aid = rawAuthorId?.trim() ?? '';
    final effectiveRaw = a.isNotEmpty ? a : aid;

    final uid = currentUserId?.trim() ?? '';
    final myNick = currentUserNickname?.trim() ?? '';
    final pid = partnerId?.trim() ?? '';
    final pNick = partnerNickname?.trim() ?? '';

    final embeddedA = extractEmbeddedName(a);
    final embeddedAid = extractEmbeddedName(aid);
    final embeddedName = embeddedA.isNotEmpty ? embeddedA : embeddedAid;

    // 1. Definitive partner UID check first so partner items are never claimed as mine.
    if (pid.isNotEmpty && (a.contains(pid) || aid.contains(pid))) {
      final partnerLabel = pNick.isNotEmpty
          ? pNick
          : (embeddedName.isNotEmpty ? embeddedName : 'Partner');
      return AuthorIdentity(
        isMine: false,
        displayName: partnerLabel,
        rawAuthor: effectiveRaw,
      );
    }

    // 2. Definitive current user UID check (checks both `author` and `author_id`).
    if (uid.isNotEmpty && (a.contains(uid) || aid.contains(uid))) {
      return AuthorIdentity(
        isMine: true,
        displayName: 'You',
        rawAuthor: effectiveRaw,
      );
    }

    // 3. Nickname match for legacy rows saved without a UID or under a prior UID.
    if (embeddedName.isNotEmpty) {
      final lowerEmbedded = embeddedName.toLowerCase();
      final matchesPartnerNick =
          pNick.isNotEmpty && lowerEmbedded == pNick.toLowerCase();
      final matchesMyNick =
          myNick.isNotEmpty && lowerEmbedded == myNick.toLowerCase();

      if (matchesMyNick && !matchesPartnerNick) {
        return AuthorIdentity(
          isMine: true,
          displayName: 'You',
          rawAuthor: effectiveRaw,
        );
      }
      if (matchesPartnerNick && !matchesMyNick) {
        return AuthorIdentity(
          isMine: false,
          displayName: pNick,
          rawAuthor: effectiveRaw,
        );
      }
      return AuthorIdentity(
        isMine: explicitIsMine,
        displayName: explicitIsMine ? 'You' : embeddedName,
        rawAuthor: effectiveRaw,
      );
    }

    // 4. Final fallback when only explicit flag or raw ID exists.
    return AuthorIdentity(
      isMine: explicitIsMine,
      displayName: explicitIsMine
          ? 'You'
          : (pNick.isNotEmpty ? pNick : 'Partner'),
      rawAuthor: effectiveRaw,
    );
  }
}
