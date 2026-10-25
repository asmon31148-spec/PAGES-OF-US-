import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/event_capsule.dart';
import '../data/models/vault_model.dart';
import '../data/services/supabase_service.dart';
import '../core/services/notification_service.dart';

class VaultProvider extends ChangeNotifier {
  List<EventCapsule> _capsules = [];
  EventCapsule? _selectedCapsule;
  bool _isUnlocked = false;
  String _enteredPin = '';
  bool _isError = false;
  bool _shouldTriggerConfetti = false;

  final AudioPlayer _vaultAudio = AudioPlayer();
  bool _isAudioPlaying = false;

  List<EventCapsule> get capsules => List.unmodifiable(_capsules);
  EventCapsule? get selectedCapsule => _selectedCapsule ?? (_capsules.isNotEmpty ? _capsules.first : null);
  bool get isUnlocked => _isUnlocked;
  String get enteredPin => _enteredPin;
  bool get isError => _isError;
  bool get shouldTriggerConfetti => _shouldTriggerConfetti;

  // Compatibility getter with legacy VaultModel
  VaultModel get vault {
    final c = selectedCapsule;
    if (c == null) return VaultModel();
    return VaultModel(
      isLocked: !_isUnlocked,
      passcode: c.passcode,
      title: c.title,
      subtitle: c.eventType,
      videoUrl: c.videoUrl,
      personalNote: c.personalNote,
    );
  }

  void selectCapsule(EventCapsule capsule) {
    if (_selectedCapsule?.id != capsule.id) {
      _selectedCapsule = capsule;
      _isUnlocked = false;
      _enteredPin = '';
      _isError = false;
      _stopVaultMusic();
      notifyListeners();
    }
  }

  void appendPinDigit(String digit) {
    if (_enteredPin.length < 6) {
      _enteredPin += digit;
      _isError = false;
      notifyListeners();

      if (_enteredPin.length == 6) {
        verifyPin();
      }
    }
  }

  void deletePinDigit() {
    if (_enteredPin.isNotEmpty) {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _isError = false;
      notifyListeners();
    }
  }

  void clearPin() {
    _enteredPin = '';
    _isError = false;
    notifyListeners();
  }

  bool verifyPin() {
    final target = selectedCapsule;
    if (target == null) return false;

    // Check if entered pin matches 6-digit passcode
    if (_enteredPin == target.passcode) {
      _isUnlocked = true;
      _isError = false;
      _enteredPin = '';
      _shouldTriggerConfetti = true;
      _playVaultMusic(target.ambientTrack);
      notifyListeners();
      return true;
    } else {
      _isError = true;
      _enteredPin = '';
      notifyListeners();
      return false;
    }
  }

  void resetConfettiTrigger() {
    _shouldTriggerConfetti = false;
  }

  void lockVault() {
    _isUnlocked = false;
    _enteredPin = '';
    _stopVaultMusic();
    notifyListeners();
  }

  Future<void> _playVaultMusic(String? track) async {
    try {
      await _vaultAudio.stop();
      await _vaultAudio.setReleaseMode(ReleaseMode.loop);
      await _vaultAudio.setVolume(0.35);

      if (track == null || track.isEmpty || track == 'lofi_sanctuary') {
        await _vaultAudio.play(AssetSource('audio/lofi_sanctuary.mp3'));
      } else if (track.startsWith('http')) {
        await _vaultAudio.play(UrlSource(track));
      } else {
        await _vaultAudio.play(AssetSource('audio/$track.mp3'));
      }
      _isAudioPlaying = true;
    } catch (_) {}
  }

  Future<void> _stopVaultMusic() async {
    try {
      if (_isAudioPlaying) {
        await _vaultAudio.stop();
        _isAudioPlaying = false;
      }
    } catch (_) {}
  }

