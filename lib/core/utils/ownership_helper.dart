/// Enforces strict single-owner item ownership and pairing visibility rules:
/// 1. Every item has one immutable ownerId set at creation from the real logged-in user.
/// 2. Unpaired users see ONLY items where isOwner == true.
/// 3. Paired partners see their own items PLUS their active partner's items (shared read, never merged/copied).
/// 4. Disconnecting hides all partner items cleanly while keeping owner items intact.
/// 5. Only the item owner can delete their own item.
class OwnershipHelper {
  OwnershipHelper._();

  static bool isOwner({
    String? ownerUid,
    String? ownerId,
    String? legacyAuthor,
    String? myUid,
    String? currentUserId,
  }) {
    final uid = (currentUserId ?? myUid ?? '').trim();
    if (uid.isEmpty) return false;
    final cleanOwner = (ownerId ?? ownerUid ?? '').trim();
    if (cleanOwner.isNotEmpty) {
      if (cleanOwner.contains(':::')) {
        return cleanOwner.split(':::').last.trim() == uid;
      }
      return cleanOwner == uid;
    }
    final cleanLegacy = legacyAuthor?.trim() ?? '';
    if (cleanLegacy.contains(':::')) {
      final parts = cleanLegacy.split(':::');
      return parts.length >= 2 && parts[1].trim() == uid;
    }
    return cleanLegacy == uid;
  }

  static bool isOwnedByPartner({
    String? ownerUid,
    String? ownerId,
    String? legacyAuthor,
    String? partnerUid,
    String? partnerId,
  }) {
    final pid = (partnerId ?? partnerUid ?? '').trim();
    if (pid.isEmpty) return false;
    final cleanOwner = (ownerId ?? ownerUid ?? '').trim();
    if (cleanOwner.isNotEmpty) {
      if (cleanOwner.contains(':::')) {
        return cleanOwner.split(':::').last.trim() == pid;
      }
      return cleanOwner == pid;
    }
    final cleanLegacy = legacyAuthor?.trim() ?? '';
    if (cleanLegacy.contains(':::')) {
      final parts = cleanLegacy.split(':::');
      return parts.length >= 2 && parts[1].trim() == pid;
    }
    return cleanLegacy == pid;
  }

  static bool canViewItem({
    String? ownerUid,
    String? ownerId,
    String? legacyAuthor,
    String? myUid,
    String? currentUserId,
    String? partnerUid,
    String? partnerId,
  }) {
    if (isOwner(
      ownerUid: ownerUid,
      ownerId: ownerId,
      legacyAuthor: legacyAuthor,
      myUid: myUid,
      currentUserId: currentUserId,
    )) {
      return true;
    }
    return isOwnedByPartner(
      ownerUid: ownerUid,
      ownerId: ownerId,
      legacyAuthor: legacyAuthor,
      partnerUid: partnerUid,
      partnerId: partnerId,
    );
  }

  static bool canDeleteItem({
    String? ownerUid,
    String? ownerId,
    String? legacyAuthor,
    String? myUid,
    String? currentUserId,
  }) {
    return isOwner(
      ownerUid: ownerUid,
      ownerId: ownerId,
      legacyAuthor: legacyAuthor,
      myUid: myUid,
      currentUserId: currentUserId,
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
