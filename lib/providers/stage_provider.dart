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
import '../data/services/firebase_service.dart';
import '../data/services/supabase_service.dart';
import '../core/services/local_cache_service.dart';
import '../core/services/widget_sync_service.dart';
import '../core/services/notification_service.dart';
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
  String? _activeSpaceId;
  String? _activeUserId;
  String? _activePartnerId;
  int _lastPulseTimestamp = 0;
  int _lastHeartbeatTimestamp = 0;
  Timer? _drawingSaveDebounce;

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
    _drawingSaveDebounce?.cancel();
    _partnerTouchDecayTimer?.cancel();
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

    _anniversaryDate = null;
    _myMood = null;
    _partnerMood = null;
    _dailyPrompt = null;
    _promptHistory = [];
    _pinnedNotes = {};
    _goals = [];
    _dailyCareItems = [];
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

    _activeSpaceId = spaceId;
    _activeUserId = userId;
    _activePartnerId = partnerId;

    if (partnerId == null || partnerId.isEmpty) {
      _partnerMood = null;
      _partnerTouchPoint = null;
      _partnerDailyTouches = 0;
      _pinnedNotes.removeWhere((k, _) => k != userId);
      LocalCacheService.setCachedPartner(null);
      LocalCacheService.setCachedPartnerMood(null);
    }

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
        final updatedMap = <String, PinnedNote>{};
        rawNotes.forEach((k, v) {
          if (k != 'updatedAt' && v is Map) {
            // Strictly only admit notes for current user or active partner!
            if (k == userId || (partnerId != null && partnerId.isNotEmpty && k == partnerId)) {
              try {
                updatedMap[k] = PinnedNote.fromJson(Map<String, dynamic>.from(v));
              } catch (_) {}
            }
          }
        });
        _pinnedNotes = updatedMap;
        LocalCacheService.setCachedPinnedNotes(
          _pinnedNotes.map((k, v) => MapEntry(k, v.toJson())),
        );
        _syncWidget(partnerId);
        notifyListeners();
      }
    });

    // 4. Listen to Daily Blind Prompt
    _dailyPromptSub?.cancel();
    _dailyPromptSub = FirebaseService.streamFeatureDoc(spaceId, 'daily_prompt').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final parsed = DailyPrompt.fromJson(snap.data()!);
        _dailyPrompt = _handleDailyPromptRollover(parsed, spaceId);
        LocalCacheService.setCachedDailyPrompt(_dailyPrompt!.toJson());
        notifyListeners();
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
    try {
      final client = SupabaseService.client;
      if (client != null) {
        client
            .from('app_content')
            .select('content')
            .eq('id', 'daily_prompt_$spaceId')
            .maybeSingle()
            .then((res) {
          if (res != null && res['content'] != null && res['content'] is Map) {
            final promptMap = Map<String, dynamic>.from(res['content'] as Map);
            final parsed = DailyPrompt.fromJson(promptMap);
            _dailyPrompt = _handleDailyPromptRollover(parsed, spaceId);
            LocalCacheService.setCachedDailyPrompt(_dailyPrompt!.toJson());
            notifyListeners();
          }
        });
      }
    } catch (_) {}

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
          _goals = list
              .map((e) => CoupleGoalItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          notifyListeners();
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
        if (list != null) {
          _dailyCareItems = list
              .map((e) => DailyCareItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();

          // Reschedule local exact alarm notifications for this device
          NotificationService.scheduleDailyCareNotifications(
            items: _dailyCareItems,
            currentUserId: userId,
            partnerName: partnerNickname,
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
      onPinnedNote: (data) {
        final sender = data['senderId'] as String?;
        if (sender != userId && data['note'] != null) {
          final note = PinnedNote.fromJson(Map<String, dynamic>.from(data['note'] as Map));
          _pinnedNotes[note.userId] = note;
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

  Future<void> saveDailyPromptAnswer(String spaceId, String userId, String answer) async {
    final currentPrompt = _dailyPrompt ?? DailyPrompt(
      id: DateTime.now().toIso8601String().split('T').first,
      prompt: 'What was the sweetest little thought you had about us today?',
      category: 'Soft Affection',
      vibeTag: 'Gentle Whisper',
      answers: {},
      reveals: {},
      careChecks: {},
    );

    final updatedAnswers = Map<String, String>.from(currentPrompt.answers);
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
    _pinnedNotes[userId] = note;
    _syncWidget(null);
    notifyListeners();

    await FirebaseService.saveUserFeatureField(spaceId, 'pinned_note', userId, note.toJson());
    await SupabaseService.upsertAppContent('pinned_note_${spaceId}_$userId', note.toJson());
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

  Future<void> fetchGoals(String spaceId) async {
    final supabase = SupabaseService.client;
    if (supabase != null) {
      try {
        final res = await supabase
            .from('app_content')
            .select('content')
            .eq('id', 'couple_goals_$spaceId')
            .maybeSingle();
        if (res != null && res['content'] != null && res['content'] is List) {
          final list = res['content'] as List;
          if (list.isNotEmpty) {
            _goals = list
                .map((e) => CoupleGoalItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
            final pending = _goals.where((g) => !g.isCompleted).length;
            NotificationService.scheduleWeeklyGoalReminder(pendingGoalsCount: pending);
            notifyListeners();
            return;
          }
        }
      } catch (_) {}
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
    _goals.add(goal);
    notifyListeners();
    _syncGoalsToCloud(spaceId);
  }

  Future<void> deleteGoal(String spaceId, String goalId) async {
    _goals.removeWhere((g) => g.id == goalId);
    notifyListeners();
    _syncGoalsToCloud(spaceId);
  }

  Future<void> _syncGoalsToCloud(String spaceId) async {
    final jsonList = _goals.map((g) => g.toJson()).toList();
    final supabase = SupabaseService.client;
    if (supabase != null) {
      try {
        await supabase.from('app_content').upsert({
          'id': 'couple_goals_$spaceId',
          'content': jsonList,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }
    try {
      await FirebaseService.saveFeatureDoc(spaceId, 'couple_goals', {
        'goals': jsonList,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
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

  Future<void> fetchDailyCare(String spaceId, {String? currentUserId, String? partnerName}) async {
    final supabase = SupabaseService.client;
    if (supabase != null) {
      try {
        final res = await supabase
            .from('app_content')
            .select('content')
            .eq('id', 'daily_care_$spaceId')
            .maybeSingle();
        if (res != null && res['content'] != null && res['content'] is List) {
          final list = res['content'] as List;
          if (list.isNotEmpty) {
            _dailyCareItems = list
                .map((e) => DailyCareItem.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
            NotificationService.scheduleDailyCareNotifications(
              items: _dailyCareItems,
              currentUserId: currentUserId,
              partnerName: partnerName,
            );
            notifyListeners();
            return;
          }
        }
      } catch (_) {}
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

  Future<void> deleteCareItem(String spaceId, String careId) async {
    _dailyCareItems.removeWhere((c) => c.id == careId);
    notifyListeners();
    _syncDailyCareToCloud(spaceId);
    NotificationService.cancelDailyCareNotification(careId);
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

  Future<void> _syncDailyCareToCloud(
    String spaceId, {
    String? senderId,
    String? lastAction,
    String? lastItemTitle,
    String? lastItemTime,
    String? targetUserId,
  }) async {
    final jsonList = _dailyCareItems.map((c) => c.toJson()).toList();
    final supabase = SupabaseService.client;
    if (supabase != null) {
      try {
        await supabase.from('app_content').upsert({
          'id': 'daily_care_$spaceId',
          'content': jsonList,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }
    try {
      await FirebaseService.saveFeatureDoc(spaceId, 'daily_care_schedules', {
        'care_items': jsonList,
        'updatedAt': DateTime.now().toIso8601String(),
        if (senderId != null) 'senderId': senderId,
        if (lastAction != null) 'lastAction': lastAction,
        if (lastItemTitle != null) 'lastItemTitle': lastItemTitle,
        if (lastItemTime != null) 'lastItemTime': lastItemTime,
        if (targetUserId != null) 'targetUserId': targetUserId,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
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
    super.dispose();
  }
}
