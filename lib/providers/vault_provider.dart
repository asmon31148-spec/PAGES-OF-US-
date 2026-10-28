import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/vault_item.dart';
import '../data/models/event_capsule.dart';
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

  // Compatibility with existing capsule references
  List<EventCapsule> get capsules => _vaults.map((v) => EventCapsule(
    id: v.id,
    creatorId: v.creatorId,
    creatorName: v.creatorName,
    title: v.title,
    eventType: v.accessMode,
    passcode: v.pinCode ?? '',
    personalNote: v.letter,
    videoUrl: v.videoUrl,
    ambientTrack: v.backgroundSong,
    unlockAt: v.specialDate,
    createdAt: v.createdAt,
  )).toList();

  EventCapsule? get selectedCapsule {
    final v = selectedVault;
    if (v == null) return null;
    return EventCapsule(
      id: v.id,
      creatorId: v.creatorId,
      creatorName: v.creatorName,
      title: v.title,
      eventType: v.accessMode,
      passcode: v.pinCode ?? '',
      personalNote: v.letter,
      videoUrl: v.videoUrl,
      ambientTrack: v.backgroundSong,
      unlockAt: v.specialDate,
      createdAt: v.createdAt,
    );
  }

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

      if (track.startsWith('http')) {
        await _vaultAudio.play(UrlSource(track));
      } else if (track == 'lofi_sanctuary' || track.startsWith('lofi')) {
        await _vaultAudio.play(AssetSource('audio/lofi_sanctuary.mp3'));
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
            _vaults = rawList
                .map((e) => VaultItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
            if (_vaults.isNotEmpty && _selectedVault == null) {
              _selectedVault = _vaults.first;
            }
            notifyListeners();
          }
        }
      }
    } catch (_) {}

    // 2. Initial Default Seeds if empty
    if (_vaults.isEmpty) {
      _vaults = [
        VaultItem(
          id: 'vault_paris_seed',
          creatorId: '',
          creatorName: 'You',
          title: 'Our First Paris Trip',
          emblemShape: 'circle',
          colorValue: 0xFF541525, // Wine
          specialDate: DateTime.now().add(const Duration(days: 49)),
          accessMode: 'timer',
          letter: 'No matter how many places we wander through, this city and this view with you remains my absolute favorite memory in this universe.',
          photoUrls: [],
          backgroundSong: 'lofi_sanctuary',
          createdAt: DateTime.now().subtract(const Duration(days: 12)),
        ),
        VaultItem(
          id: 'vault_midnight_seed',
          creatorId: 'partner',
          creatorName: 'Partner',
          title: 'The Midnight Letters',
          emblemShape: 'arch',
          colorValue: 0xFF162238, // Midnight Navy
          accessMode: 'pin',
          pinCode: '1234',
          letter: 'Every quiet night I think of the moments we promised each other under the stars.',
          photoUrls: [],
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ];
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
            _vaults = raw
                .map((e) => VaultItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
            
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
  }

  // Backward compatibility methods
  Future<void> addEventCapsule(EventCapsule capsule, String spaceId) async {
    final item = VaultItem(
      id: capsule.id,
      creatorId: capsule.creatorId,
      creatorName: capsule.creatorName,
      title: capsule.title,
      colorValue: 0xFF541525,
      emblemShape: 'circle',
      accessMode: capsule.passcode.isNotEmpty ? 'pin' : (capsule.unlockAt != null ? 'timer' : 'open'),
      pinCode: capsule.passcode.isNotEmpty ? capsule.passcode : null,
      specialDate: capsule.unlockAt,
      letter: capsule.personalNote,
      videoUrl: capsule.videoUrl,
      backgroundSong: capsule.ambientTrack,
      createdAt: capsule.createdAt,
    );
    await createVault(item, spaceId);
  }

  Future<void> updateEventCapsule(EventCapsule capsule, String spaceId) async {
    final item = VaultItem(
      id: capsule.id,
      creatorId: capsule.creatorId,
      creatorName: capsule.creatorName,
      title: capsule.title,
      colorValue: 0xFF541525,
      emblemShape: 'circle',
      accessMode: capsule.passcode.isNotEmpty ? 'pin' : (capsule.unlockAt != null ? 'timer' : 'open'),
      pinCode: capsule.passcode.isNotEmpty ? capsule.passcode : null,
      specialDate: capsule.unlockAt,
      letter: capsule.personalNote,
      videoUrl: capsule.videoUrl,
      backgroundSong: capsule.ambientTrack,
      createdAt: capsule.createdAt,
    );
    await updateVault(item, spaceId);
  }

  Future<void> deleteEventCapsule(String capsuleId, String spaceId) async {
    await deleteVault(capsuleId, spaceId);
  }

  @override
  void dispose() {
    _vaultSub?.cancel();
    _vaultAudio.dispose();
    super.dispose();
  }
}
