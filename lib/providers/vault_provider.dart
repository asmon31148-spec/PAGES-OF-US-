import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Source;
import '../data/models/vault_item.dart';
import '../data/services/supabase_service.dart';
import '../core/services/notification_service.dart';

class VaultProvider extends ChangeNotifier {
  List<VaultItem> _vaults = [];
  VaultItem? _selectedVault;
  String _activeFilter = 'all'; // 'all', 'mine', 'partner'
  final Set<String> _unlockedVaultIds = {};

  final AudioPlayer _vaultAudio = AudioPlayer();
  bool _isAudioPlaying = false;
  String? _currentPlayingTrack;
  StreamSubscription? _vaultSub;
  String? _activeSpaceId;

  List<VaultItem> get vaults => List.unmodifiable(_vaults);
  VaultItem? get selectedVault => _selectedVault ?? (_vaults.isNotEmpty ? _vaults.first : null);
  String get activeFilter => _activeFilter;
  Set<String> get unlockedVaultIds => Set.unmodifiable(_unlockedVaultIds);
  bool get isAudioPlaying => _isAudioPlaying;

  bool get shouldTriggerConfetti => false;
  void resetConfettiTrigger() {}

  void setFilter(String filter) {
    if (_activeFilter != filter) {
      _activeFilter = filter;
      notifyListeners();
    }
  }

  List<VaultItem> getFilteredVaults(String currentUserId) {
    switch (_activeFilter) {
      case 'mine':
        return _vaults.where((v) => v.creatorId == currentUserId || v.creatorId.isEmpty).toList();
      case 'partner':
        return _vaults.where((v) => v.creatorId.isNotEmpty && v.creatorId != currentUserId).toList();
      case 'all':
      default:
        return _vaults;
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

  Future<void> initVaultSync(String spaceId) async {
    if (spaceId.isEmpty) return;
    if (_activeSpaceId == spaceId && _vaultSub != null) return;
    _activeSpaceId = spaceId;

    // 0. Register Supabase Realtime Listener (0-50ms peer updates)
    SupabaseService.addVaultListener(_handleSupabaseVaultsUpdate);

    final vaultDocId = 'vaults_$spaceId';

    // 1. Supabase fetch
    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        // First try the new 'vaults_$spaceId' key
        var res = await supabase
            .from('app_content')
            .select('content')
            .eq('id', vaultDocId)
            .maybeSingle();

        // Fallback to legacy key if not found
        if (res == null || res['content'] == null) {
          res = await supabase
              .from('app_content')
              .select('content')
              .eq('id', 'vault_capsules_$spaceId')
              .maybeSingle();
        }

        if (res != null && res['content'] != null) {
          final rawList = res['content'];
          if (rawList is List && rawList.isNotEmpty) {
            final loaded = rawList
                .map((e) => VaultItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
            _vaults = loaded.where((v) => v.id != 'vault_midnight_seed' && v.title.toLowerCase().trim() != 'the midnight letters').toList();
            if (loaded.length != _vaults.length) {
              _syncVaultsToCloud(spaceId);
            }
            if (_vaults.isNotEmpty && _selectedVault == null) {
              _selectedVault = _vaults.first;
            }
            notifyListeners();
          }
        }
      }
    } catch (_) {}

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
            final loaded = raw
                .map((e) => VaultItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();

            bool removedMidnight = false;
            _vaults = loaded.where((v) {
              if (v.id == 'vault_midnight_seed' || v.title.toLowerCase().trim() == 'the midnight letters') {
                removedMidnight = true;
                return false;
              }
              return true;
            }).toList();

            if (removedMidnight) {
              _syncVaultsToCloud(spaceId);
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

  void _handleSupabaseVaultsUpdate(Map<String, dynamic> data) {
    if (data['vaults'] != null && data['vaults'] is List) {
      final raw = data['vaults'] as List;
      final loaded = raw
          .map((e) => VaultItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      bool removedMidnight = false;
      _vaults = loaded.where((v) {
        if (v.id == 'vault_midnight_seed' || v.title.toLowerCase().trim() == 'the midnight letters') {
          removedMidnight = true;
          return false;
        }
        return true;
      }).toList();

      if (removedMidnight && _activeSpaceId != null) {
        _syncVaultsToCloud(_activeSpaceId!);
      }

      if (_vaults.isNotEmpty && _selectedVault == null) {
        _selectedVault = _vaults.first;
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

  /// Real permanent hard delete from both Firestore and Supabase databases
  Future<void> deleteVault(String vaultId, String spaceId) async {
    _vaults.removeWhere((v) => v.id == vaultId);
    _unlockedVaultIds.remove(vaultId);
    await NotificationService.cancelScheduledVaultNotification(vaultId);

    if (_selectedVault?.id == vaultId) {
      _selectedVault = _vaults.isNotEmpty ? _vaults.first : null;
      await stopVaultMusic();
    }
    notifyListeners();

    // Sync permanently to Cloud
    await _syncVaultsToCloud(spaceId);
  }

  Future<void> _syncVaultsToCloud(String spaceId) async {
    final jsonList = _vaults.map((v) => v.toJson()).toList();
    final vaultDocId = 'vaults_$spaceId';

    // 1. Supabase permanent hard update / save
    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('app_content').upsert({
          'id': vaultDocId,
          'content': jsonList,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

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
      }, SetOptions(merge: true));
    } catch (_) {}

    // 3. Supabase Realtime broadcast (0-50ms instant sync to partner)
    try {
      await SupabaseService.broadcastEvent(
        spaceId: spaceId,
        eventType: 'VAULTS_UPDATE',
        payload: {'vaults': jsonList},
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _vaultSub?.cancel();
    _vaultAudio.dispose();
    SupabaseService.removeVaultListener(_handleSupabaseVaultsUpdate);
    super.dispose();
  }
}
