import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/user_profile.dart';
import '../data/models/space_model.dart';
import '../data/services/firebase_service.dart';
import '../core/services/local_cache_service.dart';

class AuthProvider extends ChangeNotifier {
  UserProfile? _user;
  SpaceModel? _space;
  UserProfile? _partner;
  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription<User?>? _authSub;
  StreamSubscription? _spaceSub;

  UserProfile? get user => _user;
  SpaceModel? get space => _space;
  UserProfile? get partner => _partner;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isPaired => _space != null && _space!.members.length > 1;

  AuthProvider() {
    // 1. INSTANT LOCAL CACHE LOAD (0ms delay!)
    final cachedUser = LocalCacheService.getCachedUser();
    if (cachedUser != null) {
      _user = UserProfile.fromJson(cachedUser);
    }
    final cachedSpace = LocalCacheService.getCachedSpace();
    if (cachedSpace != null) {
      _space = SpaceModel.fromJson(cachedSpace);
    }
    final cachedPartner = LocalCacheService.getCachedPartner();
    if (cachedPartner != null) {
      _partner = UserProfile.fromJson(cachedPartner);
    }
    _isLoading = false;

    // 2. BACKGROUND SERVER SYNC
    _initAuthListener();
  }

  void _initAuthListener() {
    _authSub = FirebaseService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser == null) {
        _spaceSub?.cancel();
        _user = null;
        _space = null;
        _partner = null;
        await LocalCacheService.clearAll();
        notifyListeners();
      } else {
        await refreshUserData(firebaseUser.uid);
      }
    });
  }

  void _listenToSpace(String spaceId, String currentUid) {
    if (spaceId.isEmpty) return;
    _spaceSub?.cancel();
    _spaceSub = FirebaseService.streamSpace(spaceId).listen((doc) async {
      if (doc.exists && doc.data() != null) {
        final updatedSpace = SpaceModel.fromJson(doc.data()!);
        _space = updatedSpace;
        await LocalCacheService.setCachedSpace(updatedSpace.toJson());

        // Check if partner exists in members
        final partnerId = updatedSpace.members.firstWhere(
          (m) => m != currentUid,
          orElse: () => '',
        );
        if (partnerId.isNotEmpty && (_partner == null || _partner!.id != partnerId)) {
          final partnerData = await FirebaseService.getUserProfile(partnerId);
          if (partnerData != null) {
            _partner = partnerData;
            await LocalCacheService.setCachedPartner(partnerData.toJson());
          }
        }
        notifyListeners();
      }
    });
  }

  Future<void> refreshUserData(String uid) async {
    try {
      final profile = await FirebaseService.getUserProfile(uid);
      if (profile != null) {
        _user = profile;
        await LocalCacheService.setCachedUser(profile.toJson());

        if (profile.spaceId != null && profile.spaceId!.isNotEmpty) {
          _listenToSpace(profile.spaceId!, uid);
          final spaceData = await FirebaseService.getSpace(profile.spaceId!);
          if (spaceData != null) {
            _space = spaceData;
            await LocalCacheService.setCachedSpace(spaceData.toJson());

            // Fetch partner if present
            final partnerId = spaceData.members.firstWhere(
              (m) => m != uid,
              orElse: () => '',
            );
            if (partnerId.isNotEmpty) {
              final partnerData = await FirebaseService.getUserProfile(partnerId);
              if (partnerData != null) {
                _partner = partnerData;
                await LocalCacheService.setCachedPartner(partnerData.toJson());
              }
            }
          }
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final cred = await FirebaseService.signInWithEmail(email, password);
      if (cred.user != null) {
        await refreshUserData(cred.user!.uid);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String nickname) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final cred = await FirebaseService.registerWithEmail(email, password, nickname);
      if (cred.user != null) {
        await refreshUserData(cred.user!.uid);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final cred = await FirebaseService.signInWithGoogle();
      if (cred == null) {
        // User cancelled account picker
        _isLoading = false;
        notifyListeners();
        return false;
      }
      if (cred.user != null) {
        await refreshUserData(cred.user!.uid);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> createSpace() async {
    if (_user == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final newSpace = await FirebaseService.createSpace(_user!);
      _space = newSpace;
      _user = _user!.copyWith(spaceId: newSpace.id);
      await LocalCacheService.setCachedSpace(newSpace.toJson());
      await LocalCacheService.setCachedUser(_user!.toJson());
      _listenToSpace(newSpace.id, _user!.id);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> joinSpace(String pairCode) async {
    if (_user == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      final joinedSpace = await FirebaseService.joinSpace(pairCode, _user!);
      if (joinedSpace != null) {
        _space = joinedSpace;
        _user = _user!.copyWith(spaceId: joinedSpace.id);
        await LocalCacheService.setCachedSpace(joinedSpace.toJson());
        await LocalCacheService.setCachedUser(_user!.toJson());
        _listenToSpace(joinedSpace.id, _user!.id);

        // Refresh partner
        final partnerId = joinedSpace.members.firstWhere(
          (m) => m != _user!.id,
          orElse: () => '',
        );
        if (partnerId.isNotEmpty) {
          final partnerData = await FirebaseService.getUserProfile(partnerId);
          if (partnerData != null) {
            _partner = partnerData;
            await LocalCacheService.setCachedPartner(partnerData.toJson());
          }
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> updateProfile({String? nickname, String? thought, String? avatarUrl}) async {
    if (_user == null) return;
    final updated = _user!.copyWith(
      nickname: nickname,
      thought: thought,
      avatarUrl: avatarUrl,
    );
    _user = updated;
    await LocalCacheService.setCachedUser(updated.toJson());
    await FirebaseService.saveUserProfile(updated);
    notifyListeners();
  }

  Future<void> signOut() async {
    _spaceSub?.cancel();
    await FirebaseService.signOut();
  }

  @override
  void dispose() {
    _spaceSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
