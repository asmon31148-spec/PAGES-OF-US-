/// Enforces strict single-owner item ownership and pairing visibility rules:
/// 1. Every item has one immutable ownerId set at creation from the real logged-in user.
/// 2. Unpaired users see ONLY items where isOwner == true.
/// 3. Paired partners see their own items PLUS their active partner's items (shared read, never merged/copied).
/// 4. Disconnecting hides all partner items cleanly while keeping owner items intact.
/// 5. Only the item owner can delete their own item.
class OwnershipHelper {
  OwnershipHelper._();

  static String extractRawDisplayName(String? raw) {
    final clean = raw?.trim() ?? '';
    if (clean.isEmpty) return '';
    if (clean.contains(':::')) {
      return clean.split(':::').first.trim();
    }
    return clean;
  }

  /// Dynamically infers legacy prior UIDs owned by the active user or partner
  /// from historical compound tokens (`Nickname:::LegacyUid`) inside the same
  /// space, without hardcoding any user IDs or names in code.
  static void collectLegacyUidAliases(
    Iterable<Map<String, dynamic>> rows, {
    required String myUid,
    String? myNickname,
    String? partnerUid,
    String? partnerNickname,
    String? activeSpaceId,
    required Set<String> myLegacyUids,
    required Set<String> partnerLegacyUids,
  }) {
    final cleanMyUid = myUid.trim();
    final cleanPartnerUid = (partnerUid ?? '').trim();
    final normMyName = (myNickname ?? '').trim().toLowerCase();
    final normPartnerName = (partnerNickname ?? '').trim().toLowerCase();
    final cleanActiveSpace = (activeSpaceId ?? '').trim();

    for (final row in rows) {
      final rawAuthor = (row['author'] ?? row['author_id'] ?? row['creatorId'])?.toString().trim() ?? '';
      if (!rawAuthor.contains(':::')) continue;
      final parts = rawAuthor.split(':::');
      if (parts.length < 2) continue;
      final prefix = parts.first.trim().toLowerCase();
      final uidPart = parts.last.trim();
      if (uidPart.isEmpty || uidPart == cleanMyUid || uidPart == cleanPartnerUid) continue;

      final rowSpace = (row['space_id'] ?? '').toString().trim();
      final sameSpace = cleanActiveSpace.isEmpty || rowSpace.isEmpty || rowSpace == cleanActiveSpace;

      if (normMyName.isNotEmpty && prefix == normMyName) {
        myLegacyUids.add(uidPart);
      } else if (normPartnerName.isNotEmpty && cleanPartnerUid.isNotEmpty && sameSpace && prefix == normPartnerName) {
        partnerLegacyUids.add(uidPart);
      }
    }
  }

  static bool isOwner({
    String? ownerUid,
    String? ownerId,
    String? legacyAuthor,
    String? myUid,
    String? currentUserId,
    String? myNickname,
    Set<String> myLegacyUids = const {},
    String? partnerUid,
    String? activeSpaceId,
    String? itemSpaceId,
  }) {
    final uid = (currentUserId ?? myUid ?? '').trim();
    if (uid.isEmpty) return false;
    final cleanPartner = (partnerUid ?? '').trim();
    final raw = (ownerId ?? ownerUid ?? legacyAuthor ?? '').trim();
    if (raw.isEmpty) return false;

    final extractedUid = extractOwnerUid(ownerId ?? ownerUid, legacyAuthor: legacyAuthor);
    if (extractedUid == uid || (myLegacyUids.isNotEmpty && myLegacyUids.contains(extractedUid))) {
      return true;
    }
    if (cleanPartner.isNotEmpty && extractedUid == cleanPartner) {
      return false;
    }

    // Legacy alias fallback for historical rows written before current Firebase UID
    final normMe = (myNickname ?? '').trim().toLowerCase();
    if (normMe.isNotEmpty) {
      if (raw.contains(':::')) {
        final prefix = extractRawDisplayName(raw).toLowerCase();
        if (prefix == normMe) {
          return true;
        }
      } else {
        final sameSpace = activeSpaceId == null ||
            activeSpaceId.isEmpty ||
            itemSpaceId == null ||
            itemSpaceId.isEmpty ||
            itemSpaceId == activeSpaceId;
        if (sameSpace && raw.toLowerCase() == normMe) {
          return true;
        }
      }
    }
    return false;
  }

