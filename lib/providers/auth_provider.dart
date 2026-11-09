import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/models/user_profile.dart';
import '../data/models/space_model.dart';
import '../data/services/firebase_service.dart';
import '../data/services/supabase_service.dart';
import '../core/services/local_cache_service.dart';
import '../core/services/notification_service.dart';

class PairingResult {
  final bool isSuccess;
  final String? errorMessage;
  final SpaceModel? space;

  const PairingResult._({required this.isSuccess, this.errorMessage, this.space});

  factory PairingResult.success(SpaceModel space) =>
      PairingResult._(isSuccess: true, space: space);

  factory PairingResult.failure(String message) =>
      PairingResult._(isSuccess: false, errorMessage: message);
}

class AuthProvider extends ChangeNotifier {
  UserProfile? _user;
  SpaceModel? _space;
  UserProfile? _partner;
  bool _isLoading = true;
  bool _isCreatingSpace = false;
  String? _errorMessage;

  StreamSubscription? _authSub;
  StreamSubscription? _spaceSub;
  StreamSubscription? _partnerSub;
  StreamSubscription? _userSub;

  UserProfile? get user => _user;
  UserProfile? get currentUser => _user;
  SpaceModel? get space => _space;
  SpaceModel? get currentSpace => _space;
  UserProfile? get partner => _partner;
  UserProfile? get partnerUser => _partner;
  bool get isLoading => _isLoading;
  bool get isCreatingSpace => _isCreatingSpace;
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

  static final List<FutureOr<void> Function()> _signOutHooks = [];

  static void registerSignOutHook(FutureOr<void> Function() hook) {
    if (!_signOutHooks.contains(hook)) {
      _signOutHooks.add(hook);
    }
  }

  static Future<void> runSignOutHooks() async {
    for (final hook in _signOutHooks) {
      try {
        await hook();
      } catch (e) {
        debugPrint('SignOut hook error: $e');
      }
    }
  }

  void _initAuthListener() {
    _authSub = SupabaseService.authStateChanges.listen((data) async {
      final supaUser = data.session?.user ?? SupabaseService.currentAuthUser;
      if (supaUser == null) {
        _spaceSub?.cancel();
        _partnerSub?.cancel();
        _userSub?.cancel();
        _spaceSub = null;
        _partnerSub = null;
        _userSub = null;
        _user = null;
        _space = null;
        _partner = null;
        await runSignOutHooks();
        await LocalCacheService.clearAll();
        notifyListeners();
      } else {
        // Ensure background Firebase anonymous session for Firestore & RTDB synchronization
        try {
          if (FirebaseAuth.instance.currentUser == null) {
            await FirebaseAuth.instance.signInAnonymously();
          }
        } catch (e) {
          debugPrint('Firebase background bridge note: $e');
        }

        await refreshUserData(supaUser.id);
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
        _listenToPartner(partnerId);
        notifyListeners();
      }
    });
  }

  void _listenToPartner(String partnerId) {
    if (partnerId.isEmpty) {
      _partnerSub?.cancel();
      _partnerSub = null;
      if (_partner != null) {
        _partner = null;
        LocalCacheService.setCachedPartner(null);
        notifyListeners();
      }
      return;
    }

    _partnerSub?.cancel();
    _partnerSub = FirebaseService.streamUserProfile(partnerId).listen((partnerData) {
      if (partnerData != null) {
        final wasUnpaired = _partner == null;
        _partner = partnerData;
        LocalCacheService.setCachedPartner(partnerData.toJson());
        if (wasUnpaired) {
          NotificationService.showPairingSuccessNotification(
            partnerNickname: partnerData.nickname,
          );
        }
        notifyListeners();
      }
    });
  }

