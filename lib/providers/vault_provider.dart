import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Source;
import '../data/models/vault_item.dart';
import '../data/services/supabase_service.dart';
import '../core/services/deleted_ids_store.dart';
import '../core/services/device_status_service.dart';
import '../core/services/media_upload_service.dart';
import '../core/services/notification_service.dart';
import '../core/utils/ownership_helper.dart';
import 'auth_provider.dart';

class VaultProvider extends ChangeNotifier {
  List<VaultItem> _vaults = [];
  VaultItem? _selectedVault;
  String _activeFilter = 'all'; // 'all', 'mine', 'partner'
  final Set<String> _unlockedVaultIds = {};
  final Set<String> _deletedVaultIds = {};

  final AudioPlayer _vaultAudio = AudioPlayer();
  bool _isAudioPlaying = false;
  String? _currentPlayingTrack;
  StreamSubscription? _vaultSub;
  String? _activeSpaceId;
  String? _currentUserId;
  String? _partnerId;
  String? _partnerNickname;

  VaultProvider() {
    AuthProvider.registerSignOutHook(resetState);
  }

  List<VaultItem> get vaults => List.unmodifiable(_vaults);
  VaultItem? get selectedVault => _selectedVault ?? (_vaults.isNotEmpty ? _vaults.first : null);
  String get activeFilter => _activeFilter;
  Set<String> get unlockedVaultIds => Set.unmodifiable(_unlockedVaultIds);
  bool get isAudioPlaying => _isAudioPlaying;

  bool get shouldTriggerConfetti => false;
  void resetConfettiTrigger() {}

  /// Wipes ALL in-memory state when user logs out.
  /// Called by AuthProvider.signOut() before FirebaseService.signOut().
  void resetState() {
    _vaultSub?.cancel();
    _vaultSub = null;
    _vaults = [];
    _selectedVault = null;
    _activeFilter = 'all';
    _unlockedVaultIds.clear();
    _deletedVaultIds.clear();
    _activeSpaceId = null;
    _currentUserId = null;
    _partnerId = null;
    _partnerNickname = null;
    _isAudioPlaying = false;
    _currentPlayingTrack = null;
    try { _vaultAudio.stop(); } catch (_) {}
    notifyListeners();
  }

  void setFilter(String filter) {
    if (_activeFilter != filter) {
      _activeFilter = filter;
      notifyListeners();
    }
  }

  bool get _isSharedCoupleSpace =>
      (_partnerId != null && _partnerId!.isNotEmpty) ||
      (_activeSpaceId != null && !_activeSpaceId!.startsWith('solo_'));

  bool _isAllowedVault(VaultItem v, String currentUserId, String spaceId) {
    final persistedTombstones = DeletedIdsStore.getIds('vaults');
    if (v.id == 'vault_midnight_seed' ||
        v.title.toLowerCase().trim() == 'the midnight letters' ||
        _deletedVaultIds.contains(v.id) ||
        persistedTombstones.contains(v.id)) {
      return false;
    }
    final ownerUid = OwnershipHelper.extractOwnerUid(v.creatorId);
    return OwnershipHelper.canViewItem(
      ownerUid: ownerUid,
      myUid: currentUserId,
      partnerUid: _partnerId,
    );
  }

  List<VaultItem> getFilteredVaults(String currentUserId) {
    final myVaults = _vaults.where((v) => v.creatorId == currentUserId).toList();
    if (!_isSharedCoupleSpace) {
      return myVaults;
    }
    switch (_activeFilter) {
      case 'mine':
        return myVaults;
      case 'partner':
        return _vaults.where((v) => v.creatorId != currentUserId).toList();
      case 'all':
      default:
        return List<VaultItem>.from(_vaults);
    }
  }

  void selectVault(VaultItem vault) {
    _selectedVault = vault;
    notifyListeners();
  }

  bool isVaultLocked(VaultItem vault, String currentUserId) {
    return vault.isLockedFor(currentUserId, _unlockedVaultIds);
  }

