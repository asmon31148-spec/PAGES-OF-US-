import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pages_of_us/core/services/deleted_ids_store.dart';
import 'package:pages_of_us/core/services/local_cache_service.dart';
import 'package:pages_of_us/core/services/media_upload_service.dart';
import 'package:pages_of_us/core/utils/ownership_helper.dart';

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

      // Legacy hardcoded test owner
      expect(
        OrphanAuditService.looksSuspiciousRow(
          ownerRaw: 'asmon',
          title: 'FOR U',
          myUid: me,
          partnerUid: partner,
        ),
        isTrue,
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
}
