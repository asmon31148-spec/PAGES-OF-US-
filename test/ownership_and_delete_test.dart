import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pages_of_us/core/services/deleted_ids_store.dart';
import 'package:pages_of_us/core/services/local_cache_service.dart';
import 'package:pages_of_us/core/services/media_upload_service.dart';
import 'package:pages_of_us/core/utils/ownership_helper.dart';
import 'package:pages_of_us/features/dossier/screens/obsession_dossier_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OwnershipHelper - Strict Solo Ownership & Pairing Visibility', () {
    const alice = 'uid_alice_001';
    const bob = 'uid_bob_002';
    const charlie = 'uid_charlie_003';
    const stranger = 'uid_stranger_999';

    test('extractOwnerUid handles bare UIDs and legacy nickname:::uid strings', () {
      expect(OwnershipHelper.extractOwnerUid(alice), alice);
      expect(OwnershipHelper.extractOwnerUid('Alice:::$alice'), alice);
      expect(OwnershipHelper.extractOwnerUid('   '), '');
      expect(OwnershipHelper.extractOwnerUid(null), '');
    });

    test('solo user sees only own items; partner and third-party items stay hidden', () {
      expect(
        OwnershipHelper.canViewItem(
          ownerUid: alice,
          myUid: alice,
          partnerUid: null,
        ),
        isTrue,
      );
      expect(
        OwnershipHelper.canViewItem(
          ownerUid: bob,
          myUid: alice,
          partnerUid: null,
        ),
        isFalse,
      );
      expect(
        OwnershipHelper.canViewItem(
          ownerUid: bob,
          myUid: alice,
          partnerUid: '',
        ),
        isFalse,
      );
    });

    test('paired users share read visibility while disconnecting hides ex-partner items', () {
      // Paired Alice <-> Bob
      expect(
        OwnershipHelper.canViewItem(
          ownerUid: bob,
          myUid: alice,
          partnerUid: bob,
        ),
        isTrue,
      );
      // Stranger remains hidden even when paired
      expect(
        OwnershipHelper.canViewItem(
          ownerUid: stranger,
          myUid: alice,
          partnerUid: bob,
        ),
        isFalse,
      );

      // Disconnected: Alice's items remain visible, Bob's items disappear
      expect(
        OwnershipHelper.canViewItem(
          ownerUid: alice,
          myUid: alice,
          partnerUid: null,
        ),
        isTrue,
      );
      expect(
        OwnershipHelper.canViewItem(
          ownerUid: bob,
          myUid: alice,
          partnerUid: null,
        ),
        isFalse,
      );

      // Re-paired Alice <-> Charlie: Charlie visible, old partner Bob stays hidden
      expect(
        OwnershipHelper.canViewItem(
          ownerUid: charlie,
          myUid: alice,
          partnerUid: charlie,
        ),
        isTrue,
      );
      expect(
        OwnershipHelper.canViewItem(
          ownerUid: bob,
          myUid: alice,
          partnerUid: charlie,
        ),
        isFalse,
      );
    });

    test('only the item owner can delete an item, never the paired partner', () {
      expect(
        OwnershipHelper.canDeleteItem(ownerUid: alice, myUid: alice),
        isTrue,
      );
      expect(
        OwnershipHelper.canDeleteItem(ownerUid: 'Alice:::$alice', myUid: alice),
        isTrue,
      );
      expect(
        OwnershipHelper.canDeleteItem(ownerUid: alice, myUid: bob),
        isFalse,
      );
      expect(
        OwnershipHelper.canDeleteItem(ownerUid: '', myUid: alice),
        isFalse,
      );
    });
  });

  group('DeletedIdsStore - Tombstone Persistence', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.init();
    });

    test('persists deleted IDs across reloads and supports rollback via unmarkDeleted', () async {
      await DeletedIdsStore.markDeleted('memories', 'mem_123');
      expect(DeletedIdsStore.getIds('memories'), contains('mem_123'));

      // Re-initialize SharedPreferences cache abstraction to verify persistence
      await LocalCacheService.init();
      expect(DeletedIdsStore.getIds('memories'), contains('mem_123'));

      // Rollback tombstone if server delete rejected
      await DeletedIdsStore.unmarkDeleted('memories', 'mem_123');
      expect(DeletedIdsStore.getIds('memories'), isNot(contains('mem_123')));
    });
  });

  group('OrphanAuditService & MediaUploadService - Audit & Remote Deletion Parsing', () {
    test('looksSuspiciousRow flags missing owner, seed owners, test titles, and foreign owners', () {
      const me = 'uid_me_111';
      const partner = 'uid_partner_222';

      // Legitimate rows
      expect(
        OrphanAuditService.looksSuspiciousRow(
          ownerRaw: 'Asmon:::$me',
          title: 'Evening Walk Together',
          myUid: me,
          partnerUid: partner,
        ),
        isFalse,
      );
      expect(
        OrphanAuditService.looksSuspiciousRow(
          ownerRaw: partner,
          title: 'Weekend Letter',
          myUid: me,
          partnerUid: partner,
        ),
        isFalse,
      );

      // Missing / empty owner
      expect(
        OrphanAuditService.looksSuspiciousRow(
          ownerRaw: '',
          title: 'Mystery Row',
          myUid: me,
          partnerUid: partner,
        ),
        isTrue,
      );

      // Legacy hardcoded test owner (non-real handle)
      expect(
        OrphanAuditService.looksSuspiciousRow(
          ownerRaw: 'test',
          title: 'Seed item',
          myUid: me,
          partnerUid: partner,
        ),
        isTrue,
      );
      // Real legacy user handle matching 'asmon' must NOT be auto-classified as dummy seed
      expect(
        OrphanAuditService.looksSuspiciousRow(
          ownerRaw: 'Asmon:::$me',
          title: 'FOR U',
          myUid: me,
          partnerUid: partner,
        ),
        isFalse,
      );

      // Foreign owner outside current couple
      expect(
        OrphanAuditService.looksSuspiciousRow(
          ownerRaw: 'uid_random_ex_999',
          title: 'Old memory',
          myUid: me,
          partnerUid: partner,
        ),
        isTrue,
      );

      // Known throwaway test title
      expect(
        OrphanAuditService.looksSuspiciousRow(
          ownerRaw: me,
          title: 'fgh',
          myUid: me,
          partnerUid: partner,
        ),
        isTrue,
      );
    });

    test('extractSupabaseStoragePath and extractImageKitFileName parse real URLs accurately', () {
      const supaUrl =
          'https://qzycnvpyjrphvxogndjd.supabase.co/storage/v1/object/public/pages-media/memories/photo_1794.jpg';
      expect(
        MediaUploadService.extractSupabaseStoragePath(supaUrl),
        'memories/photo_1794.jpg',
      );
      expect(
        MediaUploadService.extractSupabaseStoragePath('https://example.com/other.png'),
        isNull,
      );

      const ikUrl = 'https://ik.imagekit.io/asmon96/vaults/clip_42.mp4?tr=w-400';
      expect(MediaUploadService.extractImageKitFileName(ikUrl), 'clip_42.mp4');
      expect(
        MediaUploadService.extractImageKitFileName('https://cdn.other.io/clip.mp4'),
        isNull,
      );
    });
  });

  group('Legacy UID Recovery, Isolation & Velvet Dossier Palette', () {
    const newUid = 'uid_current_001';
    const legacyUid = 'uid_previous_001';
    const partnerUid = 'uid_partner_002';
    const thirdPartyUid = 'uid_thirdparty_999';
    const spaceId = 'space_pair_123';

    test('collectLegacyUidAliases recovers prior UID from same-space Nickname:::LegacyUid without cross-account leakage', () {
      final myLegacy = <String>{};
      final partnerLegacy = <String>{};

      OwnershipHelper.collectLegacyUidAliases(
        [
          {'space_id': spaceId, 'author': 'Alice:::$legacyUid'},
          {'space_id': 'space_other_999', 'author': 'OtherUser:::$thirdPartyUid'},
        ],
        myUid: newUid,
        myNickname: 'Alice',
        partnerUid: partnerUid,
        partnerNickname: 'Bob',
        activeSpaceId: spaceId,
        myLegacyUids: myLegacy,
        partnerLegacyUids: partnerLegacy,
      );

      expect(myLegacy, contains(legacyUid));
      expect(myLegacy, isNot(contains(thirdPartyUid)));
      expect(partnerLegacy, isEmpty);

      // Bare prior-UID item now becomes viewable AND deletable by the rightful owner
      expect(
        OwnershipHelper.canViewItem(
          ownerUid: legacyUid,
          myUid: newUid,
          myNickname: 'Alice',
          myLegacyUids: myLegacy,
          partnerUid: null, // works even when solo!
        ),
        isTrue,
      );
      expect(
        OwnershipHelper.canDeleteItem(
          ownerUid: legacyUid,
          myUid: newUid,
          myNickname: 'Alice',
          myLegacyUids: myLegacy,
        ),
        isTrue,
      );

      // Same-space legacy bare handle ('alice') matches case-insensitively
      expect(
        OwnershipHelper.canViewItem(
          ownerUid: 'alice',
          myUid: newUid,
          myNickname: 'Alice',
          activeSpaceId: spaceId,
          itemSpaceId: spaceId,
        ),
        isTrue,
      );

      // Third-party account's row remains strictly hidden
      expect(
        OwnershipHelper.canViewItem(
          ownerUid: thirdPartyUid,
          myUid: newUid,
          myNickname: 'Alice',
          myLegacyUids: myLegacy,
          partnerUid: partnerUid,
          partnerNickname: 'Bob',
          partnerLegacyUids: partnerLegacy,
          activeSpaceId: spaceId,
          itemSpaceId: 'space_other_999',
        ),
        isFalse,
      );
    });

    test('DossierPalette produces genuinely distinct colors when Velvet Noir is ON vs OFF', () {
      final velvetLightBase = DossierPalette.fromBrightness(false, isVelvet: true);
      final lightOff = DossierPalette.fromBrightness(false, isVelvet: false);
      final velvetDarkBase = DossierPalette.fromBrightness(true, isVelvet: true);
      final darkOff = DossierPalette.fromBrightness(true, isVelvet: false);

      expect(velvetLightBase.bg, isNot(equals(lightOff.bg)));
      expect(velvetLightBase.accent, isNot(equals(lightOff.accent)));
      expect(velvetDarkBase.bg, isNot(equals(darkOff.bg)));
      expect(velvetDarkBase.card, isNot(equals(darkOff.card)));
      expect(velvetDarkBase.accent, isNot(equals(darkOff.accent)));
      // Velvet palette stays rich deep obsidian-crimson regardless of light/dark toggle
      expect(velvetLightBase.bg, equals(velvetDarkBase.bg));
    });
  });
}
