import 'dart:convert';
import '../utils/ownership_helper.dart';
import '../../data/services/firebase_service.dart';
import '../../data/services/supabase_service.dart';
import 'device_status_service.dart';
import 'local_cache_service.dart';
import 'media_upload_service.dart';

/// Persists deleted record tombstones locally across restarts so lagging DB mirrors
/// or stale caches never resurrect permanently deleted items.
class DeletedIdsStore {
  static const String _prefix = 'deleted_tombstones_';

  static Set<String> getIds(String scope) {
    try {
      final raw = LocalCacheService.prefs.getStringList('$_prefix$scope');
      return raw != null ? raw.toSet() : <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> markDeleted(String scope, String id) async {
    if (id.isEmpty) return;
    try {
      final current = getIds(scope).toList();
      if (!current.contains(id)) {
        current.add(id);
        if (current.length > 300) {
          current.removeRange(0, current.length - 300);
        }
        await LocalCacheService.prefs.setStringList('$_prefix$scope', current);
      }
    } catch (_) {}
  }

  static Future<void> unmarkDeleted(String scope, String id) async {
    if (id.isEmpty) return;
    try {
      final current = getIds(scope);
      if (current.remove(id)) {
        await LocalCacheService.prefs.setStringList('$_prefix$scope', current.toList());
      }
    } catch (_) {}
  }
}

class OrphanAuditItem {
  final String table;
  final String id;
  final String title;
  final String ownerRaw;
  final String spaceId;
  final String reason;
  final List<String> mediaUrls;

  const OrphanAuditItem({
    required this.table,
    required this.id,
    required this.title,
    required this.ownerRaw,
    required this.spaceId,
    required this.reason,
    this.mediaUrls = const [],
  });

  Map<String, dynamic> toJson() => {
        'table': table,
        'id': id,
        'title': title,
        'ownerRaw': ownerRaw,
        'spaceId': spaceId,
        'reason': reason,
        'mediaUrls': mediaUrls,
      };
}

/// One-time audit & cleanup helper for legacy/test/orphaned rows across Supabase & Firestore.
/// Always reports found candidates first before deleting.
class OrphanAuditService {
  static final RegExp _testOwnerPattern = RegExp(
    r'^(test|dummy|seed|sample|unknown)$',
    caseSensitive: false,
  );

  static bool looksSuspiciousRow({
    required String? ownerRaw,
    required String? title,
    required String myUid,
    String? partnerUid,
  }) {
    final ownerUid = OwnershipHelper.extractOwnerUid(ownerRaw);
    if (ownerUid.isEmpty) return true;
    if (_testOwnerPattern.hasMatch(ownerUid)) return true;
    if (!OwnershipHelper.canViewItem(
      ownerUid: ownerUid,
      myUid: myUid,
      partnerUid: partnerUid,
    )) {
      return true;
    }
    final cleanTitle = (title ?? '').trim().toLowerCase();
    if (cleanTitle == 'test' || cleanTitle == 'fgh' || cleanTitle == 'bvfd') {
      return true;
    }
    return false;
  }

  static Future<List<OrphanAuditItem>> auditActiveSpace({
    required String spaceId,
    required String myUid,
    String? partnerUid,
  }) async {
    final findings = <OrphanAuditItem>[];
    final client = SupabaseService.client;
    if (client == null || spaceId.isEmpty) return findings;

    Future<void> scanTable(String table, String titleKey) async {
      try {
        final rows = await client
            .from(table)
            .select()
            .eq('space_id', spaceId)
            .limit(250);
        for (final raw in (rows as List)) {
          if (raw is! Map) continue;
          final row = Map<String, dynamic>.from(raw);
          final id = row['id']?.toString() ?? '';
          final ownerRaw = (row['author'] ?? row['author_id'])?.toString() ?? '';
          final title = row[titleKey]?.toString() ?? '(untitled)';
          final ownerUid = OwnershipHelper.extractOwnerUid(ownerRaw);
          if (looksSuspiciousRow(
            ownerRaw: ownerRaw,
            title: title,
            myUid: myUid,
            partnerUid: partnerUid,
          )) {
            final reason = ownerUid.isEmpty
                ? 'Missing ownerId'
                : (_testOwnerPattern.hasMatch(ownerUid)
                    ? 'Legacy test owner "$ownerUid"'
                    : (!OwnershipHelper.canViewItem(
                        ownerUid: ownerUid,
                        myUid: myUid,
                        partnerUid: partnerUid,
                      )
                        ? 'Foreign owner "$ownerUid" in active space'
                        : 'Suspicious test content'));
            final urls = <String>[
              if (row['media_url'] != null && row['media_url'].toString().isNotEmpty)
                row['media_url'].toString(),
              if (row['thumbnail_url'] != null && row['thumbnail_url'].toString().isNotEmpty)
                row['thumbnail_url'].toString(),
              if (row['image_url'] != null && row['image_url'].toString().isNotEmpty)
                row['image_url'].toString(),
              if (row['audio_url'] != null && row['audio_url'].toString().isNotEmpty)
                row['audio_url'].toString(),
            ];
            findings.add(OrphanAuditItem(
              table: table,
              id: id,
              title: title,
              ownerRaw: ownerRaw,
              spaceId: row['space_id']?.toString() ?? spaceId,
              reason: reason,
              mediaUrls: urls,
            ));
          }
        }
      } catch (e) {
        await DeviceStatusService.recordSyncError('orphan_audit_$table', e.toString());
      }
    }

    await Future.wait([
      scanTable('memories', 'title'),
      scanTable('letters', 'title'),
      scanTable('milestones', 'title'),
    ]);

    // Check shared vaults container for foreign/seed items
    try {
      final vaultRes = await client
          .from('app_content')
          .select('content')
          .eq('id', 'vaults_$spaceId')
          .maybeSingle();
      if (vaultRes != null && vaultRes['content'] is List) {
        for (final raw in (vaultRes['content'] as List)) {
          if (raw is! Map) continue;
          final v = Map<String, dynamic>.from(raw);
          final vid = v['id']?.toString() ?? '';
          final ownerRaw = v['creatorId']?.toString() ?? '';
          final title = v['title']?.toString() ?? '';
          if (vid == 'vault_midnight_seed' ||
              looksSuspiciousRow(
                ownerRaw: ownerRaw,
                title: title,
                myUid: myUid,
                partnerUid: partnerUid,
              )) {
            final urls = <String>[
              if (v['coverImageUrl'] != null) v['coverImageUrl'].toString(),
              if (v['videoUrl'] != null) v['videoUrl'].toString(),
              if (v['voiceNoteUrl'] != null) v['voiceNoteUrl'].toString(),
              if (v['photoUrls'] is List) ...(v['photoUrls'] as List).map((e) => e.toString()),
            ];
            findings.add(OrphanAuditItem(
              table: 'app_content_vault',
              id: vid,
              title: title,
              ownerRaw: ownerRaw,
              spaceId: spaceId,
              reason: vid == 'vault_midnight_seed' ? 'Legacy seed vault' : 'Unowned/foreign vault',
              mediaUrls: urls,
            ));
          }
        }
      }
    } catch (e) {
      await DeviceStatusService.recordSyncError('orphan_audit_vaults', e.toString());
    }

    return findings;
  }

  static Future<int> deleteFindings(List<OrphanAuditItem> items) async {
    final client = SupabaseService.client;
    if (client == null) return 0;
    int deleted = 0;

    for (final item in items) {
      try {
        await MediaUploadService.deleteRemoteFiles(item.mediaUrls);
        if (item.table == 'memories' || item.table == 'letters' || item.table == 'milestones') {
          await client.from(item.table).delete().eq('id', item.id);
          await DeletedIdsStore.markDeleted(item.table, item.id);
          if (item.table == 'milestones') {
            try {
              await FirebaseService.firestore
                  .collection('spaces')
                  .doc(item.spaceId)
                  .collection('milestones')
                  .doc(item.id)
                  .delete();
            } catch (_) {}
          }
          deleted++;
        } else if (item.table == 'app_content_vault') {
          await DeletedIdsStore.markDeleted('vaults', item.id);
          final res = await client
              .from('app_content')
              .select('content')
              .eq('id', 'vaults_${item.spaceId}')
              .maybeSingle();
          if (res != null && res['content'] is List) {
            final filtered = (res['content'] as List)
                .where((e) => e is Map && e['id']?.toString() != item.id)
                .toList();
            await client.from('app_content').upsert({
              'id': 'vaults_${item.spaceId}',
              'content': filtered,
              'updated_at': DateTime.now().toIso8601String(),
            });
            deleted++;
          }
        }
      } catch (e) {
        await DeviceStatusService.recordSyncError('orphan_delete_${item.id}', e.toString());
      }
    }

    // Record completion summary timestamp
    try {
      await LocalCacheService.prefs.setString(
        'last_orphan_audit_json',
        jsonEncode({
          'ranAt': DateTime.now().toUtc().toIso8601String(),
          'deletedCount': deleted,
          'items': items.map((e) => e.toJson()).toList(),
        }),
      );
    } catch (_) {}
    return deleted;
  }
}