  void _listenToUser(String uid) {
    if (uid.isEmpty) return;
    _userSub?.cancel();
    _userSub = FirebaseService.streamUserProfile(uid).listen((profile) async {
      if (profile != null) {
        if (_user != null &&
            profile.spaceId != null &&
            profile.spaceId!.isNotEmpty &&
            profile.spaceId != _user!.spaceId) {
          _user = profile;
          await LocalCacheService.setCachedUser(profile.toJson());
          final spaceData = await FirebaseService.getSpace(profile.spaceId!);
          if (spaceData != null) {
            _space = spaceData;
            await LocalCacheService.setCachedSpace(spaceData.toJson());
            _listenToSpace(spaceData.id, uid);
          }
        } else {
          _user = profile;
          await LocalCacheService.setCachedUser(profile.toJson());
        }
        if (profile.partnerId != null && profile.partnerId!.isNotEmpty && (_partner == null || _partner!.id != profile.partnerId)) {
          _listenToPartner(profile.partnerId!);
        } else if ((profile.partnerId == null || profile.partnerId!.isEmpty) && _partner != null) {
          // If profile cleared partner, verify with space
          if (_space == null || !_space!.members.any((m) => m != uid)) {
            _listenToPartner('');
          }
        }
        notifyListeners();
      }
    });
  }

