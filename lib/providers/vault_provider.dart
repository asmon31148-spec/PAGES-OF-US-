import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/vault_model.dart';
import '../data/services/supabase_service.dart';

class VaultProvider extends ChangeNotifier {
  VaultModel _vault = VaultModel();
  bool _isUnlocked = false;
  String _enteredPin = '';
  bool _isError = false;

  VaultModel get vault => _vault;
  bool get isUnlocked => _isUnlocked;
  String get enteredPin => _enteredPin;
  bool get isError => _isError;

  void appendPinDigit(String digit) {
    if (_enteredPin.length < 4) {
      _enteredPin += digit;
      _isError = false;
      notifyListeners();

      if (_enteredPin.length == 4) {
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
    if (_enteredPin == _vault.passcode) {
      _isUnlocked = true;
      _isError = false;
      _enteredPin = '';
      notifyListeners();
      return true;
    } else {
      _isError = true;
      _enteredPin = '';
      notifyListeners();
      return false;
    }
  }

  void lockVault() {
    _isUnlocked = false;
    _enteredPin = '';
    notifyListeners();
  }

  Future<void> initVaultSync(String spaceId) async {
    final vaultDocId = 'vault_$spaceId';

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
          _vault = VaultModel.fromJson(Map<String, dynamic>.from(res['content']));
          notifyListeners();
        }
      }
    } catch (_) {}

    // 2. Firestore fetch & listener
    try {
      FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('features')
          .doc('vault')
          .snapshots()
          .listen((snap) {
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          if (data['vault'] != null) {
            _vault = VaultModel.fromJson(Map<String, dynamic>.from(data['vault']));
            notifyListeners();
          }
        }
      });
    } catch (_) {}
  }

  Future<void> updateVaultConfig({
    required String spaceId,
    required String title,
    required String subtitle,
    required String passcode,
    required String? videoUrl,
    required String personalNote,
  }) async {
    _vault = _vault.copyWith(
      title: title,
      subtitle: subtitle,
      passcode: passcode,
      videoUrl: videoUrl,
      personalNote: personalNote,
    );
    notifyListeners();

    final vaultDocId = 'vault_$spaceId';

    // Supabase upsert
    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('app_content').upsert({
          'id': vaultDocId,
          'content': _vault.toJson(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    // Firestore upsert
    try {
      await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('features')
          .doc('vault')
          .set({
        'vault': _vault.toJson(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