  Future<void> initVaultSync(String spaceId) async {
    final vaultDocId = 'vault_capsules_$spaceId';

    // 1. Supabase fetch
    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        final res = await supabase
            .from('app_content')
            .select('content')
            .eq('id', vaultDocId)
            .maybeSingle();

        if (res != null && res['content'] != null) {
          final rawList = res['content'];
          if (rawList is List) {
            _capsules = rawList
                .map((e) => EventCapsule.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
            if (_capsules.isNotEmpty && _selectedCapsule == null) {
              _selectedCapsule = _capsules.first;
            }
            notifyListeners();
          }
        }
      }
    } catch (_) {}

    // 2. Fallback initial seed if empty
    if (_capsules.isEmpty) {
      _capsules = [
        EventCapsule(
          id: 'initial_vault_capsule',
          creatorId: '',
          creatorName: 'You',
          title: 'Just for us',
          eventType: 'special',
          passcode: '251200',
          passcodeHint: 'Our special 6-digit key 🗝️',
          personalNote: '“No matter how many places we go, this is still my favorite view.”',
          createdAt: DateTime.now(),
        ),
      ];
      _selectedCapsule = _capsules.first;
      notifyListeners();
    }

    // 3. Firestore Realtime Listener
    try {
      FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('features')
          .doc('vault_capsules')
          .snapshots()
          .listen((snap) {
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          if (data['capsules'] != null && data['capsules'] is List) {
            final raw = data['capsules'] as List;
            _capsules = raw
                .map((e) => EventCapsule.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
            for (final c in _capsules) {
              if (c.unlockAt != null && c.unlockAt!.isAfter(DateTime.now())) {
                NotificationService.scheduleVaultUnlockNotification(
                  capsuleId: c.id,
                  title: c.title,
                  unlockDateTime: c.unlockAt!,
                );
              }
            }
            notifyListeners();
          }
        }
      });
    } catch (_) {}
  }

  Future<void> addEventCapsule(EventCapsule capsule, String spaceId) async {
    _capsules.insert(0, capsule);
    _selectedCapsule = capsule;
    _isUnlocked = false;
    _enteredPin = '';
    notifyListeners();

    if (capsule.unlockAt != null) {
      await NotificationService.scheduleVaultUnlockNotification(
        capsuleId: capsule.id,
        title: capsule.title,
        unlockDateTime: capsule.unlockAt!,
      );
    }

    await _syncCapsulesToCloud(spaceId);
  }

  Future<void> updateEventCapsule(EventCapsule updated, String spaceId) async {
    final idx = _capsules.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      _capsules[idx] = updated;
      if (_selectedCapsule?.id == updated.id) {
        _selectedCapsule = updated;
      }
      notifyListeners();

      if (updated.unlockAt != null) {
        await NotificationService.scheduleVaultUnlockNotification(
          capsuleId: updated.id,
          title: updated.title,
          unlockDateTime: updated.unlockAt!,
        );
      } else {
        await NotificationService.cancelScheduledVaultNotification(updated.id);
      }

      await _syncCapsulesToCloud(spaceId);
    }
  }

  Future<void> deleteEventCapsule(String capsuleId, String spaceId) async {
    _capsules.removeWhere((c) => c.id == capsuleId);
    await NotificationService.cancelScheduledVaultNotification(capsuleId);
    if (_selectedCapsule?.id == capsuleId) {
      _selectedCapsule = _capsules.isNotEmpty ? _capsules.first : null;
      _isUnlocked = false;
      _stopVaultMusic();
    }
    notifyListeners();
    await _syncCapsulesToCloud(spaceId);
  }

  Future<void> _syncCapsulesToCloud(String spaceId) async {
    final jsonList = _capsules.map((c) => c.toJson()).toList();
    final vaultDocId = 'vault_capsules_$spaceId';

    // Supabase
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

    // Firestore
    try {
      await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('features')
          .doc('vault_capsules')
          .set({
        'capsules': jsonList,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  void dispose() {
    _vaultAudio.dispose();
    super.dispose();
  }
}
