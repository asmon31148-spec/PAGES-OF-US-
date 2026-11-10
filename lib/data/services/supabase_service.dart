import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants/app_constants.dart';

class SupabaseService {
  static SupabaseClient? _client;

  static Future<void> init() async {
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );
      _client = Supabase.instance.client;
    } catch (_) {
      // Fallback if network unavailable on boot
    }
  }

  static SupabaseClient? get client => _client;

  // --- Supabase Authentication API ---

  static Stream<AuthState> get authStateChanges =>
      Supabase.instance.client.auth.onAuthStateChange;

  static User? get currentAuthUser =>
      Supabase.instance.client.auth.currentUser;

  static Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await Supabase.instance.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<AuthResponse> registerWithEmail(
    String email,
    String password,
    String nickname,
  ) async {
    return await Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'nickname': nickname.trim()},
    );
  }

  static Future<void> sendPasswordReset(String email) async {
    await Supabase.instance.client.auth.resetPasswordForEmail(email.trim());
  }

  static Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  static Future<AuthResponse?> signInWithGoogle() async {
    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw const AuthException('No Google ID token returned from Google Play Services.');
      }

      final res = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      return res;
    } catch (e) {
      debugPrint('[SupabaseService] signInWithGoogle error: $e');
      rethrow;
    }
  }

  // Realtime Broadcast Channel
  static RealtimeChannel? _channel;
  static String? _currentSpaceId;
  static final List<Function(Map<String, dynamic> data)> _locationCallbacks = [];
  static final List<Function(Map<String, dynamic> data)> _vaultCallbacks = [];

  // Persistent Event Handlers
  static Function(Map<String, dynamic> data)? _onPulse;
  static Function(Map<String, dynamic> data)? _onHeartbeatPulse;
  static Function(Map<String, dynamic> data)? _onMood;
  static Function(Map<String, dynamic> data)? _onTouchPad;
  static Function(Map<String, dynamic> data)? _onDrawStroke;
  static Function(Map<String, dynamic> data)? _onSyncDrawing;
  static Function(Map<String, dynamic> data)? _onClearDrawing;
  static Function(Map<String, dynamic> data)? _onTouchCountSync;
  static Function(Map<String, dynamic> data)? _onDailyPrompt;
  static Function(Map<String, dynamic> data)? _onPinnedNote;
  static Function(Map<String, dynamic> data)? _onListenInvite;
  static Function(Map<String, dynamic> data)? _onThemeUpdate;
  static Function(Map<String, dynamic> data)? _onGentleMode;
  static Function(Map<String, dynamic> data)? _onPlaylistsUpdate;
  static Function(Map<String, dynamic> data)? _onMusicUpdate;
  static Function(Map<String, dynamic> data)? _onProfileUpdate;
  static Function(Map<String, dynamic> data)? _onBucketListUpdate;
  static Function(Map<String, dynamic> data)? _onBatteryStatus;
  static Function(Map<String, dynamic> data)? _onDeviceTelemetry;
  static Function(Map<String, dynamic> data)? _onSecretWhisper;
  static Function(Map<String, dynamic> data)? _onGeofenceEvent;

  static void setThemeUpdateListener(Function(Map<String, dynamic> data)? callback) {
    _onThemeUpdate = callback;
  }

  static void setMusicSyncListener({
    Function(Map<String, dynamic> data)? onPlaylistsUpdate,
    Function(Map<String, dynamic> data)? onMusicUpdate,
  }) {
    _onPlaylistsUpdate = onPlaylistsUpdate;
    _onMusicUpdate = onMusicUpdate;
  }

  static void setProfileUpdateListener(Function(Map<String, dynamic> data)? callback) {
    _onProfileUpdate = callback;
  }

  static void setBucketListListener(Function(Map<String, dynamic> data)? callback) {
    _onBucketListUpdate = callback;
  }

  static void setBatteryStatusListener(Function(Map<String, dynamic> data)? callback) {
    _onBatteryStatus = callback;
  }

  static void setDeviceTelemetryListener(Function(Map<String, dynamic> data)? callback) {
    _onDeviceTelemetry = callback;
  }

  static void setSecretWhisperListener(Function(Map<String, dynamic> data)? callback) {
    _onSecretWhisper = callback;
  }

  static void setGeofenceEventListener(Function(Map<String, dynamic> data)? callback) {
    _onGeofenceEvent = callback;
  }

  static void addLocationListener(Function(Map<String, dynamic> data) callback) {
    if (!_locationCallbacks.contains(callback)) {
      _locationCallbacks.add(callback);
    }
  }

  static void removeLocationListener(Function(Map<String, dynamic> data) callback) {
    _locationCallbacks.remove(callback);
  }

  static void addVaultListener(Function(Map<String, dynamic> data) callback) {
    if (!_vaultCallbacks.contains(callback)) {
      _vaultCallbacks.add(callback);
    }
  }

  static void removeVaultListener(Function(Map<String, dynamic> data) callback) {
    _vaultCallbacks.remove(callback);
  }

  static RealtimeChannel _ensureChannel(String spaceId) {
    if (_channel != null && _currentSpaceId == spaceId) {
      return _channel!;
    }

    if (_channel != null) {
      try {
        _client?.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }

    _currentSpaceId = spaceId;
    final ch = _client!.channel(
      'stage_space_$spaceId',
      opts: const RealtimeChannelConfig(ack: false, self: false),
    );

    ch.onBroadcast(
      event: 'PULSE',
      callback: (payload) => _onPulse?.call(payload),
    );

    ch.onBroadcast(
      event: 'HEARTBEAT_PULSE',
      callback: (payload) => _onHeartbeatPulse?.call(payload),
    );

    ch.onBroadcast(
      event: 'MOOD_UPDATE',
      callback: (payload) => _onMood?.call(payload),
    );

    ch.onBroadcast(
      event: 'TOUCH_PAD_EVENT',
      callback: (payload) => _onTouchPad?.call(payload),
    );

    ch.onBroadcast(
      event: 'LOCATION_UPDATE',
      callback: (payload) {
        for (final cb in List<Function(Map<String, dynamic> data)>.from(_locationCallbacks)) {
          try {
            cb(payload);
          } catch (_) {}
        }
      },
    );

    ch.onBroadcast(
      event: 'VAULTS_UPDATE',
      callback: (payload) {
        for (final cb in List<Function(Map<String, dynamic> data)>.from(_vaultCallbacks)) {
          try {
            cb(payload);
          } catch (_) {}
        }
      },
    );

    ch.onBroadcast(
      event: 'DRAW_STROKE',
      callback: (payload) => _onDrawStroke?.call(payload),
    );

    ch.onBroadcast(
      event: 'CLEAR_DRAWING',
      callback: (payload) => _onClearDrawing?.call(payload),
    );

    ch.onBroadcast(
      event: 'SYNC_DRAWING',
      callback: (payload) => _onSyncDrawing?.call(payload),
    );

    ch.onBroadcast(
      event: 'TOUCH_COUNT_SYNC',
      callback: (payload) => _onTouchCountSync?.call(payload),
    );

    ch.onBroadcast(
      event: 'DAILY_PROMPT_UPDATE',
      callback: (payload) => _onDailyPrompt?.call(payload),
    );

    ch.onBroadcast(
      event: 'PINNED_NOTE_CHANGED',
      callback: (payload) => _onPinnedNote?.call(payload),
    );

    ch.onBroadcast(
      event: 'LISTEN_INVITE',
      callback: (payload) => _onListenInvite?.call(payload),
    );

    ch.onBroadcast(
      event: 'THEME_UPDATE',
      callback: (payload) => _onThemeUpdate?.call(payload),
    );

    ch.onBroadcast(
      event: 'GENTLE_MODE_UPDATE',
      callback: (payload) => _onGentleMode?.call(payload),
    );

    ch.onBroadcast(
      event: 'PLAYLISTS_UPDATE',
      callback: (payload) => _onPlaylistsUpdate?.call(payload),
    );

    ch.onBroadcast(
      event: 'MUSIC_UPDATE',
      callback: (payload) => _onMusicUpdate?.call(payload),
    );

    ch.onBroadcast(
      event: 'PROFILE_UPDATE',
      callback: (payload) => _onProfileUpdate?.call(payload),
    );

    ch.onBroadcast(
      event: 'BUCKET_LIST_UPDATE',
      callback: (payload) => _onBucketListUpdate?.call(payload),
    );

    ch.onBroadcast(
      event: 'BATTERY_STATUS',
      callback: (payload) => _onBatteryStatus?.call(payload),
    );

    ch.onBroadcast(
      event: 'DEVICE_TELEMETRY',
      callback: (payload) => _onDeviceTelemetry?.call(payload),
    );

    ch.onBroadcast(
      event: 'SECRET_WHISPER',
      callback: (payload) => _onSecretWhisper?.call(payload),
    );

    ch.onBroadcast(
      event: 'GEOFENCE_EVENT',
      callback: (payload) => _onGeofenceEvent?.call(payload),
    );

    ch.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.closed) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (_currentSpaceId == spaceId && _channel != null) {
            try {
              _channel!.subscribe();
            } catch (_) {}
          }
        });
      }
    });

    _channel = ch;
    return ch;
  }

  static void subscribeToSpaceEvents(
    String spaceId, {
    required Function(Map<String, dynamic> data) onPulse,
    Function(Map<String, dynamic> data)? onHeartbeatPulse,
    required Function(Map<String, dynamic> data) onMood,
    required Function(Map<String, dynamic> data) onTouchPad,
    Function(Map<String, dynamic> data)? onDrawStroke,
    Function(Map<String, dynamic> data)? onSyncDrawing,
    Function(Map<String, dynamic> data)? onClearDrawing,
    Function(Map<String, dynamic> data)? onTouchCountSync,
    Function(Map<String, dynamic> data)? onDailyPrompt,
    Function(Map<String, dynamic> data)? onPinnedNote,
    Function(Map<String, dynamic> data)? onListenInvite,
    Function(Map<String, dynamic> data)? onGentleMode,
  }) {
    if (_client == null || spaceId.isEmpty) return;

    _onPulse = onPulse;
    _onHeartbeatPulse = onHeartbeatPulse;
    _onMood = onMood;
    _onTouchPad = onTouchPad;
    _onDrawStroke = onDrawStroke;
    _onSyncDrawing = onSyncDrawing;
    _onClearDrawing = onClearDrawing;
    _onTouchCountSync = onTouchCountSync;
    _onDailyPrompt = onDailyPrompt;
    _onPinnedNote = onPinnedNote;
    _onListenInvite = onListenInvite;
    _onGentleMode = onGentleMode;

    try {
      _ensureChannel(spaceId);
    } catch (_) {}
  }

  static Future<void> broadcastEvent({
    required String spaceId,
    required String eventType,
    required Map<String, dynamic> payload,
  }) async {
    if (_client == null || spaceId.isEmpty) return;
    try {
      final ch = _ensureChannel(spaceId);
      await ch.sendBroadcastMessage(
        event: eventType,
        payload: payload,
      );
    } catch (_) {}
  }

  // App Content Upsert
  static Future<void> upsertAppContent(String id, Map<String, dynamic> content) async {
    if (_client == null) return;
    try {
      final nowIso = DateTime.now().toIso8601String();
      await _client!.from('app_content').upsert({
        'id': id,
        'content': content,
        'updated_at': nowIso,
      });
    } catch (_) {}
  }

  // App Content Retrieval
  static Future<Map<String, dynamic>?> getAppContent(String id) async {
    if (_client == null) return null;
    try {
      final res = await _client!
          .from('app_content')
          .select('content')
          .eq('id', id)
          .maybeSingle();
      if (res != null && res['content'] != null) {
        return Map<String, dynamic>.from(res['content'] as Map);
      }
    } catch (_) {}
    return null;
  }
}
