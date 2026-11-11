import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/mood_aura.dart';
import '../data/models/daily_prompt.dart';
import '../data/models/pinned_note.dart';
import '../data/models/couple_goal_item.dart';
import '../data/models/daily_care_item.dart';
import '../data/models/drawing_stroke.dart';
import '../data/models/secret_whisper.dart';
import '../data/services/firebase_service.dart';
import '../data/services/supabase_service.dart';
import '../core/constants/app_constants.dart';
import '../core/services/deleted_ids_store.dart';
import '../core/services/local_cache_service.dart';
import '../core/services/widget_sync_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/device_status_service.dart';
import '../core/utils/ownership_helper.dart';
import '../core/utils/telemetry_math.dart';
import 'auth_provider.dart';

class TouchPoint {
  final double x;
  final double y;
  final int timestamp;
  TouchPoint({required this.x, required this.y, required this.timestamp});
}

class StageProvider extends ChangeNotifier {
  String? _anniversaryDate;
  MoodAura? _myMood;
  MoodAura? _partnerMood;
  DailyPrompt? _dailyPrompt;
  List<PromptHistoryItem> _promptHistory = [];
  Map<String, PinnedNote> _pinnedNotes = {};
  List<CoupleGoalItem> _goals = [];
  List<DailyCareItem> _dailyCareItems = [];
  final Set<String> _deletedGoalIds = {};
  final Set<String> _deletedCareIds = {};
  bool _isPulsing = false;
  final List<TouchPoint> _touchPoints = [];
  TouchPoint? _partnerTouchPoint;
  Timer? _partnerTouchDecayTimer;

  // Live Drawing Strokes
  final List<DrawingStroke> _drawingStrokes = [];

  // Daily & Weekly Touch Metrics
  int _myDailyTouches = 0;
  int _partnerDailyTouches = 0;
  int _weeklyTouches = 0;
  String _lastTouchDate = '';

  StreamSubscription? _anniversarySub;
  StreamSubscription? _moodSub;
  StreamSubscription? _noteSub;
  StreamSubscription? _dailyPromptSub;
  StreamSubscription? _promptHistorySub;
  StreamSubscription? _goalsSub;
  StreamSubscription? _dailyCareSub;
  StreamSubscription? _pulseSub;
  StreamSubscription? _heartbeatSub;
  StreamSubscription? _touchStatsSub;
  StreamSubscription? _gentleModeSub;
  String? _activeSpaceId;
  String? _activeUserId;
  String? _activePartnerId;
  int _lastPulseTimestamp = 0;
  int _lastHeartbeatTimestamp = 0;
  Timer? _drawingSaveDebounce;

  // Gentle Sanctuary Mode (Zero-pressure recharging shell)
  bool _isGentleMode = false;
  bool _partnerGentleMode = false;
  bool get isGentleMode => _isGentleMode;
  bool get partnerGentleMode => _partnerGentleMode;

  // Live Partner Hardware Telemetry & Secret Whispers (100% real readings)
  DeviceBatteryStatus? _partnerBattery;
  DeviceTelemetry? _partnerTelemetry;
  DeviceTelemetry? _myTelemetry;
  List<DailyActivitySummary> _partnerDailySummaries = [];
  List<DailyActivitySummary> _myDailySummaries = [];
  String? _lastTelemetrySyncError;
  bool _isTelemetrySharingEnabled = true;
  Timer? _batterySyncTimer;
  List<SecretWhisper> _secretWhispers = [];

  DeviceBatteryStatus? get partnerBattery => _partnerBattery;
  DeviceTelemetry? get partnerTelemetry => _partnerTelemetry;
  DeviceTelemetry? get myTelemetry => _myTelemetry;
  List<DailyActivitySummary> get partnerDailySummaries =>
      List.unmodifiable(_partnerDailySummaries);
  List<DailyActivitySummary> get myDailySummaries =>
      List.unmodifiable(_myDailySummaries);
  String? get lastTelemetrySyncError => _lastTelemetrySyncError;
  bool get isTelemetrySharingEnabled => _isTelemetrySharingEnabled;
  List<SecretWhisper> get secretWhispers => List.unmodifiable(_secretWhispers);

  // Zero-Pressure Heartbeat Pulse (isolated Notifiers for buttery 60 FPS)
  final ValueNotifier<int> heartbeatPulseNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isHeartbeatActiveNotifier = ValueNotifier<bool>(false);

  String? get activeSpaceId => _activeSpaceId;
  String? get activePartnerId => _activePartnerId;

  String? get anniversaryDate => _anniversaryDate;
  MoodAura? get myMood => _myMood;
  MoodAura? get partnerMood => _partnerMood;
  DailyPrompt? get dailyPrompt => _dailyPrompt;
  List<PromptHistoryItem> get promptHistory => List.unmodifiable(_promptHistory);
  Map<String, PinnedNote> get pinnedNotes => _pinnedNotes;
  List<CoupleGoalItem> get goals => _goals;
  List<DailyCareItem> get dailyCareItems => List.unmodifiable(_dailyCareItems);
  bool get isPulsing => _isPulsing;
  List<TouchPoint> get touchPoints => List.unmodifiable(_touchPoints);
  TouchPoint? get partnerTouchPoint => _partnerTouchPoint;
  bool get isPartnerTouching => _partnerTouchPoint != null;

  List<DrawingStroke> get drawingStrokes => List.unmodifiable(_drawingStrokes);
  int get myDailyTouches => _myDailyTouches;
  int get partnerDailyTouches => _partnerDailyTouches;
  int get weeklyTouches => _weeklyTouches;

  int get daysTogether {
    if (_anniversaryDate == null || _anniversaryDate!.isEmpty) return 1;
    try {
      final start = DateTime.parse(_anniversaryDate!);
      final startDateOnly = DateTime(start.year, start.month, start.day);
      final now = DateTime.now();
      final todayDateOnly = DateTime(now.year, now.month, now.day);
      final diff = todayDateOnly.difference(startDateOnly).inDays;
      return diff >= 0 ? diff + 1 : 1;
    } catch (_) {
      return 1;
    }
  }

  StageProvider() {
    AuthProvider.registerSignOutHook(resetState);
    AuthProvider.registerDisconnectHook(clearPartnerState);
    // 1. INSTANT ZERO-LATENCY LOAD FROM LOCAL CACHE
    _anniversaryDate = LocalCacheService.getCachedAnniversary();
    final cachedMyMood = LocalCacheService.getCachedMyMood();
    if (cachedMyMood != null) {
      _myMood = MoodAura.fromJson(cachedMyMood);
    }
    final cachedPartnerMood = LocalCacheService.getCachedPartnerMood();
    if (cachedPartnerMood != null) {
      _partnerMood = MoodAura.fromJson(cachedPartnerMood);
    }
    final cachedPrompt = LocalCacheService.getCachedDailyPrompt();
    if (cachedPrompt != null) {
      _dailyPrompt = DailyPrompt.fromJson(cachedPrompt);
    }
    final cachedNotes = LocalCacheService.getCachedPinnedNotes();
    if (cachedNotes != null) {
      _pinnedNotes = cachedNotes.map(
        (k, v) => MapEntry(k, PinnedNote.fromJson(Map<String, dynamic>.from(v as Map))),
      );
    }
    _loadTouchMetrics();
    _syncWidget(null);
  }

  /// Wipes ALL in-memory state when user logs out.
  /// Called by AuthProvider.signOut() before FirebaseService.signOut().
  void resetState() {
    _anniversarySub?.cancel();
    _moodSub?.cancel();
    _noteSub?.cancel();
    _dailyPromptSub?.cancel();
    _promptHistorySub?.cancel();
    _goalsSub?.cancel();
    _dailyCareSub?.cancel();
    _pulseSub?.cancel();
    _heartbeatSub?.cancel();
    _touchStatsSub?.cancel();
    _gentleModeSub?.cancel();
    _drawingSaveDebounce?.cancel();
    _partnerTouchDecayTimer?.cancel();
    _batterySyncTimer?.cancel();
    _batterySyncTimer = null;
    _partnerBattery = null;
    _partnerTelemetry = null;
    _myTelemetry = null;
    _partnerDailySummaries = [];
    _myDailySummaries = [];
    _lastTelemetrySyncError = null;
    _secretWhispers = [];
    _anniversarySub = null;
    _moodSub = null;
    _noteSub = null;
    _dailyPromptSub = null;
    _promptHistorySub = null;
    _goalsSub = null;
    _dailyCareSub = null;
    _pulseSub = null;
    _heartbeatSub = null;
    _touchStatsSub = null;
    _gentleModeSub = null;

    _anniversaryDate = null;
    _myMood = null;
    _partnerMood = null;
    _dailyPrompt = null;
    _promptHistory = [];
    _pinnedNotes = {};
    _goals = [];
    _dailyCareItems = [];
    _deletedGoalIds.clear();
    _deletedCareIds.clear();
    _drawingStrokes.clear();
    _touchPoints.clear();
    _partnerTouchPoint = null;
    _isPulsing = false;
    _myDailyTouches = 0;
    _partnerDailyTouches = 0;
    _weeklyTouches = 0;
    _activeSpaceId = null;
    _activeUserId = null;
    _activePartnerId = null;
    notifyListeners();
  }

  /// Wipes ALL partner-specific live telemetry, battery, mood, and notes immediately on unpair.
  void clearPartnerState() {
    _partnerMood = null;
    _partnerTouchPoint = null;
    _partnerDailyTouches = 0;
    _partnerBattery = null;
    _partnerTelemetry = null;
    _partnerDailySummaries = [];
    if (_activeUserId != null && _activeUserId!.isNotEmpty) {
      _pinnedNotes.removeWhere((k, _) => k != _activeUserId);
    } else {
      _pinnedNotes.clear();
    }
    _activePartnerId = null;
    LocalCacheService.setCachedPartner(null);
    LocalCacheService.setCachedPartnerMood(null);
    notifyListeners();
  }

