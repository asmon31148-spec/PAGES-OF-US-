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

  static void subscribeToSpaceEvents(
    String spaceId, {
    required Function(Map<String, dynamic> data) onPulse,
    required Function(Map<String, dynamic> data) onMood,
    required Function(Map<String, dynamic> data) onTouchPad,
  }) {
    if (_client == null || spaceId.isEmpty) return;

    try {
      _channel?.unsubscribe();
      _channel = _client!.channel('stage_space_$spaceId');

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

      _channel!.subscribe();
    } catch (_) {}
  }

  static Future<void> broadcastEvent({
    required String spaceId,
    required String eventType,
    required Map<String, dynamic> payload,
  }) async {
    if (_channel == null) return;
    try {
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
}