  Future<void> refreshUserData(String uid) async {
    try {
      NotificationService.syncDeviceToken(uid);
      var profile = await FirebaseService.getUserProfile(uid);

      // Auto-provision profile from Supabase user session if not created yet
      if (profile == null) {
        final supaUser = SupabaseService.currentAuthUser;
        final email = supaUser?.email ?? '';
        final metadata = supaUser?.userMetadata ?? {};
        final nickname = metadata['nickname']?.toString() ??
            (email.isNotEmpty ? email.split('@').first : 'Partner');
        final newProfile = UserProfile(
          id: uid,
          email: email,
          nickname: nickname,
          createdAt: DateTime.now().toIso8601String(),
        );
        try {
          await FirebaseService.saveUserProfile(newProfile);
        } catch (_) {}
        profile = newProfile;
      }

      if (profile != null) {
        // Automatically ensure the user has a permanent sanctuary space & invite code
        SpaceModel? spaceData;
        if (profile.spaceId != null && profile.spaceId!.isNotEmpty) {
          spaceData = await FirebaseService.getSpace(profile.spaceId!);
        }

        if (spaceData == null) {
          spaceData = await FirebaseService.ensureUserSpace(profile);
          profile = profile.copyWith(spaceId: spaceData.id);
        }

        _user = profile;
        _space = spaceData;
        await LocalCacheService.setCachedUser(profile.toJson());
        await LocalCacheService.setCachedSpace(spaceData.toJson());
        _listenToSpace(spaceData.id, uid);
        _listenToUser(uid);

        // Fetch partner if present
        final partnerId = spaceData.members.firstWhere(
          (m) => m != uid,
          orElse: () => '',
        );
        _listenToPartner(partnerId);

        NotificationService.scheduleDailyLivingSanctuaryCadence(
          userNickname: _user?.nickname,
          partnerNickname: _partner?.nickname,
        );
      }
    } catch (e) {
      debugPrint('Error in refreshUserData: $e');
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await SupabaseService.signInWithEmail(email, password);
      final user = res.user;
      if (user != null) {
        try {
          if (FirebaseAuth.instance.currentUser == null) {
            await FirebaseAuth.instance.signInAnonymously();
          }
        } catch (_) {}
        await refreshUserData(user.id);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (e is AuthException) {
        final msg = e.message.toLowerCase();
        if (msg.contains('invalid login credentials') || msg.contains('invalid credential')) {
          _errorMessage = 'Incorrect email or password.\n• Note: If your email is asmon31148@gmail.com, please check spelling.\n• Or tap "Forgot Password?" below to reset.';
        } else if (msg.contains('email not confirmed')) {
          _errorMessage = 'Email address not confirmed yet. Please check your inbox for the confirmation email.';
        } else {
          _errorMessage = e.message;
        }
      } else {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      await SupabaseService.sendPasswordReset(email);
      return true;
    } catch (e) {
      if (e is AuthException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String nickname) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await SupabaseService.registerWithEmail(email, password, nickname);
      final user = res.user;
      if (user != null) {
        try {
          if (FirebaseAuth.instance.currentUser == null) {
            await FirebaseAuth.instance.signInAnonymously();
          }
        } catch (_) {}
        await refreshUserData(user.id);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (e is AuthException) {
        final msg = e.message.toLowerCase();
        if (msg.contains('user already registered')) {
          _errorMessage = 'An account with this email already exists. Please tap "Sign In" instead.';
        } else {
          _errorMessage = e.message;
        }
      } else {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
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
      final res = await SupabaseService.signInWithGoogle();
      if (res == null) {
        // User cancelled account picker
        _isLoading = false;
        notifyListeners();
        return false;
      }
      if (res.user != null) {
        try {
          if (FirebaseAuth.instance.currentUser == null) {
            await FirebaseAuth.instance.signInAnonymously();
          }
        } catch (_) {}
        await refreshUserData(res.user!.id);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (e is AuthException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> createSpace() async {
    if (_user == null || _isCreatingSpace) return;
    _isCreatingSpace = true;
    notifyListeners();
    try {
      final newSpace = await FirebaseService.createSpace(_user!);
      _space = newSpace;
      _user = _user!.copyWith(spaceId: newSpace.id);
      await LocalCacheService.setCachedSpace(newSpace.toJson());
      await LocalCacheService.setCachedUser(_user!.toJson());
      _listenToSpace(newSpace.id, _user!.id);
    } catch (e) {
      debugPrint('createSpace error: $e');
    } finally {
      _isCreatingSpace = false;
      notifyListeners();
    }
  }

  Future<void> ensureSpace() async {
    if (_user == null || _isCreatingSpace) return;
    _isCreatingSpace = true;
    notifyListeners();
    try {
      final space = await FirebaseService.ensureUserSpace(_user!);
      _space = space;
      _user = _user!.copyWith(spaceId: space.id);
      await LocalCacheService.setCachedSpace(space.toJson());
      await LocalCacheService.setCachedUser(_user!.toJson());
      _listenToSpace(space.id, _user!.id);
    } catch (e) {
      debugPrint('ensureSpace error: $e');
    } finally {
      _isCreatingSpace = false;
      notifyListeners();
    }
  }

  Future<PairingResult> joinSpace(String pairCode) async {
    if (_user == null) {
      return PairingResult.failure('You must be signed in to connect.');
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final joinedSpace = await FirebaseService.joinSpace(pairCode, _user!);
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
          // 1st: Pairing Successful notification
          NotificationService.showPairingSuccessNotification(
            partnerNickname: partnerData.nickname,
          );
        }
      }
      _isLoading = false;
      notifyListeners();
      return PairingResult.success(joinedSpace);
    } on PairingException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return PairingResult.failure(e.message);
    } catch (e) {
      debugPrint('joinSpace exception: $e');
      _isLoading = false;
      final msg = e.toString().replaceAll('Exception: ', '');
      _errorMessage = msg;
      notifyListeners();
      return PairingResult.failure(msg);
    }
  }

  Future<bool> disconnectPartner() async {
    if (_user == null || _space == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      final newSpace = await FirebaseService.disconnectPartner(
        currentUser: _user!,
        currentSpace: _space!,
      );
      _spaceSub?.cancel();
      _space = newSpace;
      _partner = null;
      _user = _user!.copyWith(spaceId: newSpace.id, clearPartner: true);
      await LocalCacheService.setCachedSpace(newSpace.toJson());
      await LocalCacheService.setCachedUser(_user!.toJson());
      await LocalCacheService.setCachedPartner(null);
      _listenToSpace(newSpace.id, _user!.id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
    _partnerSub?.cancel();
    _userSub?.cancel();
    _spaceSub = null;
    _partnerSub = null;
    _userSub = null;
    _user = null;
    _space = null;
    _partner = null;
    await runSignOutHooks();
    await LocalCacheService.clearAll();
    try {
      await SupabaseService.signOut();
    } catch (_) {}
    try {
      await FirebaseService.signOut();
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _spaceSub?.cancel();
    _partnerSub?.cancel();
    _userSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