  void _loadTouchMetrics() {
    try {
      final prefs = LocalCacheService.prefs;
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      _lastTouchDate = prefs.getString('touch_last_date') ?? todayStr;

      if (_lastTouchDate != todayStr) {
        // New calendar day! Reset daily touches automatically after midnight
        _myDailyTouches = 0;
        _partnerDailyTouches = 0;
        _lastTouchDate = todayStr;
        prefs.setString('touch_last_date', todayStr);
        prefs.setInt('touch_my_daily', 0);
        prefs.setInt('touch_partner_daily', 0);
      } else {
        _myDailyTouches = prefs.getInt('touch_my_daily') ?? 0;
        _partnerDailyTouches = prefs.getInt('touch_partner_daily') ?? 0;
      }
      _weeklyTouches = prefs.getInt('touch_weekly_total') ?? (_myDailyTouches + _partnerDailyTouches);
    } catch (_) {}
  }

  void initSpaceListeners(String spaceId, String userId, String? partnerId) {
    if (spaceId.isEmpty) return;

    final isSameSpace = _activeSpaceId == spaceId &&
        _activeUserId == userId &&
        _activePartnerId == partnerId;
    if (isSameSpace && _anniversarySub != null) return;

    final partnerChanged = _activePartnerId != partnerId;
    _activeSpaceId = spaceId;
    _activeUserId = userId;
    _activePartnerId = partnerId;

    if (partnerId == null || partnerId.isEmpty || partnerChanged) {
      _partnerMood = null;
      _partnerTouchPoint = null;
      _partnerDailyTouches = 0;
      _partnerBattery = null;
      _partnerTelemetry = null;
      _partnerDailySummaries = [];
      _pinnedNotes.removeWhere((k, _) => k != userId);
      if (partnerId == null || partnerId.isEmpty) {
        LocalCacheService.setCachedPartner(null);
        LocalCacheService.setCachedPartnerMood(null);
      }
      notifyListeners();
    }

    _isTelemetrySharingEnabled = LocalCacheService.prefs.getBool('telemetry_sharing_enabled') ?? true;

    // 0. Live Partner Hardware Telemetry & Battery (100% real Android OS sensors)
    void applyPartnerTelemetry(Map<String, dynamic> data) {
      final parsed = DeviceTelemetry.fromJson(data);
      _partnerTelemetry = parsed;
      if (parsed.batteryLevel >= 0 && parsed.batteryLevel <= 100) {
        _partnerBattery = DeviceBatteryStatus(
          level: parsed.batteryLevel,
          isCharging: parsed.isCharging,
          updatedAt: parsed.updatedAt,
        );
      }
      notifyListeners();
    }

    SupabaseService.setBatteryStatusListener((data) {
      final sender = data['senderId']?.toString();
      if (_activePartnerId != null &&
          _activePartnerId!.isNotEmpty &&
          sender == _activePartnerId &&
          sender != userId) {
        final parsed = DeviceBatteryStatus.fromJson(data);
        if (parsed.level >= 0 && parsed.level <= 100) {
          _partnerBattery = parsed;
          notifyListeners();
        }
      }
    });
    SupabaseService.setDeviceTelemetryListener((data) {
      final sender = data['senderId']?.toString();
      if (_activePartnerId != null &&
          _activePartnerId!.isNotEmpty &&
          sender == _activePartnerId &&
          sender != userId) {
        if (data['disabled'] == true) {
          _partnerTelemetry = null;
          notifyListeners();
        } else {
          applyPartnerTelemetry(data);
        }
      }
    });
    SupabaseService.setSecretWhisperListener((data) {
      final list = data['whispers'] as List<dynamic>?;
      if (list != null) {
        _secretWhispers = list
            .map((e) => SecretWhisper.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        notifyListeners();
      }
    });

    if (partnerId != null && partnerId.isNotEmpty) {
      SupabaseService.getAppContent('telemetry_${spaceId}_$partnerId').then((data) {
        if (data != null && data['disabled'] != true) {
          applyPartnerTelemetry(data);
        }
      });
      SupabaseService.getAppContent('battery_${spaceId}_$partnerId').then((data) {
        if (data != null && _partnerBattery == null) {
          final parsed = DeviceBatteryStatus.fromJson(data);
          if (parsed.level >= 0 && parsed.level <= 100) {
            _partnerBattery = parsed;
            notifyListeners();
          }
        }
      });
    }

    // Fetch Secret Whispers for this space
    SupabaseService.getAppContent('secret_whispers_$spaceId').then((data) {
      if (data != null && data['whispers'] is List) {
        _secretWhispers = (data['whispers'] as List)
            .map((e) => SecretWhisper.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        notifyListeners();
      }
    });

    // Configure native Android foreground service for background telemetry & midnight summaries
    final cachedName = LocalCacheService.getCachedUser()?['name']?.toString() ?? '';
    DeviceStatusService.configureTelemetryUpload(
      supabaseUrl: AppConstants.supabaseUrl,
      supabaseKey: AppConstants.supabaseAnonKey,
      accessToken: SupabaseService.client?.auth.currentSession?.accessToken,
      spaceId: spaceId,
      myUserId: userId,
      myName: cachedName,
    );

    if (partnerId == null || partnerId.isEmpty) {
      // Disconnected/unpaired: hide partner data while preserving own items intact
      _pinnedNotes.removeWhere((k, _) => k != userId);
      _partnerDailySummaries = [];
    } else {
      loadDailyActivitySummaries(spaceId: spaceId, userId: userId, partnerId: partnerId);
    }

    DeviceStatusService.onNowPlayingChanged = () {
      if (_activeSpaceId == spaceId && _activeUserId == userId) {
        _syncMyTelemetry(spaceId, userId);
      }
    };

    _syncMyTelemetry(spaceId, userId);
    _batterySyncTimer?.cancel();
    _batterySyncTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      if (_activeSpaceId == spaceId && _activeUserId == userId) {
        _syncMyTelemetry(spaceId, userId);
      }
    });

    // 1. Listen to Anniversary
    _anniversarySub?.cancel();
    _anniversarySub = FirebaseService.streamFeatureDoc(spaceId, 'anniversary').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final date = snap.data()!['anniversaryDate'] as String?;
        if (date != null && date.isNotEmpty && date != _anniversaryDate) {
          _anniversaryDate = date;
          LocalCacheService.setCachedAnniversary(date);
          _syncWidget(partnerId);
          notifyListeners();
        }
      } else if (partnerId != null && partnerId.isNotEmpty && (_anniversaryDate == null || _anniversaryDate!.isEmpty)) {
        // When paired with partner, automatically start counting from today if no date was set
        final now = DateTime.now();
        final todayStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        setAnniversary(spaceId, todayStr);
      }
    });

    // 2. Listen to Mood Aura (Partitioned multi-device safe merge)
    _moodSub?.cancel();
    _moodSub = FirebaseService.streamFeatureDoc(spaceId, 'mood_aura').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final moods = data['mood'] is Map ? Map<String, dynamic>.from(data['mood'] as Map) : data;

        if (moods.containsKey(userId) && moods[userId] is Map) {
          final myData = Map<String, dynamic>.from(moods[userId] as Map);
          _myMood = MoodAura.fromJson(myData);
          LocalCacheService.setCachedMyMood(myData);
        }

        if (partnerId != null && partnerId.isNotEmpty && moods.containsKey(partnerId) && moods[partnerId] is Map) {
          final pData = Map<String, dynamic>.from(moods[partnerId] as Map);
          _partnerMood = MoodAura.fromJson(pData);
          LocalCacheService.setCachedPartnerMood(pData);
        } else {
          _partnerMood = null;
          LocalCacheService.setCachedPartnerMood(null);
        }
        notifyListeners();
      }
    });

    // 3. Listen to Pinned Notes (Partitioned multi-device safe merge)
    _noteSub?.cancel();
    _noteSub = FirebaseService.streamFeatureDoc(spaceId, 'pinned_note').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final rawNotes = data['notes'] is Map ? Map<String, dynamic>.from(data['notes'] as Map) : data;
        _mergeRawPinnedNotes(rawNotes, userId: userId, partnerId: partnerId, spaceId: spaceId);
      }
    });

    // Supabase app_content fast-fetch for pinned notes (survives re-logins)
    _fetchPinnedNotesFromSupabase(spaceId: spaceId, userId: userId, partnerId: partnerId);

    // 4. Listen to Daily Blind Prompt
    _dailyPromptSub?.cancel();
    _dailyPromptSub = FirebaseService.streamFeatureDoc(spaceId, 'daily_prompt').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final parsed = DailyPrompt.fromJson(snap.data()!);
        _applyMergedDailyPrompt(parsed, spaceId);
      } else if (partnerId != null && partnerId.isNotEmpty && _dailyPrompt == null) {
        // Paired, but no prompt exists yet in space: establish shared prompt
        final todayStr = DateTime.now().toIso8601String().split('T').first;
        final defaultPrompt = DailyPrompt(
          id: todayStr,
          prompt: 'What was the sweetest little thought you had about us today?',
          category: 'Soft Affection',
          vibeTag: 'Gentle Whisper',
          answers: {},
          reveals: {},
          careChecks: {},
        );
        _dailyPrompt = defaultPrompt;
        LocalCacheService.setCachedDailyPrompt(defaultPrompt.toJson());
        FirebaseService.saveFeatureDoc(spaceId, 'daily_prompt', defaultPrompt.toJson());
        SupabaseService.upsertAppContent('daily_prompt_$spaceId', defaultPrompt.toJson());
        notifyListeners();
      }
    });

    // Supabase app_content fast-fetch for daily_prompt
    _fetchDailyPromptFromSupabase(spaceId);

    // 4b. Listen to Prompt History
    _promptHistorySub?.cancel();
    _promptHistorySub = FirebaseService.streamFeatureDoc(spaceId, 'prompt_history').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final list = snap.data()!['history'] as List?;
        if (list != null) {
          _promptHistory = list
              .map((e) => PromptHistoryItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          notifyListeners();
        }
      }
    });

    // 5. Goals Live Listener
    _goalsSub?.cancel();
    _goalsSub = FirebaseService.streamFeatureDoc(spaceId, 'couple_goals').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final list = snap.data()!['goals'] as List?;
        if (list != null && list.isNotEmpty) {
          final incoming = list
              .map((e) => CoupleGoalItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _mergeGoals(incoming);
        }
      }
    });
    fetchGoals(spaceId);

    // 5.5 Daily Care Schedules Live Listener (Auto-schedules alarms on both partner phones)
    final cachedPartner = LocalCacheService.getCachedPartner();
    final partnerNickname = cachedPartner?['nickname']?.toString() ?? 'Partner';

    _dailyCareSub?.cancel();
    _dailyCareSub = FirebaseService.streamFeatureDoc(spaceId, 'daily_care_schedules').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final list = data['care_items'] as List?;
        final cloudDeleted = (data['deleted_care_ids'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.isNotEmpty)
                .toSet() ??
            const <String>{};
        if (list != null) {
          final incoming = list
              .map((e) => DailyCareItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _mergeDailyCareItems(
            incoming,
            currentUserId: userId,
            partnerName: partnerNickname,
            cloudDeletedIds: cloudDeleted,
            replaceMissing: true,
          );

          // Check if partner just scheduled a new care item or nudged me right now
          final sender = data['senderId'] as String?;
          final target = data['targetUserId'] as String?;
          final action = data['lastAction'] as String?;
          final itemTitle = data['lastItemTitle'] as String?;
          final itemTime = data['lastItemTime'] as String?;

          if (sender != null && sender != userId && (target == null || target == userId || target.isEmpty)) {
            final now = DateTime.now();
            final updatedStr = data['updatedAt'] as String?;
            final updatedTime = updatedStr != null ? DateTime.tryParse(updatedStr) : null;
            if (updatedTime != null && now.difference(updatedTime).inMinutes < 2) {
              if (action == 'new_care' && itemTitle != null) {
                NotificationService.showInstantDailyCareScheduledNotification(
                  partnerName: partnerNickname,
                  careTitle: itemTitle,
                  scheduledTime: itemTime ?? '',
                );
              } else if (action == 'nudge' && itemTitle != null) {
                NotificationService.showInstantDailyCareNudgeNotification(
                  partnerName: partnerNickname,
                  careTitle: itemTitle,
                );
              }
            }
          }

          notifyListeners();
        }
      }
    });
    fetchDailyCare(spaceId, currentUserId: userId, partnerName: partnerNickname);

    // 6. Dual Pulse Live Listener (Guaranteed delivery if socket packet dropped)
    _pulseSub?.cancel();
    _pulseSub = FirebaseService.streamFeatureDoc(spaceId, 'live_pulse').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final sender = data['senderId'] as String?;
        final ts = (data['timestamp'] as num?)?.toInt() ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (sender != userId && (now - ts).abs() < 5000 && ts != _lastPulseTimestamp) {
          _lastPulseTimestamp = ts;
          _triggerPulseEffect();
        }
      }
    });

    // 6b. Dual Heartbeat Live Listener (Zero-Pressure Silent Handhold Fallback)
    _heartbeatSub?.cancel();
    _heartbeatSub = FirebaseService.streamFeatureDoc(spaceId, 'live_heartbeat').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final sender = data['senderId'] as String?;
        final ts = (data['timestamp'] as num?)?.toInt() ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (sender != userId && (now - ts).abs() < 5000 && ts != _lastHeartbeatTimestamp) {
          _lastHeartbeatTimestamp = ts;
          _triggerHeartbeatEffect(isRemote: true);
        }
      }
    });

    // 7. Touch Stats Listener (Daily counts)
    _touchStatsSub?.cancel();
    _touchStatsSub = FirebaseService.streamFeatureDoc(spaceId, 'touch_stats').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final touches = data['touches'] as Map<String, dynamic>? ?? {};
        if (partnerId != null && touches.containsKey(partnerId)) {
          _partnerDailyTouches = (touches[partnerId] as num).toInt();
        } else {
          for (final entry in touches.entries) {
            if (entry.key != userId && entry.value is num) {
              _partnerDailyTouches = (entry.value as num).toInt();
              break;
            }
          }
        }
        _weeklyTouches = _myDailyTouches + _partnerDailyTouches;
        _syncWidget(partnerId);
        notifyListeners();
      }
    });

    // 7b. Gentle Mode Listener (Zero-pressure recharging presence)
    _isGentleMode = LocalCacheService.prefs.getBool('gentle_mode') ?? false;
    NotificationService.setGentleMode(_isGentleMode);
    _gentleModeSub?.cancel();
    _gentleModeSub = FirebaseService.streamFeatureDoc(spaceId, 'gentle_modes').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        final modes = data['modes'] as Map<String, dynamic>? ?? {};
        if (partnerId != null && modes.containsKey(partnerId)) {
          _partnerGentleMode = modes[partnerId] == true;
          notifyListeners();
        }
      }
    });

    // 8. Fetch Cached Drawing Canvas
    SupabaseService.getAppContent('drawing_$spaceId').then((content) {
      if (content != null && content['strokes'] is List) {
        final list = content['strokes'] as List;
        _drawingStrokes.clear();
        for (final s in list) {
          if (s is Map) {
            _drawingStrokes.add(DrawingStroke.fromJson(
              Map<String, dynamic>.from(s),
              currentUserId: userId,
            ));
          }
        }
        notifyListeners();
      }
    });

    // 9. Supabase Realtime Broadcast for Live Touch, Pulses & Drawings
    SupabaseService.subscribeToSpaceEvents(
      spaceId,
      onPulse: (data) {
        final sender = data['senderId'] as String?;
        final ts = (data['timestamp'] as num?)?.toInt() ?? 0;
        if (sender != userId && ts != _lastPulseTimestamp) {
          _lastPulseTimestamp = ts;
          _triggerPulseEffect();
        }
      },
      onHeartbeatPulse: (data) {
        final sender = data['senderId'] as String?;
        final ts = (data['timestamp'] as num?)?.toInt() ?? 0;
        if (sender != userId && ts != _lastHeartbeatTimestamp) {
          _lastHeartbeatTimestamp = ts;
          _triggerHeartbeatEffect(isRemote: true);
        }
      },
      onMood: (data) {
        final sender = data['senderId'] as String?;
        if (sender != userId && data['mood'] != null) {
          _partnerMood = MoodAura.fromJson(Map<String, dynamic>.from(data['mood'] as Map));
          HapticFeedback.mediumImpact();
          notifyListeners();
        }
      },
      onTouchPad: (data) {
        final sender = data['senderId'] as String?;
        if (sender != userId) {
          final isTouching = data['isTouching'] as bool? ?? true;
          if (isTouching) {
            final x = (data['x'] as num?)?.toDouble() ?? 0.5;
            final y = (data['y'] as num?)?.toDouble() ?? 0.5;
            _partnerTouchPoint = TouchPoint(x: x, y: y, timestamp: DateTime.now().millisecondsSinceEpoch);
            _touchPoints.clear();
            _touchPoints.add(_partnerTouchPoint!);
            HapticFeedback.lightImpact();
            _partnerTouchDecayTimer?.cancel();
            _partnerTouchDecayTimer = Timer(const Duration(milliseconds: 2500), () {
              _partnerTouchPoint = null;
              _touchPoints.clear();
              notifyListeners();
            });
            notifyListeners();
          } else {
            _partnerTouchPoint = null;
            _touchPoints.clear();
            _partnerTouchDecayTimer?.cancel();
            notifyListeners();
          }
        }
      },
      onDrawStroke: (data) {
        final sender = data['senderId'] as String?;
        if (sender != userId && data['stroke'] != null) {
          final stroke = DrawingStroke.fromJson(
            Map<String, dynamic>.from(data['stroke'] as Map),
            isPartner: true,
            currentUserId: userId,
          );
          _drawingStrokes.add(stroke);
          notifyListeners();
        }
      },
      onSyncDrawing: (data) {
        final sender = data['senderId'] as String?;
        if (sender != userId && data['strokes'] is List) {
          final list = (data['strokes'] as List)
              .map((e) => DrawingStroke.fromJson(Map<String, dynamic>.from(e as Map), currentUserId: userId))
              .toList();
          _drawingStrokes.clear();
          _drawingStrokes.addAll(list);
          notifyListeners();
        }
      },
      onClearDrawing: (data) {
        final sender = data['senderId'] as String?;
        if (sender != userId) {
          _drawingStrokes.clear();
          notifyListeners();
        }
      },
      onTouchCountSync: (data) {
        final sender = data['senderId'] as String?;
        if (sender != userId && data['count'] != null) {
          _partnerDailyTouches = (data['count'] as num).toInt();
          _weeklyTouches = _myDailyTouches + _partnerDailyTouches;
          try {
            LocalCacheService.prefs.setInt('touch_partner_daily', _partnerDailyTouches);
          } catch (_) {}
          notifyListeners();
        }
      },
      onDailyPrompt: (data) {
        final promptData = data['dailyPrompt'] as Map<String, dynamic>?;
        if (promptData != null) {
          _dailyPrompt = DailyPrompt.fromJson(promptData);
          LocalCacheService.setCachedDailyPrompt(promptData);

          // 7th: Partner answered notification
          final sender = data['senderId'] as String?;
          if (sender != null && sender != userId) {
            NotificationService.showPartnerAnsweredDailyQuestionNotification(
              partnerNickname: 'Partner',
            );
          }

          // Evaluate daily pending question reminder
          final hasUserAnswered = _dailyPrompt?.answers[userId]?.isNotEmpty ?? false;
          NotificationService.scheduleDailyQuestionPendingReminder(
            hasUserAnswered: hasUserAnswered,
            partnerNickname: 'Partner',
          );

          notifyListeners();
        }
      },
      onPinnedNote: (data) async {
        final sender = data['senderId'] as String?;
        if (sender != userId && data['note'] != null) {
          final note = PinnedNote.fromJson(Map<String, dynamic>.from(data['note'] as Map));
          _pinnedNotes[note.userId] = note;
          await LocalCacheService.setCachedPinnedNotes(
            _pinnedNotes.map((k, v) => MapEntry(k, v.toJson())),
          );
          _syncWidget(partnerId);
          notifyListeners();
        }
      },
      onListenInvite: (data) {
        final sender = data['senderId'] as String?;
        if (sender != userId) {
          NotificationService.showListenTogetherInviteNotification(
            partnerNickname: data['senderNickname'] ?? 'Partner',
            songTitle: data['songTitle'] ?? 'Music',
            artist: data['artist'] ?? '',
          );
        }
      },
      onGentleMode: (data) {
        final sender = data['senderId'] as String?;
        if (sender != userId && data['isGentleMode'] != null) {
          _partnerGentleMode = data['isGentleMode'] == true;
          notifyListeners();
        }
      },
    );
  }

  void _triggerPulseEffect() {
    _isPulsing = true;
    HapticFeedback.mediumImpact();
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 850), () {
      _isPulsing = false;
      notifyListeners();
    });
  }

  /// Zero-Pressure Heartbeat Pulse: Plays rhythmic tactile lub-dub haptics
  /// and increments isolated ValueNotifier without forcing a full screen rebuild.
  void _triggerHeartbeatEffect({bool isRemote = false}) {
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 140), () {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    });

    heartbeatPulseNotifier.value++;
    isHeartbeatActiveNotifier.value = true;
    Future.delayed(const Duration(milliseconds: 1400), () {
      isHeartbeatActiveNotifier.value = false;
    });
  }

  /// Sends a gentle "Thinking of You" Heartbeat Pulse over Supabase Realtime broadcast.
  /// Zero-pressure presence: provides silent tactile connection without requiring words.
  Future<void> sendHeartbeatPulse(String spaceId, String userId, String nickname) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastHeartbeatTimestamp = now;
    _triggerHeartbeatEffect(isRemote: false);

    // 1. Instant WebSocket broadcast (0-50ms)
    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'HEARTBEAT_PULSE',
      payload: {
        'senderId': userId,
        'senderNickname': nickname,
        'timestamp': now,
      },
    );

    // 2. Dual Firestore live pulse (Guaranteed delivery if socket drops)
    try {
      await FirebaseService.saveFeatureDoc(spaceId, 'live_heartbeat', {
        'senderId': userId,
        'senderNickname': nickname,
        'timestamp': now,
      });
    } catch (_) {}
  }

  /// Toggles Gentle Sanctuary / Quiet Shell mode.
  /// Mutes non-critical alerts & vibrations, lets partner know you are resting
  /// with no pressure to talk or respond.
  Future<void> toggleGentleMode(String spaceId, String userId) async {
    _isGentleMode = !_isGentleMode;
    NotificationService.setGentleMode(_isGentleMode);
    notifyListeners();

    try {
      await LocalCacheService.prefs.setBool('gentle_mode', _isGentleMode);
    } catch (_) {}

    // 1. Instant WebSocket broadcast to partner
    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'GENTLE_MODE_UPDATE',
      payload: {
        'senderId': userId,
        'isGentleMode': _isGentleMode,
      },
    );

    // 2. Dual Firestore sync for offline/cross-device continuity
    try {
      await FirebaseService.saveNestedFeatureField(
        spaceId,
        'gentle_modes',
        'modes.$userId',
        _isGentleMode,
      );
    } catch (_) {}
  }

  void _syncWidget(String? partnerId) {
    String? thought;
    if (partnerId != null && _pinnedNotes.containsKey(partnerId)) {
      thought = _pinnedNotes[partnerId]?.text;
    }
    final careLines = _dailyCareItems.map((c) {
      final cleanTitle = c.title.replaceAll(c.icon, '').trim();
      return '${c.icon} $cleanTitle';
    }).take(3).toList();
    WidgetSyncService.syncWidget(
      partnerThought: thought,
      daysTogether: daysTogether,
      missYouCount: _partnerDailyTouches + _myDailyTouches,
      careLines: careLines.isNotEmpty ? careLines : null,
    );
  }

  Future<void> sendPulse(String spaceId, String userId, String nickname) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastPulseTimestamp = now;
    _triggerPulseEffect();

    // 1. Instant WebSocket broadcast
    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'PULSE',
      payload: {
        'senderId': userId,
        'senderNickname': nickname,
        'timestamp': now,
      },
    );

    // 2. Dual Firestore live pulse (100% delivery guarantee)
    try {
      await FirebaseService.saveFeatureDoc(spaceId, 'live_pulse', {
        'senderId': userId,
        'senderNickname': nickname,
        'timestamp': now,
      });
    } catch (_) {}
  }

  Future<void> sendTouchPadEvent(String spaceId, String userId, double x, double y, {bool isTouching = true}) async {
    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'TOUCH_PAD_EVENT',
      payload: {'senderId': userId, 'x': x, 'y': y, 'isTouching': isTouching},
    );
  }

  Future<void> incrementMyTouch(String spaceId, String userId, String partnerNickname) async {
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    if (_lastTouchDate != todayStr) {
      _myDailyTouches = 0;
      _partnerDailyTouches = 0;
      _lastTouchDate = todayStr;
    }

    _myDailyTouches++;
    _weeklyTouches++;

    try {
      final prefs = LocalCacheService.prefs;
      prefs.setString('touch_last_date', todayStr);
      prefs.setInt('touch_my_daily', _myDailyTouches);
      prefs.setInt('touch_weekly_total', _weeklyTouches);
    } catch (_) {}

    notifyListeners();

    // 1. Broadcast count to partner
    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'TOUCH_COUNT_SYNC',
      payload: {'senderId': userId, 'count': _myDailyTouches, 'date': todayStr},
    );

    // 2. Dual Firestore sync for persistent touches
    await FirebaseService.saveNestedFeatureField(
      spaceId,
      'touch_stats',
      'touches.$userId',
      _myDailyTouches,
    );

    // Schedule weekly reminder notification
    await NotificationService.scheduleWeeklyMissYouNotification(
      weeklyTouches: _weeklyTouches,
      partnerNickname: partnerNickname,
    );
  }

  Future<void> addDrawingStroke(DrawingStroke stroke, String spaceId, String userId) async {
    final taggedStroke = (stroke.senderId == null || stroke.senderId!.isEmpty)
        ? stroke.copyWith(senderId: userId)
        : stroke;
    _drawingStrokes.add(taggedStroke);
    notifyListeners();

    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'DRAW_STROKE',
      payload: {
        'senderId': userId,
        'stroke': taggedStroke.toJson(),
      },
    );

    // Debounced canvas save (max 80 strokes)
    _drawingSaveDebounce?.cancel();
    _drawingSaveDebounce = Timer(const Duration(milliseconds: 1500), () {
      final toSave = _drawingStrokes.length > 80
          ? _drawingStrokes.sublist(_drawingStrokes.length - 80)
          : _drawingStrokes;
      SupabaseService.upsertAppContent('drawing_$spaceId', {
        'strokes': toSave.map((s) => s.toJson()).toList(),
      });
    });
  }

  Future<void> eraseStrokesNear(double nx, double ny, double radius, String spaceId, String userId) async {
    final beforeCount = _drawingStrokes.length;
    final rSq = radius * radius;
    _drawingStrokes.removeWhere((stroke) {
      // The eraser tool only rubs away the user's own strokes so partner's art is never accidentally wiped
      if (stroke.isPartner || (stroke.senderId != null && stroke.senderId != userId)) {
        return false;
      }
      for (final pt in stroke.points) {
        final dx = pt.x - nx;
        final dy = pt.y - ny;
        if ((dx * dx + dy * dy) <= rSq) {
          return true;
        }
      }
      return false;
    });

    if (_drawingStrokes.length != beforeCount) {
      notifyListeners();
      HapticFeedback.selectionClick();

      _drawingSaveDebounce?.cancel();
      _drawingSaveDebounce = Timer(const Duration(milliseconds: 800), () {
        final toSave = _drawingStrokes.length > 80
            ? _drawingStrokes.sublist(_drawingStrokes.length - 80)
            : _drawingStrokes;
        SupabaseService.upsertAppContent('drawing_$spaceId', {
          'strokes': toSave.map((s) => s.toJson()).toList(),
        });
        SupabaseService.broadcastEvent(
          spaceId: spaceId,
          eventType: 'SYNC_DRAWING',
          payload: {
            'senderId': userId,
            'strokes': toSave.map((s) => s.toJson()).toList(),
          },
        );
      });
    }
  }

  /// Erases ONLY the user's drawings, keeping partner's drawings 100% intact
  Future<void> clearMyDrawing(String spaceId, String userId) async {
    _drawingStrokes.removeWhere((stroke) {
      if (stroke.senderId != null && stroke.senderId == userId) return true;
      if (!stroke.isPartner) return true;
      return false;
    });
    notifyListeners();

    final toSave = _drawingStrokes.length > 80
        ? _drawingStrokes.sublist(_drawingStrokes.length - 80)
        : _drawingStrokes;

    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'SYNC_DRAWING',
      payload: {
        'senderId': userId,
        'strokes': toSave.map((s) => s.toJson()).toList(),
      },
    );

    await SupabaseService.upsertAppContent('drawing_$spaceId', {
      'strokes': toSave.map((s) => s.toJson()).toList(),
    });
  }

  /// Clears the entire canvas (both users' drawings)
  Future<void> clearDrawing(String spaceId, String userId) async {
    _drawingStrokes.clear();
    notifyListeners();

    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'CLEAR_DRAWING',
      payload: {'senderId': userId},
    );

    await SupabaseService.upsertAppContent('drawing_$spaceId', {'strokes': []});
  }

  Future<void> setAnniversary(String spaceId, String date) async {
    _anniversaryDate = date;
    await LocalCacheService.setCachedAnniversary(date);
    await FirebaseService.saveFeatureDoc(spaceId, 'anniversary', {'anniversaryDate': date});
    _syncWidget(null);
    notifyListeners();
  }

  Future<void> setMyMood(String spaceId, String userId, MoodAura? mood) async {
    _myMood = mood;
    await LocalCacheService.setCachedMyMood(mood?.toJson());
    notifyListeners();

    if (mood != null) {
      await FirebaseService.saveUserFeatureField(spaceId, 'mood_aura', userId, mood.toJson());
      await SupabaseService.upsertAppContent('mood_${spaceId}_$userId', mood.toJson());
      await SupabaseService.broadcastEvent(
        spaceId: spaceId,
        eventType: 'MOOD_UPDATE',
        payload: {
          'senderId': userId,
          'mood': mood.toJson(),
        },
      );
    }
  }

  Future<void> setCustomDailyPrompt({
    required String spaceId,
    required String question,
    required String vibeTag,
    required String category,
  }) async {
    final effectiveSpaceId = spaceId.isNotEmpty ? spaceId : (_activeSpaceId ?? '');
    final todayStr = DateTime.now().toIso8601String().split('T').first;

    // If current prompt has answers, archive to history first
    if (_dailyPrompt != null && _dailyPrompt!.answers.isNotEmpty && effectiveSpaceId.isNotEmpty) {
      final historyItem = PromptHistoryItem(
        id: _dailyPrompt!.id,
        question: _dailyPrompt!.prompt,
        vibeTag: _dailyPrompt!.vibeTag,
        category: _dailyPrompt!.category,
        answers: _dailyPrompt!.answers,
        date: todayStr,
      );
      _archivePromptHistory(effectiveSpaceId, historyItem);
    }

    final newPrompt = DailyPrompt(
      id: todayStr,
      prompt: question.trim(),
      category: category,
      vibeTag: vibeTag,
      answers: {},
      reveals: {},
      careChecks: {},
      createdAt: DateTime.now().toIso8601String(),
      isCustom: true,
    );

    _dailyPrompt = newPrompt;
    await LocalCacheService.setCachedDailyPrompt(newPrompt.toJson());
    notifyListeners();

    if (effectiveSpaceId.isNotEmpty) {
      // 1. Dual save: Firestore (merge: false so stale answers are wiped) & Supabase app_content
      try {
        await FirebaseService.saveFeatureDoc(effectiveSpaceId, 'daily_prompt', newPrompt.toJson(), merge: false);
        await SupabaseService.upsertAppContent('daily_prompt_$effectiveSpaceId', newPrompt.toJson());

        // 2. Broadcast to partner
        await SupabaseService.broadcastEvent(
          spaceId: effectiveSpaceId,
          eventType: 'DAILY_PROMPT_UPDATE',
          payload: {
            'senderId': _activeUserId ?? '',
            'dailyPrompt': newPrompt.toJson(),
          },
        );
      } catch (e) {
        debugPrint('Failed to sync custom daily prompt: $e');
      }
    }
  }

  DailyPrompt _handleDailyPromptRollover(DailyPrompt prompt, String spaceId) {
    final todayStr = DateTime.now().toIso8601String().split('T').first;

    // Check if the prompt is legitimately from today:
    // 1. Its ID equals today's date (todayStr)
    // 2. OR its createdAt starts with today's date
    final isFromToday = prompt.id == todayStr ||
        (prompt.createdAt != null && prompt.createdAt!.startsWith(todayStr));

    if (!isFromToday && prompt.id.isNotEmpty) {
      // It's from a previous day! Auto-archive yesterday's prompt if it had answers
      if (prompt.answers.isNotEmpty && spaceId.isNotEmpty) {
        final historyItem = PromptHistoryItem(
          id: prompt.id,
          question: prompt.prompt,
          vibeTag: prompt.vibeTag,
          category: prompt.category,
          answers: prompt.answers,
          date: prompt.id.length == 10 ? prompt.id : (prompt.createdAt?.split('T').first ?? todayStr),
        );
        _archivePromptHistory(spaceId, historyItem);
      }

      // Automatically seal a fresh daily question for today
      final curatedPool = [
        'What was the sweetest little thought you had about us today?',
        'If you could teleport anywhere with me for 1 hour tonight, where would we go?',
        'What is one tiny habit or quirk of mine that secretly makes you smile?',
        'When do you feel most deeply close and connected to my heart?',
        'What is a song, scent, or place that instantly brings me to your mind?',
        'What is a private fantasy or dream you want us to experience together?',
        'What made you fall for me all over again recently?',
      ];
      final dayIndex = DateTime.now().day % curatedPool.length;
      final freshPrompt = DailyPrompt(
        id: todayStr,
        prompt: curatedPool[dayIndex],
        category: 'Soft Affection',
        vibeTag: 'Gentle Whisper',
        answers: {},
        reveals: {},
        careChecks: {},
        createdAt: DateTime.now().toIso8601String(),
        isCustom: false,
      );

      // Save to Firebase and Supabase so both partners receive the identical prompt
      if (spaceId.isNotEmpty) {
        FirebaseService.saveFeatureDoc(spaceId, 'daily_prompt', freshPrompt.toJson(), merge: false);
        SupabaseService.upsertAppContent('daily_prompt_$spaceId', freshPrompt.toJson());
      }
      LocalCacheService.setCachedDailyPrompt(freshPrompt.toJson());
      return freshPrompt;
    }
    return prompt;
  }

  Future<void> _archivePromptHistory(String spaceId, PromptHistoryItem item) async {
    final existingIdx = _promptHistory.indexWhere((h) => h.id == item.id || h.question == item.question);
    if (existingIdx == -1) {
      _promptHistory.insert(0, item);
    } else {
      _promptHistory[existingIdx] = item;
    }
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('features')
          .doc('prompt_history')
          .set({
        'history': _promptHistory.map((h) => h.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  bool _isAllowedNoteKey(
    String key, {
    required String userId,
    String? partnerId,
    required String spaceId,
  }) {
    if (key == 'updatedAt' || key == 'updated_at' || key == 'notes') {
      return false;
    }
    return OwnershipHelper.canViewItem(
      ownerUid: OwnershipHelper.extractOwnerUid(key),
      myUid: userId,
      partnerUid: partnerId,
    );
  }

  void _mergeRawPinnedNotes(
    Map<String, dynamic> rawNotes, {
    required String userId,
    String? partnerId,
    required String spaceId,
  }) {
    bool changed = false;
    final updated = Map<String, PinnedNote>.from(_pinnedNotes);
    rawNotes.forEach((k, v) {
      if (v is Map &&
          _isAllowedNoteKey(k, userId: userId, partnerId: partnerId, spaceId: spaceId)) {
        try {
          updated[k] = PinnedNote.fromJson(Map<String, dynamic>.from(v));
          changed = true;
        } catch (_) {}
      }
    });
    if (changed) {
      _pinnedNotes = updated;
      LocalCacheService.setCachedPinnedNotes(
        _pinnedNotes.map((k, v) => MapEntry(k, v.toJson())),
      );
      _syncWidget(partnerId);
      notifyListeners();
    }
  }

  Future<void> _fetchPinnedNotesFromSupabase({
    required String spaceId,
    required String userId,
    String? partnerId,
  }) async {
    try {
      final client = SupabaseService.client;
      if (client == null) return;

      final res = await client
          .from('app_content')
          .select('content')
          .eq('id', 'pinned_notes_$spaceId')
          .maybeSingle();
      if (res != null && res['content'] != null && res['content'] is Map) {
        final data = Map<String, dynamic>.from(res['content'] as Map);
        final rawNotes = data['notes'] is Map
            ? Map<String, dynamic>.from(data['notes'] as Map)
            : data;
        _mergeRawPinnedNotes(rawNotes, userId: userId, partnerId: partnerId, spaceId: spaceId);
      }

      final myRes = await client
          .from('app_content')
          .select('content')
          .eq('id', 'pinned_note_${spaceId}_$userId')
          .maybeSingle();
      if (myRes != null && myRes['content'] is Map) {
        final note = PinnedNote.fromJson(Map<String, dynamic>.from(myRes['content'] as Map));
        if (note.text.isNotEmpty &&
            (!_pinnedNotes.containsKey(userId) || _pinnedNotes[userId]!.text.isEmpty)) {
          _pinnedNotes[userId] = note;
          await LocalCacheService.setCachedPinnedNotes(
            _pinnedNotes.map((k, v) => MapEntry(k, v.toJson())),
          );
          _syncWidget(partnerId);
          notifyListeners();
        }
      }

      if (partnerId != null && partnerId.isNotEmpty) {
        final pRes = await client
            .from('app_content')
            .select('content')
            .eq('id', 'pinned_note_${spaceId}_$partnerId')
            .maybeSingle();
        if (pRes != null && pRes['content'] is Map) {
          final note = PinnedNote.fromJson(Map<String, dynamic>.from(pRes['content'] as Map));
          if (note.text.isNotEmpty &&
              (!_pinnedNotes.containsKey(partnerId) || _pinnedNotes[partnerId]!.text.isEmpty)) {
            _pinnedNotes[partnerId] = note;
            await LocalCacheService.setCachedPinnedNotes(
              _pinnedNotes.map((k, v) => MapEntry(k, v.toJson())),
            );
            _syncWidget(partnerId);
            notifyListeners();
          }
        }
      }
    } catch (_) {}
  }

  void _applyMergedDailyPrompt(DailyPrompt parsed, String spaceId) {
    final existing = _dailyPrompt;
    DailyPrompt candidate = parsed;
    if (existing != null && existing.id == parsed.id) {
      final mergedAnswers = <String, String>{...existing.answers, ...parsed.answers};
      final mergedReveals = <String, bool>{...existing.reveals, ...parsed.reveals};
      final mergedChecks = <String, Map<String, dynamic>>{
        ...existing.careChecks,
        ...parsed.careChecks,
      };
      candidate = DailyPrompt(
        id: parsed.id,
        prompt: parsed.prompt.isNotEmpty ? parsed.prompt : existing.prompt,
        category: parsed.category.isNotEmpty ? parsed.category : existing.category,
        vibeTag: parsed.vibeTag.isNotEmpty ? parsed.vibeTag : existing.vibeTag,
        answers: mergedAnswers,
        reveals: mergedReveals,
        careChecks: mergedChecks,
        createdAt: parsed.createdAt ?? existing.createdAt,
        isCustom: parsed.isCustom || existing.isCustom,
      );
    }
    _dailyPrompt = _handleDailyPromptRollover(candidate, spaceId);
    LocalCacheService.setCachedDailyPrompt(_dailyPrompt!.toJson());
    notifyListeners();
  }

  Future<void> _fetchDailyPromptFromSupabase(String spaceId) async {
    try {
      final client = SupabaseService.client;
      if (client == null) return;
      final res = await client
          .from('app_content')
          .select('content')
          .eq('id', 'daily_prompt_$spaceId')
          .maybeSingle();
      if (res != null && res['content'] != null && res['content'] is Map) {
        final promptMap = Map<String, dynamic>.from(res['content'] as Map);
        final parsed = DailyPrompt.fromJson(promptMap);
        _applyMergedDailyPrompt(parsed, spaceId);
      }
    } catch (_) {}
  }

  /// Re-fetches all shared Stage data when the app resumes to foreground.
  Future<void> refreshSharedStageData() async {
    final spaceId = _activeSpaceId;
    final userId = _activeUserId;
    if (spaceId == null || userId == null) return;
    final cachedPartner = LocalCacheService.getCachedPartner();
    final partnerNickname = cachedPartner?['nickname']?.toString() ?? 'Partner';
    await Future.wait([
      _fetchPinnedNotesFromSupabase(
        spaceId: spaceId,
        userId: userId,
        partnerId: _activePartnerId,
      ),
      _fetchDailyPromptFromSupabase(spaceId),
      fetchGoals(spaceId),
      fetchDailyCare(
        spaceId,
        currentUserId: userId,
        partnerName: partnerNickname,
      ),
    ]);
  }

  Future<void> saveDailyPromptAnswer(String spaceId, String userId, String answer) async {
    var currentPrompt = _dailyPrompt ?? DailyPrompt(
      id: DateTime.now().toIso8601String().split('T').first,
      prompt: 'What was the sweetest little thought you had about us today?',
      category: 'Soft Affection',
      vibeTag: 'Gentle Whisper',
      answers: {},
      reveals: {},
      careChecks: {},
    );

    final updatedAnswers = Map<String, String>.from(currentPrompt.answers);
    // Merge remote answers for same prompt ID so concurrent partner answers aren't overwritten
    try {
      final remote = await SupabaseService.getAppContent('daily_prompt_$spaceId');
      if (remote != null && remote['id']?.toString() == currentPrompt.id && remote['answers'] is Map) {
        (remote['answers'] as Map).forEach((k, v) {
          if (v != null && k.toString() != userId) {
            updatedAnswers[k.toString()] = v.toString();
          }
        });
      }
    } catch (_) {}
    updatedAnswers[userId] = answer;

    final updatedPrompt = DailyPrompt(
      id: currentPrompt.id.isNotEmpty ? currentPrompt.id : DateTime.now().toIso8601String().split('T').first,
      prompt: currentPrompt.prompt,
      category: currentPrompt.category,
      vibeTag: currentPrompt.vibeTag,
      answers: updatedAnswers,
      reveals: currentPrompt.reveals,
      careChecks: currentPrompt.careChecks,
    );

    _dailyPrompt = updatedPrompt;
    await LocalCacheService.setCachedDailyPrompt(updatedPrompt.toJson());
    notifyListeners();

    // 7th: Since user has answered, cancel the pending reminder!
    NotificationService.scheduleDailyQuestionPendingReminder(
      hasUserAnswered: true,
      partnerNickname: _activePartnerId ?? 'Partner',
    );

    // If both partners have now answered, auto-archive to history!
    if (updatedAnswers.length > 1) {
      final historyItem = PromptHistoryItem(
        id: updatedPrompt.id,
        question: updatedPrompt.prompt,
        vibeTag: updatedPrompt.vibeTag,
        category: updatedPrompt.category,
        answers: updatedAnswers,
        date: DateTime.now().toIso8601String().split('T').first,
      );
      _archivePromptHistory(spaceId, historyItem);
    }

    await FirebaseService.saveNestedFeatureField(
      spaceId,
      'daily_prompt',
      'answers.$userId',
      answer,
      rootDefaults: updatedPrompt.toJson(),
    );
    await SupabaseService.upsertAppContent('daily_prompt_$spaceId', updatedPrompt.toJson());
    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'DAILY_PROMPT_UPDATE',
      payload: {
        'senderId': userId,
        'dailyPrompt': updatedPrompt.toJson(),
      },
    );
  }

  Future<void> savePinnedNote(String spaceId, String userId, String nickname, String text) async {
    final note = PinnedNote(
      userId: userId,
      authorNickname: nickname,
      text: text,
      updatedAt: DateTime.now().toIso8601String(),
    );
    try {
      final remote = await SupabaseService.getAppContent('pinned_notes_$spaceId');
      if (remote != null) {
        final rawNotes = remote['notes'] is Map
            ? Map<String, dynamic>.from(remote['notes'] as Map)
            : remote;
        _mergeRawPinnedNotes(
          rawNotes,
          userId: userId,
          partnerId: _activePartnerId,
          spaceId: spaceId,
        );
      }
    } catch (_) {}
    _pinnedNotes[userId] = note;
    await LocalCacheService.setCachedPinnedNotes(
      _pinnedNotes.map((k, v) => MapEntry(k, v.toJson())),
    );
    _syncWidget(_activePartnerId);
    notifyListeners();

    await FirebaseService.saveUserFeatureField(spaceId, 'pinned_note', userId, note.toJson());
    await SupabaseService.upsertAppContent('pinned_note_${spaceId}_$userId', note.toJson());
    await SupabaseService.upsertAppContent('pinned_notes_$spaceId', {
      'notes': _pinnedNotes.map((k, v) => MapEntry(k, v.toJson())),
      'updated_at': DateTime.now().toIso8601String(),
    });
    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'PINNED_NOTE_CHANGED',
      payload: {
        'senderId': userId,
        'note': note.toJson(),
      },
    );
  }

  static final List<CoupleGoalItem> defaultPresetGoals = [
    CoupleGoalItem(id: 'preset_1', title: 'Met Each Other', icon: '🌸', category: 'firsts'),
    CoupleGoalItem(id: 'preset_2', title: 'First Date', icon: '☕', category: 'firsts'),
    CoupleGoalItem(id: 'preset_3', title: 'Kissed First Time', icon: '🕊️', category: 'firsts'),
    CoupleGoalItem(id: 'preset_4', title: 'First Trip Together', icon: '✈️', category: 'firsts'),
    CoupleGoalItem(id: 'preset_5', title: 'Said "I Love You"', icon: '💌', category: 'firsts'),
    CoupleGoalItem(id: 'preset_6', title: 'Moved in Together', icon: '🏡', category: 'future'),
    CoupleGoalItem(id: 'preset_7', title: 'Got Engaged', icon: '💍', category: 'future'),
  ];

  void _mergeGoals(List<CoupleGoalItem> incoming) {
    final tombstones = DeletedIdsStore.getIds('goals');
    final mergedMap = <String, CoupleGoalItem>{};
    for (final g in _goals) {
      if (!_deletedGoalIds.contains(g.id) && !tombstones.contains(g.id)) {
        mergedMap[g.id] = g;
      }
    }
    for (final g in incoming) {
      if (!_deletedGoalIds.contains(g.id) && !tombstones.contains(g.id)) {
        final existing = mergedMap[g.id];
        // Prefer completed version if either side marked it complete
        if (existing != null && existing.isCompleted && !g.isCompleted) {
          continue;
        }
        mergedMap[g.id] = g;
      }
    }
    _goals = mergedMap.values.toList();
    final pending = _goals.where((g) => !g.isCompleted).length;
    NotificationService.scheduleWeeklyGoalReminder(pendingGoalsCount: pending);
    notifyListeners();
  }

  Future<void> fetchGoals(String spaceId) async {
    final collected = <CoupleGoalItem>[];
    final supabase = SupabaseService.client;
    if (supabase != null) {
      try {
        final res = await supabase
            .from('app_content')
            .select('content')
            .eq('id', 'couple_goals_$spaceId')
            .maybeSingle();
        if (res != null && res['content'] != null && res['content'] is List) {
          for (final e in (res['content'] as List)) {
            if (e is Map) {
              collected.add(CoupleGoalItem.fromJson(Map<String, dynamic>.from(e)));
            }
          }
        }
      } catch (_) {}
    }
    try {
      final fsSnap = await FirebaseService.firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('features')
          .doc('couple_goals')
          .get();
      final list = fsSnap.data()?['goals'] as List?;
      if (list != null) {
        for (final e in list) {
          if (e is Map) {
            collected.add(CoupleGoalItem.fromJson(Map<String, dynamic>.from(e)));
          }
        }
      }
    } catch (_) {}

    if (collected.isNotEmpty) {
      _mergeGoals(collected);
      return;
    }
    if (_goals.isEmpty) {
      _goals = List.from(defaultPresetGoals);
    }
    final pending = _goals.where((g) => !g.isCompleted).length;
    NotificationService.scheduleWeeklyGoalReminder(pendingGoalsCount: pending);
    notifyListeners();
  }

  Future<void> toggleGoal(String spaceId, String goalId, bool isCompleted, String? nickname) async {
    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx != -1) {
      _goals[idx] = _goals[idx].copyWith(
        isCompleted: isCompleted,
        completedDate: isCompleted ? DateTime.now().toIso8601String().split('T')[0] : null,
        completedBy: isCompleted ? nickname : null,
      );
      notifyListeners();
      _syncGoalsToCloud(spaceId);
    }
  }

  Future<void> addGoal(String spaceId, CoupleGoalItem goal) async {
    _deletedGoalIds.remove(goal.id);
    _goals.add(goal);
    notifyListeners();
    _syncGoalsToCloud(spaceId);
  }

  Future<bool> deleteGoal(String spaceId, String goalId) async {
    final prev = List<CoupleGoalItem>.from(_goals);
    _deletedGoalIds.add(goalId);
    await DeletedIdsStore.markDeleted('goals', goalId);
    _goals.removeWhere((g) => g.id == goalId);
    final ok = await _syncGoalsToCloud(spaceId);
    if (!ok) {
      _goals = prev;
      _deletedGoalIds.remove(goalId);
      await DeletedIdsStore.unmarkDeleted('goals', goalId);
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  Future<bool> _syncGoalsToCloud(String spaceId) async {
    final supabase = SupabaseService.client;
    final tombstones = DeletedIdsStore.getIds('goals');
    if (supabase != null) {
      try {
        final remote = await supabase
            .from('app_content')
            .select('content')
            .eq('id', 'couple_goals_$spaceId')
            .maybeSingle();
        if (remote != null && remote['content'] is List) {
          final merged = <String, CoupleGoalItem>{};
          for (final raw in (remote['content'] as List)) {
            if (raw is Map) {
              final g = CoupleGoalItem.fromJson(Map<String, dynamic>.from(raw));
              if (!_deletedGoalIds.contains(g.id) && !tombstones.contains(g.id)) {
                merged[g.id] = g;
              }
            }
          }
          for (final g in _goals) {
            if (!_deletedGoalIds.contains(g.id) && !tombstones.contains(g.id)) {
              merged[g.id] = g;
            }
          }
          _goals = merged.values.toList();
          notifyListeners();
        }
      } catch (_) {}
    }

    final jsonList = _goals.map((g) => g.toJson()).toList();
    bool anyOk = false;
    if (supabase != null) {
      try {
        await supabase.from('app_content').upsert({
          'id': 'couple_goals_$spaceId',
          'content': jsonList,
          'updated_at': DateTime.now().toIso8601String(),
        });
        anyOk = true;
      } catch (e) {
        await DeviceStatusService.recordSyncError('sync_goals_supabase', e.toString());
      }
    }
    try {
      await FirebaseService.saveFeatureDoc(spaceId, 'couple_goals', {
        'goals': jsonList,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      anyOk = true;
    } catch (e) {
      await DeviceStatusService.recordSyncError('sync_goals_firestore', e.toString());
    }
    return anyOk;
  }

  static final List<DailyCareItem> defaultPresetCareItems = [
    DailyCareItem(
      id: 'care_preset_1',
      title: 'Morning Hydration 💧',
      icon: '💧',
      scheduledTime: '08:30 AM',
      timeSlot: 'morning',
      caringNote: 'Drink a tall glass of warm water to wake up fresh and hydrated!',
      targetUserId: '',
      createdById: 'system',
      createdByName: 'Sanctuary Care',
    ),
    DailyCareItem(
      id: 'care_preset_2',
      title: 'Mindful Lunch & Breather 🥗',
      icon: '🥗',
      scheduledTime: '01:00 PM',
      timeSlot: 'afternoon',
      caringNote: 'Eat on time, take a deep breath, and don\'t skip lunch!',
      targetUserId: '',
      createdById: 'system',
      createdByName: 'Sanctuary Care',
    ),
    DailyCareItem(
      id: 'care_preset_3',
      title: 'Daily Vitamins & Booster 💊',
      icon: '💊',
      scheduledTime: '03:00 PM',
      timeSlot: 'afternoon',
      caringNote: 'Keep your immunity strong and stay energized.',
      targetUserId: '',
      createdById: 'system',
      createdByName: 'Sanctuary Care',
    ),
    DailyCareItem(
      id: 'care_preset_4',
      title: 'Evening Relax & Stretch 🍵',
      icon: '🍵',
      scheduledTime: '08:30 PM',
      timeSlot: 'evening',
      caringNote: 'Rest your eyes, drink warm tea, and let go of today\'s fatigue.',
      targetUserId: '',
      createdById: 'system',
      createdByName: 'Sanctuary Care',
    ),
    DailyCareItem(
      id: 'care_preset_5',
      title: 'Sweet Sleep & Peaceful Night 🌙',
      icon: '🌙',
      scheduledTime: '10:30 PM',
      timeSlot: 'night',
      caringNote: 'Sleep early and dream sweetly. You are always cherished.',
      targetUserId: '',
      createdById: 'system',
      createdByName: 'Sanctuary Care',
    ),
  ];

  void _mergeDailyCareItems(
    List<DailyCareItem> incoming, {
    String? currentUserId,
    String? partnerName,
    Set<String> cloudDeletedIds = const {},
    bool replaceMissing = false,
  }) {
    final tombstones = DeletedIdsStore.getIds('care');
    final allDeleted = {..._deletedCareIds, ...tombstones, ...cloudDeletedIds};
    for (final delId in cloudDeletedIds) {
      _deletedCareIds.add(delId);
      DeletedIdsStore.markDeleted('care', delId);
      NotificationService.cancelDailyCareNotification(delId);
    }

    final previousIds = _dailyCareItems.map((c) => c.id).toSet();
    final mergedMap = <String, DailyCareItem>{};
    if (!replaceMissing) {
      for (final c in _dailyCareItems) {
        if (!allDeleted.contains(c.id)) {
          mergedMap[c.id] = c;
        }
      }
    }
    for (final c in incoming) {
      if (!allDeleted.contains(c.id)) {
        mergedMap[c.id] = c;
      }
    }

    for (final prevId in previousIds) {
      if (!mergedMap.containsKey(prevId)) {
        NotificationService.cancelDailyCareNotification(prevId);
      }
    }

    _dailyCareItems = mergedMap.values.toList();
    NotificationService.scheduleDailyCareNotifications(
      items: _dailyCareItems,
      currentUserId: currentUserId ?? _activeUserId,
      partnerName: partnerName,
    );
    notifyListeners();
  }

  Future<void> fetchDailyCare(String spaceId, {String? currentUserId, String? partnerName}) async {
    final collected = <DailyCareItem>[];
    final supabase = SupabaseService.client;
    if (supabase != null) {
      try {
        final res = await supabase
            .from('app_content')
            .select('content')
            .eq('id', 'daily_care_$spaceId')
            .maybeSingle();
        if (res != null && res['content'] != null && res['content'] is List) {
          for (final e in (res['content'] as List)) {
            if (e is Map) {
              collected.add(DailyCareItem.fromJson(Map<String, dynamic>.from(e)));
            }
          }
        }
      } catch (_) {}
    }
    final fsDeleted = <String>{};
    try {
      final fsSnap = await FirebaseService.firestore
          .collection('spaces')
          .doc(spaceId)
          .collection('features')
          .doc('daily_care_schedules')
          .get();
      final data = fsSnap.data();
      final delList = data?['deleted_care_ids'] as List?;
      if (delList != null) {
        fsDeleted.addAll(delList.map((e) => e.toString()).where((s) => s.isNotEmpty));
      }
      final list = data?['care_items'] as List?;
      if (list != null) {
        for (final e in list) {
          if (e is Map) {
            collected.add(DailyCareItem.fromJson(Map<String, dynamic>.from(e)));
          }
        }
      }
    } catch (_) {}

    if (collected.isNotEmpty || fsDeleted.isNotEmpty) {
      _mergeDailyCareItems(
        collected,
        currentUserId: currentUserId,
        partnerName: partnerName,
        cloudDeletedIds: fsDeleted,
      );
      return;
    }
    if (_dailyCareItems.isEmpty) {
      _dailyCareItems = List.from(defaultPresetCareItems);
    }
    NotificationService.scheduleDailyCareNotifications(
      items: _dailyCareItems,
      currentUserId: currentUserId,
      partnerName: partnerName,
    );
    notifyListeners();
  }

  Future<void> toggleCareItemCompleted(
    String spaceId,
    String careId,
    bool completed,
    String completedByName,
  ) async {
    final idx = _dailyCareItems.indexWhere((c) => c.id == careId);
    if (idx != -1) {
      final todayKey = DateTime.now().toIso8601String().split('T')[0];
      _dailyCareItems[idx] = _dailyCareItems[idx].copyWith(
        isCompletedToday: completed,
        completedDateKey: completed ? todayKey : null,
        completedAt: completed ? DateTime.now().toIso8601String() : null,
        completedByName: completed ? completedByName : null,
      );
      notifyListeners();
      _syncDailyCareToCloud(spaceId);
    }
  }

  Future<void> addCareItem(String spaceId, DailyCareItem item, {String? currentUserId, String? partnerName}) async {
    _deletedCareIds.remove(item.id);
    _dailyCareItems.add(item);
    notifyListeners();
    _syncDailyCareToCloud(
      spaceId,
      senderId: currentUserId ?? item.createdById,
      lastAction: 'new_care',
      lastItemTitle: item.title,
      lastItemTime: item.scheduledTime,
      targetUserId: item.targetUserId,
    );
    NotificationService.scheduleDailyCareNotifications(
      items: _dailyCareItems,
      currentUserId: currentUserId,
      partnerName: partnerName,
    );
  }

  Future<void> updateCareItem(String spaceId, DailyCareItem item, {String? currentUserId, String? partnerName}) async {
    final idx = _dailyCareItems.indexWhere((c) => c.id == item.id);
    if (idx != -1) {
      _dailyCareItems[idx] = item;
      notifyListeners();
      _syncDailyCareToCloud(
        spaceId,
        senderId: currentUserId ?? item.createdById,
        lastAction: 'update_care',
        lastItemTitle: item.title,
        lastItemTime: item.scheduledTime,
        targetUserId: item.targetUserId,
      );
      NotificationService.scheduleDailyCareNotifications(
        items: _dailyCareItems,
        currentUserId: currentUserId,
        partnerName: partnerName,
      );
    }
  }

  Future<bool> deleteCareItem(String spaceId, String careId) async {
    final idx = _dailyCareItems.indexWhere((c) => c.id == careId);
    final target = idx != -1 ? _dailyCareItems[idx] : null;
    if (target != null &&
        _activeUserId != null &&
        _activeUserId!.isNotEmpty &&
        target.createdById.isNotEmpty &&
        target.createdById != 'system' &&
        !OwnershipHelper.canDeleteItem(ownerUid: target.createdById, myUid: _activeUserId!)) {
      return false;
    }

    final prev = List<DailyCareItem>.from(_dailyCareItems);
    _deletedCareIds.add(careId);
    await DeletedIdsStore.markDeleted('care', careId);
    await NotificationService.cancelDailyCareNotification(careId);
    _dailyCareItems.removeWhere((c) => c.id == careId);
    final ok = await _syncDailyCareToCloud(
      spaceId,
      senderId: _activeUserId,
      lastAction: 'delete_care',
    );
    if (!ok) {
      _dailyCareItems = prev;
      _deletedCareIds.remove(careId);
      await DeletedIdsStore.unmarkDeleted('care', careId);
      NotificationService.scheduleDailyCareNotifications(
        items: _dailyCareItems,
        currentUserId: _activeUserId,
      );
      notifyListeners();
      return false;
    }
    await NotificationService.scheduleDailyCareNotifications(
      items: _dailyCareItems,
      currentUserId: _activeUserId,
    );
    notifyListeners();
    return true;
  }

  Future<void> sendCareNudge(
    String spaceId,
    String careId,
    String senderName,
    String recipientName, {
    String? currentUserId,
  }) async {
    final idx = _dailyCareItems.indexWhere((c) => c.id == careId);
    if (idx != -1) {
      final item = _dailyCareItems[idx];
      final currentNudges = item.reminderNudgeCount;
      _dailyCareItems[idx] = item.copyWith(
        reminderNudgeCount: currentNudges + 1,
        lastNudgedAt: DateTime.now().toIso8601String(),
      );
      notifyListeners();
      _syncDailyCareToCloud(
        spaceId,
        senderId: currentUserId,
        lastAction: 'nudge',
        lastItemTitle: item.title,
        targetUserId: item.targetUserId,
      );
    }
  }

  Future<bool> _syncDailyCareToCloud(
    String spaceId, {
    String? senderId,
    String? lastAction,
    String? lastItemTitle,
    String? lastItemTime,
    String? targetUserId,
  }) async {
    final supabase = SupabaseService.client;
    final tombstones = {..._deletedCareIds, ...DeletedIdsStore.getIds('care')};
    if (supabase != null) {
      try {
        final remote = await supabase
            .from('app_content')
            .select('content')
            .eq('id', 'daily_care_$spaceId')
            .maybeSingle();
        if (remote != null && remote['content'] is List) {
          final merged = <String, DailyCareItem>{};
          for (final raw in (remote['content'] as List)) {
            if (raw is Map) {
              final c = DailyCareItem.fromJson(Map<String, dynamic>.from(raw));
              if (!tombstones.contains(c.id)) {
                merged[c.id] = c;
              }
            }
          }
          for (final c in _dailyCareItems) {
            if (!tombstones.contains(c.id)) {
              merged[c.id] = c;
            }
          }
          _dailyCareItems = merged.values.toList();
          notifyListeners();
        }
      } catch (_) {}
    }

    final jsonList = _dailyCareItems.map((c) => c.toJson()).toList();
    final deletedList = tombstones.take(200).toList();
    bool anyOk = false;
    if (supabase != null) {
      try {
        await supabase.from('app_content').upsert({
          'id': 'daily_care_$spaceId',
          'content': jsonList,
          'updated_at': DateTime.now().toIso8601String(),
        });
        anyOk = true;
      } catch (e) {
        await DeviceStatusService.recordSyncError('sync_care_supabase', e.toString());
      }
    }
    try {
      await FirebaseService.saveFeatureDoc(spaceId, 'daily_care_schedules', {
        'care_items': jsonList,
        'deleted_care_ids': deletedList,
        'updatedAt': DateTime.now().toIso8601String(),
        if (senderId != null) 'senderId': senderId,
        if (lastAction != null) 'lastAction': lastAction,
        if (lastItemTitle != null) 'lastItemTitle': lastItemTitle,
        if (lastItemTime != null) 'lastItemTime': lastItemTime,
        if (targetUserId != null) 'targetUserId': targetUserId,
      });
      anyOk = true;
    } catch (e) {
      await DeviceStatusService.recordSyncError('sync_care_firestore', e.toString());
    }
    return anyOk;
  }

  Future<void> setTelemetrySharingEnabled(bool enabled) async {
    _isTelemetrySharingEnabled = enabled;
    await LocalCacheService.prefs.setBool('telemetry_sharing_enabled', enabled);
    notifyListeners();
    if (_activeSpaceId != null && _activeUserId != null) {
      await _syncMyTelemetry(_activeSpaceId!, _activeUserId!);
    }
  }

  Future<void> loadDailyActivitySummaries({
    required String spaceId,
    required String userId,
    String? partnerId,
  }) async {
    try {
      final myRows = await SupabaseService.getAppContentByPrefix(
        'daily_summary_${spaceId}_${userId}_',
        limit: 35,
      );
      _myDailySummaries = myRows
          .map(DailyActivitySummary.fromJson)
          .where((s) => s.dateKey.isNotEmpty)
          .toList()
        ..sort((a, b) => b.dateKey.compareTo(a.dateKey));

      if (partnerId != null && partnerId.isNotEmpty) {
        final pRows = await SupabaseService.getAppContentByPrefix(
          'daily_summary_${spaceId}_${partnerId}_',
          limit: 35,
        );
        _partnerDailySummaries = pRows
            .map(DailyActivitySummary.fromJson)
            .where((s) => s.dateKey.isNotEmpty)
            .toList()
          ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
      }
      notifyListeners();
    } catch (e) {
      await DeviceStatusService.recordSyncError('load_daily_summaries', e.toString());
    }
  }

  Future<void> refreshPartnerTelemetryNow() async {
    if (_activeSpaceId == null || _activeUserId == null) return;
    await _syncMyTelemetry(_activeSpaceId!, _activeUserId!);
    if (_activePartnerId != null && _activePartnerId!.isNotEmpty) {
      final data = await SupabaseService.getAppContent('telemetry_${_activeSpaceId!}_${_activePartnerId!}');
      if (data != null && data['disabled'] != true) {
        final parsed = DeviceTelemetry.fromJson(data);
        _partnerTelemetry = parsed;
        if (parsed.batteryLevel >= 0 && parsed.batteryLevel <= 100) {
          _partnerBattery = DeviceBatteryStatus(
            level: parsed.batteryLevel,
            isCharging: parsed.isCharging,
            updatedAt: parsed.updatedAt,
          );
        }
        notifyListeners();
      }
      await loadDailyActivitySummaries(
        spaceId: _activeSpaceId!,
        userId: _activeUserId!,
        partnerId: _activePartnerId,
      );
    }
  }

  Future<void> _syncMyTelemetry(String spaceId, String userId) async {
    if (spaceId.isEmpty || userId.isEmpty) return;

    if (!_isTelemetrySharingEnabled) {
      final disabledPayload = {'disabled': true, 'senderId': userId};
      await SupabaseService.upsertAppContent('telemetry_${spaceId}_$userId', disabledPayload);
      await SupabaseService.broadcastEvent(
        spaceId: spaceId,
        eventType: 'DEVICE_TELEMETRY',
        payload: disabledPayload,
      );
      return;
    }

    // Flush any midnight-archived summary before syncing today's live state
    final archived = await DeviceStatusService.consumePendingDailySummary(
      userId: userId,
      spaceId: spaceId,
    );
    if (archived != null && archived.dateKey.isNotEmpty) {
      final archivedOk = await SupabaseService.upsertAppContent(
        'daily_summary_${spaceId}_${userId}_${archived.dateKey}',
        archived.toJson(),
      );
      if (!archivedOk) {
        _lastTelemetrySyncError = 'Failed to save archived summary (${archived.dateKey})';
      }
    }

    // Refresh Health Connect aggregate if user granted permission (best effort)
    await DeviceStatusService.getHealthConnectToday();

    final telemetry = await DeviceStatusService.getFullTelemetry(
      nowPlayingTitle: DeviceStatusService.currentNowPlayingTitle,
      nowPlayingArtist: DeviceStatusService.currentNowPlayingArtist,
    );
    if (telemetry == null) return;
    _myTelemetry = telemetry;

    final payload = {
      ...telemetry.toJson(),
      'senderId': userId,
    };
    final ok = await SupabaseService.upsertAppContent('telemetry_${spaceId}_$userId', payload);
    if (!ok) {
      _lastTelemetrySyncError = 'Telemetry cloud upsert failed at ${DateTime.now().toIso8601String()}';
    } else {
      _lastTelemetrySyncError = null;
    }

    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'DEVICE_TELEMETRY',
      payload: payload,
    );

    if (telemetry.batteryLevel >= 0 && telemetry.batteryLevel <= 100) {
      await SupabaseService.upsertAppContent('battery_${spaceId}_$userId', {
        'level': telemetry.batteryLevel,
        'isCharging': telemetry.isCharging,
        'updatedAt': telemetry.updatedAt,
        'senderId': userId,
      });
    }
    notifyListeners();
  }

  Future<void> sendSecretWhisper({
    required String spaceId,
    required String senderId,
    required String senderNickname,
    required String text,
  }) async {
    final clean = text.trim();
    if (spaceId.isEmpty || clean.isEmpty) return;
    final whisper = SecretWhisper(
      id: 'wsp_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderNickname: senderNickname,
      text: clean,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    _secretWhispers.insert(0, whisper);
    if (_secretWhispers.length > 25) {
      _secretWhispers = _secretWhispers.take(25).toList();
    }
    notifyListeners();

    final listJson = _secretWhispers.map((w) => w.toJson()).toList();
    await SupabaseService.upsertAppContent('secret_whispers_$spaceId', {
      'whispers': listJson,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'SECRET_WHISPER',
      payload: {'whispers': listJson},
    );
  }

  Future<void> revealAndBurnWhisper({
    required String spaceId,
    required String whisperId,
    required String readerId,
  }) async {
    final idx = _secretWhispers.indexWhere((w) => w.id == whisperId);
    if (idx == -1) return;
    _secretWhispers[idx] = _secretWhispers[idx].burn(readerId);
    notifyListeners();

    final listJson = _secretWhispers.map((w) => w.toJson()).toList();
    await SupabaseService.upsertAppContent('secret_whispers_$spaceId', {
      'whispers': listJson,
      'updated_at': DateTime.now().toIso8601String(),
    });
    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'SECRET_WHISPER',
      payload: {'whispers': listJson},
    );
  }

  @override
  void dispose() {
    _batterySyncTimer?.cancel();
    _partnerTouchDecayTimer?.cancel();
    _drawingSaveDebounce?.cancel();
    _anniversarySub?.cancel();
    _moodSub?.cancel();
    _noteSub?.cancel();
    _dailyPromptSub?.cancel();
    _promptHistorySub?.cancel();
    _goalsSub?.cancel();
    _dailyCareSub?.cancel();
    _pulseSub?.cancel();
    _heartbeatSub?.cancel();
    _touchStatsSub?.cancel();
    _gentleModeSub?.cancel();
    super.dispose();
  }
}
