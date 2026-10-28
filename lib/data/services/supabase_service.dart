import 'package:supabase_flutter/supabase_flutter.dart';
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

  // Realtime Broadcast Channel
  static RealtimeChannel? _channel;
  static String? _currentSpaceId;
  static final List<Function(Map<String, dynamic> data)> _locationCallbacks = [];

  static void addLocationListener(Function(Map<String, dynamic> data) callback) {
    if (!_locationCallbacks.contains(callback)) {
      _locationCallbacks.add(callback);
    }
  }

  static void removeLocationListener(Function(Map<String, dynamic> data) callback) {
    _locationCallbacks.remove(callback);
  }

  static void subscribeToSpaceEvents(
    String spaceId, {
    required Function(Map<String, dynamic> data) onPulse,
    required Function(Map<String, dynamic> data) onMood,
    required Function(Map<String, dynamic> data) onTouchPad,
    Function(Map<String, dynamic> data)? onDrawStroke,
    Function(Map<String, dynamic> data)? onClearDrawing,
    Function(Map<String, dynamic> data)? onTouchCountSync,
    Function(Map<String, dynamic> data)? onDailyPrompt,
    Function(Map<String, dynamic> data)? onPinnedNote,
  }) {
    if (_client == null || spaceId.isEmpty) return;

    try {
      if (_channel != null) {
        try {
          _client!.removeChannel(_channel!);
        } catch (_) {}
        _channel = null;
      }

      _currentSpaceId = spaceId;
      _channel = _client!.channel(
        'stage_space_$spaceId',
        opts: const RealtimeChannelConfig(ack: false, self: false),
      );

      _channel!.onBroadcast(
        event: 'PULSE',
        callback: (payload) => onPulse(payload),
      );

      _channel!.onBroadcast(
        event: 'MOOD_UPDATE',
        callback: (payload) => onMood(payload),
      );

      _channel!.onBroadcast(
        event: 'TOUCH_PAD_EVENT',
        callback: (payload) => onTouchPad(payload),
      );

      _channel!.onBroadcast(
        event: 'LOCATION_UPDATE',
        callback: (payload) {
          for (final cb in List<Function(Map<String, dynamic> data)>.from(_locationCallbacks)) {
            try {
              cb(payload);
            } catch (_) {}
          }
        },
      );

      if (onDrawStroke != null) {
        _channel!.onBroadcast(
          event: 'DRAW_STROKE',
          callback: (payload) => onDrawStroke(payload),
        );
      }

      if (onClearDrawing != null) {
        _channel!.onBroadcast(
          event: 'CLEAR_DRAWING',
          callback: (payload) => onClearDrawing(payload),
        );
      }

      if (onTouchCountSync != null) {
        _channel!.onBroadcast(
          event: 'TOUCH_COUNT_SYNC',
          callback: (payload) => onTouchCountSync(payload),
        );
      }

      if (onDailyPrompt != null) {
        _channel!.onBroadcast(
          event: 'DAILY_PROMPT_UPDATE',
          callback: (payload) => onDailyPrompt(payload),
        );
      }

      if (onPinnedNote != null) {
        _channel!.onBroadcast(
          event: 'PINNED_NOTE_CHANGED',
          callback: (payload) => onPinnedNote(payload),
        );
      }

      _channel!.subscribe((status, [error]) {
        // Realtime subscription callback
      });
    } catch (_) {}
  }

  static Future<void> broadcastEvent({
    required String spaceId,
    required String eventType,
    required Map<String, dynamic> payload,
  }) async {
    if (_client == null || spaceId.isEmpty) return;
    try {
      if (_channel == null || _currentSpaceId != spaceId) {
        _currentSpaceId = spaceId;
        _channel = _client!.channel(
          'stage_space_$spaceId',
          opts: const RealtimeChannelConfig(ack: false, self: false),
        );
        _channel!.onBroadcast(
          event: 'LOCATION_UPDATE',
          callback: (payload) {
            for (final cb in List<Function(Map<String, dynamic> data)>.from(_locationCallbacks)) {
              try {
                cb(payload);
              } catch (_) {}
            }
          },
        );
        _channel!.subscribe();
      }
      await _channel!.sendBroadcastMessage(
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