  bool unlockWithPin(VaultItem vault, String pin) {
    if (vault.pinCode != null && vault.pinCode == pin.trim()) {
      _unlockedVaultIds.add(vault.id);
      notifyListeners();
      return true;
    }
    return false;
  }

  void lockVault(String vaultId) {
    _unlockedVaultIds.remove(vaultId);
    stopVaultMusic();
    notifyListeners();
  }

  String? get currentPlayingTrack => _currentPlayingTrack;

  static String getTrackDisplayName(String? track) {
    if (track == null || track.isEmpty || track == 'none') return 'None (Silent)';
    if (track == 'lofi_sanctuary' || track.startsWith('lofi')) return '☕ Lo-fi Sanctuary';
    if (track == 'rain') return '🌧️ Gentle Rain';
    if (track == 'ocean') return '🌊 Ocean Waves';
    if (track == 'breeze') return '🍃 Night Breeze';
    if (track == 'fireplace') return '🔥 Cozy Fireplace';
    if (track == 'birds') return '🐦 Morning Birds';
    if (track.startsWith('http')) return '🎵 Custom Song (Cloud)';
    if (track.startsWith('/') || track.contains(':\\')) {
      final name = track.split(RegExp(r'[\\/]')).last;
      return '🎵 ${name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')}';
    }
    return track;
  }

  // --- Smooth Background Audio Player with Fade-in & Fade-out ---

  Future<void> startVaultMusic(String? track) async {
    if (track == null || track.isEmpty || track == 'none') {
      await stopVaultMusic();
      return;
    }

    if (_isAudioPlaying && _currentPlayingTrack == track) return;

    try {
      await _vaultAudio.stop();
      _currentPlayingTrack = track;
      _isAudioPlaying = true;

      // Start at 0 volume for smooth fade-in
      await _vaultAudio.setVolume(0.0);
      await _vaultAudio.setReleaseMode(ReleaseMode.loop);

      if (track.startsWith('http://') || track.startsWith('https://')) {
        await _vaultAudio.play(UrlSource(track));
      } else if (track.startsWith('/') || track.contains(':\\') || track.startsWith('file://')) {
        final localPath = track.startsWith('file://') ? track.substring(7) : track;
        await _vaultAudio.play(DeviceFileSource(localPath));
      } else if (track == 'lofi_sanctuary' || track.startsWith('lofi')) {
        await _vaultAudio.play(AssetSource('audio/lofi_sanctuary.mp3'));
      } else if (track.startsWith('audio/')) {
        await _vaultAudio.play(AssetSource(track));
      } else {
        await _vaultAudio.play(AssetSource('audio/$track.mp3'));
      }

      // Smooth volume fade in over 600ms
      for (double vol = 0.05; vol <= 0.35; vol += 0.05) {
        await Future.delayed(const Duration(milliseconds: 75));
        if (!_isAudioPlaying) break;
        await _vaultAudio.setVolume(vol);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> stopVaultMusic() async {
    if (!_isAudioPlaying) return;
    try {
      // Smooth fade out over 300ms
      for (double vol = 0.30; vol >= 0.0; vol -= 0.10) {
        await Future.delayed(const Duration(milliseconds: 50));
        await _vaultAudio.setVolume(vol > 0 ? vol : 0.0);
      }
      await _vaultAudio.stop();
      _isAudioPlaying = false;
      _currentPlayingTrack = null;
      notifyListeners();
    } catch (_) {
      _isAudioPlaying = false;
    }
  }

  // --- Real-time Sync & Persistence ---

  Future<void> initVaultSync({
    required String spaceId,
    required String currentUserId,
    String? partnerId,
    String? partnerNickname,
  }) async {
    if (spaceId.isEmpty) return;
    _activeSpaceId = spaceId;
    _currentUserId = currentUserId;
    _partnerId = partnerId;
    _partnerNickname = partnerNickname;

    // 0. Register Supabase Realtime Listener (0-50ms peer updates)
    SupabaseService.removeVaultListener(_handleSupabaseVaultsUpdate);
    SupabaseService.addVaultListener(_handleSupabaseVaultsUpdate);

    final vaultDocId = 'vaults_$spaceId';
    final Map<String, VaultItem> mergedMap = {};

    // 1. Supabase fetches: User-centric permanent vaults + Shared Space vaults
    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        // a) Fetch each user's own anchored vaults (guarantees their personal vaults are never lost!)
        if (currentUserId.isNotEmpty) {
          final userRes = await supabase
              .from('app_content')
              .select('content')
              .eq('id', 'user_vaults_$currentUserId')
              .maybeSingle()
              .timeout(const Duration(seconds: 12));
          if (userRes != null && userRes['content'] is List) {
            for (final e in (userRes['content'] as List)) {
              if (e is Map) {
                final v = VaultItem.fromJson(Map<String, dynamic>.from(e));
                mergedMap[v.id] = v;
              }
            }
          }
        }

        // b) If paired, fetch partner's anchored vaults!
        if (partnerId != null && partnerId.isNotEmpty) {
          final partnerRes = await supabase
              .from('app_content')
              .select('content')
              .eq('id', 'user_vaults_$partnerId')
              .maybeSingle()
              .timeout(const Duration(seconds: 12));
          if (partnerRes != null && partnerRes['content'] is List) {
            for (final e in (partnerRes['content'] as List)) {
              if (e is Map) {
                final v = VaultItem.fromJson(Map<String, dynamic>.from(e));
                mergedMap[v.id] = v;
              }
            }
          }
        }

        // c) Fetch shared space vaults
        var res = await supabase
            .from('app_content')
            .select('content')
            .eq('id', vaultDocId)
            .maybeSingle()
            .timeout(const Duration(seconds: 12));

        if (res == null || res['content'] == null) {
          res = await supabase
              .from('app_content')
              .select('content')
              .eq('id', 'vault_capsules_$spaceId')
              .maybeSingle()
              .timeout(const Duration(seconds: 12));
        }

        if (res != null && res['content'] != null && res['content'] is List) {
          for (final e in (res['content'] as List)) {
            if (e is Map) {
              final v = VaultItem.fromJson(Map<String, dynamic>.from(e));
              mergedMap[v.id] = v;
            }
          }
        }
      }
    } catch (_) {}

    var loaded = mergedMap.values
        .where((v) => _isAllowedVault(v, currentUserId, spaceId))
        .toList();

    _vaults = loaded;
    if (_selectedVault == null || !_vaults.any((v) => v.id == _selectedVault!.id)) {
      _selectedVault = _vaults.isNotEmpty ? _vaults.first : null;
    }
    notifyListeners();

    // 2. If vaults exist in local cache, select the first
    if (_vaults.isNotEmpty && _selectedVault == null) {
      _selectedVault = _vaults.first;
      notifyListeners();
    }

    // 3. Firestore Realtime Sync Listener
    try {
      _vaultSub?.cancel();
      _vaultSub = FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('features')
          .doc('vaults')
          .snapshots()
          .listen((snap) {
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          if (data['vaults'] != null && data['vaults'] is List) {
            final raw = data['vaults'] as List;
            final incoming = raw
                .map((e) => VaultItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();

            final Map<String, VaultItem> map = {};
            for (final v in _vaults) {
              if (_isAllowedVault(v, currentUserId, spaceId)) {
                map[v.id] = v;
              }
            }
            for (final v in incoming) {
              if (_isAllowedVault(v, currentUserId, spaceId)) {
                map[v.id] = v;
              }
            }

            _vaults = map.values.toList();
            if (_selectedVault == null || !_vaults.any((v) => v.id == _selectedVault!.id)) {
              _selectedVault = _vaults.isNotEmpty ? _vaults.first : null;
            }
            
            // Check scheduled notifications for locked timers
            for (final v in _vaults) {
              if (v.accessMode == 'timer' && v.specialDate != null && v.specialDate!.isAfter(DateTime.now())) {
                NotificationService.scheduleVaultUnlockNotification(
                  capsuleId: v.id,
                  title: v.title,
                  unlockDateTime: v.specialDate!,
                );
              }
            }
            notifyListeners();
          }
        }
      });
    } catch (_) {}
  }

  /// Re-fetches shared and personal vaults when resuming the app.
  Future<void> refreshVaults() async {
    final spaceId = _activeSpaceId;
    final userId = _currentUserId;
    if (spaceId == null || userId == null) return;
    await initVaultSync(
      spaceId: spaceId,
      currentUserId: userId,
      partnerId: _partnerId,
      partnerNickname: _partnerNickname,
    );
  }

  void _handleSupabaseVaultsUpdate(Map<String, dynamic> data) {
    if (data['vaults'] != null && data['vaults'] is List) {
      final raw = data['vaults'] as List;
      final loaded = raw
          .map((e) => VaultItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final spaceId = _activeSpaceId ?? '';
      final userId = _currentUserId ?? '';
      bool removedMidnight = false;
      final filtered = loaded.where((v) {
        if (v.id == 'vault_midnight_seed' || v.title.toLowerCase().trim() == 'the midnight letters') {
          removedMidnight = true;
          return false;
        }
        return _isAllowedVault(v, userId, spaceId);
      }).toList();

      _vaults = filtered;

      if (removedMidnight && _activeSpaceId != null) {
        _syncVaultsToCloud(_activeSpaceId!);
      }

      if (_selectedVault == null || !_vaults.any((v) => v.id == _selectedVault!.id)) {
        _selectedVault = _vaults.isNotEmpty ? _vaults.first : null;
      }
      notifyListeners();
    }
  }

  Future<void> createVault(VaultItem item, String spaceId) async {
    _vaults.insert(0, item);
    _selectedVault = item;
    notifyListeners();

    if (item.accessMode == 'timer' && item.specialDate != null && item.specialDate!.isAfter(DateTime.now())) {
      await NotificationService.scheduleVaultUnlockNotification(
        capsuleId: item.id,
        title: item.title,
        unlockDateTime: item.specialDate!,
      );
    }

    await _syncVaultsToCloud(spaceId);
  }

  Future<void> updateVault(VaultItem updated, String spaceId) async {
    final idx = _vaults.indexWhere((v) => v.id == updated.id);
    if (idx != -1) {
      _vaults[idx] = updated;
      if (_selectedVault?.id == updated.id) {
        _selectedVault = updated;
      }
      notifyListeners();

      if (updated.accessMode == 'timer' && updated.specialDate != null && updated.specialDate!.isAfter(DateTime.now())) {
        await NotificationService.scheduleVaultUnlockNotification(
          capsuleId: updated.id,
          title: updated.title,
          unlockDateTime: updated.specialDate!,
        );
      } else {
        await NotificationService.cancelScheduledVaultNotification(updated.id);
      }

      await _syncVaultsToCloud(spaceId);
    }
  }

  /// Real permanent hard delete from both Firestore and Supabase databases + storage files
  Future<bool> deleteVault(String vaultId, String spaceId) async {
    final idx = _vaults.indexWhere((v) => v.id == vaultId);
    final target = idx != -1 ? _vaults[idx] : null;
    final myUid = _currentUserId ?? '';
    if (target != null && myUid.isNotEmpty) {
      final ownerUid = OwnershipHelper.extractOwnerUid(target.creatorId);
      if (ownerUid.isNotEmpty &&
          !OwnershipHelper.canDeleteItem(ownerUid: ownerUid, myUid: myUid)) {
        return false;
      }
    }

    // Mark tombstone & compute remaining list WITHOUT removing locally until server confirms
    _deletedVaultIds.add(vaultId);
    await DeletedIdsStore.markDeleted('vaults', vaultId);

    final previousVaults = List<VaultItem>.from(_vaults);
    _vaults.removeWhere((v) => v.id == vaultId);

    final ok = await _syncVaultsToCloud(spaceId);
    if (!ok) {
      _vaults = previousVaults;
      _deletedVaultIds.remove(vaultId);
      await DeletedIdsStore.unmarkDeleted('vaults', vaultId);
      notifyListeners();
      return false;
    }

    if (target != null) {
      await MediaUploadService.deleteRemoteFiles([
        target.coverImageUrl,
        target.videoUrl,
        target.voiceNoteUrl,
        ...target.photoUrls,
        if (target.backgroundSong != null && target.backgroundSong!.startsWith('http'))
          target.backgroundSong,
      ]);
    }

    _unlockedVaultIds.remove(vaultId);
    await NotificationService.cancelScheduledVaultNotification(vaultId);

    if (_selectedVault?.id == vaultId) {
      _selectedVault = _vaults.isNotEmpty ? _vaults.first : null;
      await stopVaultMusic();
    }
    notifyListeners();
    return true;
  }

  Future<bool> _syncVaultsToCloud(String spaceId) async {
    final vaultDocId = 'vaults_$spaceId';
    final supabase = SupabaseService.client;

    // Union-merge remote vaults first so concurrent partner creations are never overwritten
    if (supabase != null) {
      try {
        final remoteRes = await supabase
            .from('app_content')
            .select('content')
            .eq('id', vaultDocId)
            .maybeSingle()
            .timeout(const Duration(seconds: 6));
        if (remoteRes != null && remoteRes['content'] is List) {
          final mergedById = <String, VaultItem>{};
          for (final raw in (remoteRes['content'] as List)) {
            if (raw is Map) {
              final rv = VaultItem.fromJson(Map<String, dynamic>.from(raw));
              if (_isAllowedVault(rv, _currentUserId ?? '', spaceId)) {
                mergedById[rv.id] = rv;
              }
            }
          }
          for (final lv in _vaults) {
            if (_isAllowedVault(lv, _currentUserId ?? '', spaceId)) {
              mergedById[lv.id] = lv;
            }
          }
          _vaults = mergedById.values.toList();
          notifyListeners();
        }
      } catch (e) {
        await DeviceStatusService.recordSyncError('vault_remote_merge', e.toString());
      }
    }

    final jsonList = _vaults.map((v) => v.toJson()).toList();
    bool anyServerOk = false;

    // 1. Supabase permanent hard update / save
    if (supabase != null) {
      try {
        await supabase.from('app_content').upsert({
          'id': vaultDocId,
          'content': jsonList,
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Also permanently anchor user's own vaults to their user account
        if (_currentUserId != null && _currentUserId!.isNotEmpty) {
          final myVaults = _vaults
              .where((v) => v.creatorId == _currentUserId)
              .map((v) => v.toJson())
              .toList();
          await supabase.from('app_content').upsert({
            'id': 'user_vaults_$_currentUserId',
            'content': myVaults,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
        anyServerOk = true;
      } catch (e) {
        await DeviceStatusService.recordSyncError('vault_supabase_upsert', e.toString());
      }
    }

    // 2. Firestore permanent sync
    try {
      await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('features')
          .doc('vaults')
          .set({
        'vaults': jsonList,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      anyServerOk = true;
    } catch (e) {
      await DeviceStatusService.recordSyncError('vault_firestore_set', e.toString());
    }

    // 3. Supabase Realtime broadcast (0-50ms instant sync to partner)
    try {
      await SupabaseService.broadcastEvent(
        spaceId: spaceId,
        eventType: 'VAULTS_UPDATE',
        payload: {'vaults': jsonList},
      );
    } catch (_) {}

    return anyServerOk;
  }

  @override
  void dispose() {
    _vaultSub?.cancel();
    _vaultAudio.dispose();
    SupabaseService.removeVaultListener(_handleSupabaseVaultsUpdate);
    super.dispose();
  }
}