  static bool isOwnedByPartner({
    String? ownerUid,
    String? ownerId,
    String? legacyAuthor,
    String? partnerUid,
    String? partnerId,
    String? partnerNickname,
    Set<String> partnerLegacyUids = const {},
    String? myUid,
    String? activeSpaceId,
    String? itemSpaceId,
  }) {
    final pid = (partnerId ?? partnerUid ?? '').trim();
    if (pid.isEmpty) return false;
    final cleanMyUid = (myUid ?? '').trim();
    final raw = (ownerId ?? ownerUid ?? legacyAuthor ?? '').trim();
    if (raw.isEmpty) return false;

    final extractedUid = extractOwnerUid(ownerId ?? ownerUid, legacyAuthor: legacyAuthor);
    if (extractedUid == pid || (partnerLegacyUids.isNotEmpty && partnerLegacyUids.contains(extractedUid))) {
      return true;
    }
    if (cleanMyUid.isNotEmpty && extractedUid == cleanMyUid) {
      return false;
    }

    final normPartner = (partnerNickname ?? '').trim().toLowerCase();
    if (normPartner.isNotEmpty) {
      final sameSpace = activeSpaceId == null ||
          activeSpaceId.isEmpty ||
          itemSpaceId == null ||
          itemSpaceId.isEmpty ||
          itemSpaceId == activeSpaceId;
      if (raw.contains(':::')) {
        final prefix = extractRawDisplayName(raw).toLowerCase();
        if (sameSpace && prefix == normPartner) {
          return true;
        }
      } else if (sameSpace && raw.toLowerCase() == normPartner) {
        return true;
      }
    }
    return false;
  }

  static bool canViewItem({
    String? ownerUid,
    String? ownerId,
    String? legacyAuthor,
    String? myUid,
    String? currentUserId,
    String? myNickname,
    Set<String> myLegacyUids = const {},
    String? partnerUid,
    String? partnerId,
    String? partnerNickname,
    Set<String> partnerLegacyUids = const {},
    String? activeSpaceId,
    String? itemSpaceId,
  }) {
    if (isOwner(
      ownerUid: ownerUid,
      ownerId: ownerId,
      legacyAuthor: legacyAuthor,
      myUid: myUid,
      currentUserId: currentUserId,
      myNickname: myNickname,
      myLegacyUids: myLegacyUids,
      partnerUid: partnerId ?? partnerUid,
      activeSpaceId: activeSpaceId,
      itemSpaceId: itemSpaceId,
    )) {
      return true;
    }
    return isOwnedByPartner(
      ownerUid: ownerUid,
      ownerId: ownerId,
      legacyAuthor: legacyAuthor,
      partnerUid: partnerUid,
      partnerId: partnerId,
      partnerNickname: partnerNickname,
      partnerLegacyUids: partnerLegacyUids,
      myUid: currentUserId ?? myUid,
      activeSpaceId: activeSpaceId,
      itemSpaceId: itemSpaceId,
    );
  }

  static bool canDeleteItem({
    String? ownerUid,
    String? ownerId,
    String? legacyAuthor,
    String? myUid,
    String? currentUserId,
    String? myNickname,
    Set<String> myLegacyUids = const {},
    String? partnerUid,
    String? activeSpaceId,
    String? itemSpaceId,
  }) {
    return isOwner(
      ownerUid: ownerUid,
      ownerId: ownerId,
      legacyAuthor: legacyAuthor,
      myUid: myUid,
      currentUserId: currentUserId,
      myNickname: myNickname,
      myLegacyUids: myLegacyUids,
      partnerUid: partnerUid,
      activeSpaceId: activeSpaceId,
      itemSpaceId: itemSpaceId,
    );
  }

  static String extractOwnerUid(
    String? raw, {
    String? ownerId,
    String? legacyAuthor,
  }) {
    final cleanRaw = raw?.trim() ?? '';
    final cleanOwner = (ownerId ?? cleanRaw).trim();
    if (cleanOwner.isNotEmpty && !cleanOwner.contains(':::')) {
      return cleanOwner;
    }
    final src = cleanOwner.isNotEmpty ? cleanOwner : (legacyAuthor?.trim() ?? '');
    if (src.contains(':::')) {
      return src.split(':::').last.trim();
    }
    return src;
  }
}
