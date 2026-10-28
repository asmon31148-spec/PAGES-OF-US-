import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/mood_aura.dart';
import '../data/models/daily_prompt.dart';
import '../data/models/pinned_note.dart';
import '../data/models/couple_goal_item.dart';
import '../data/models/drawing_stroke.dart';
import '../data/services/firebase_service.dart';
import '../data/services/supabase_service.dart';
import '../core/services/local_cache_service.dart';
import '../core/services/widget_sync_service.dart';
import '../core/services/notification_service.dart';

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
  StreamSubscription? _pulseSub;
  StreamSubscription? _touchStatsSub;
  String? _activeSpaceId;
  String? _activeUserId;
  String? _activePartnerId;
  int _lastPulseTimestamp = 0;
  Timer? _drawingSaveDebounce;

  String? get activeSpaceId => _activeSpaceId;
  String? get activePartnerId => _activePartnerId;

  String? get anniversaryDate => _anniversaryDate;
  MoodAura? get myMood => _myMood;
  MoodAura? get partnerMood => _partnerMood;
  DailyPrompt? get dailyPrompt => _dailyPrompt;
  List<PromptHistoryItem> get promptHistory => List.unmodifiable(_promptHistory);
  Map<String, PinnedNote> get pinnedNotes => _pinnedNotes;
  List<CoupleGoalItem> get goals => _goals;
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
      final diff = DateTime.now().difference(start).inDays;
      return diff > 0 ? diff : 1;
    } catch (_) {
      return 1;
    }
  }

  StageProvider() {
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

    // 1. Listen to Anniversary
    _anniversarySub?.cancel();
    _anniversarySub = FirebaseService.streamFeatureDoc(spaceId, 'anniversary').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final date = snap.data()!['anniversaryDate'] as String?;
        if (date != null && date != _anniversaryDate) {
          _anniversaryDate = date;
          LocalCacheService.setCachedAnniversary(date);
          _syncWidget(partnerId);
          notifyListeners();
        }
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

        if (partnerId != null && moods.containsKey(partnerId) && moods[partnerId] is Map) {
          final pData = Map<String, dynamic>.from(moods[partnerId] as Map);
          _partnerMood = MoodAura.fromJson(pData);
          LocalCacheService.setCachedPartnerMood(pData);
        } else {
          // Dynamic partner lookup
          for (final entry in moods.entries) {
            if (entry.key != userId && entry.key != 'updatedAt' && entry.value is Map) {
              final pData = Map<String, dynamic>.from(entry.value as Map);
              _partnerMood = MoodAura.fromJson(pData);
              LocalCacheService.setCachedPartnerMood(pData);
              break;
            }
          }
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
            try {
              updatedMap[k] = PinnedNote.fromJson(Map<String, dynamic>.from(v));
            } catch (_) {}
          }
        });
        if (updatedMap.isNotEmpty) {
          _pinnedNotes = updatedMap;
          LocalCacheService.setCachedPinnedNotes(rawNotes);
          _syncWidget(partnerId);
          notifyListeners();
        }
      }
    });

    // 4. Listen to Daily Blind Prompt
    _dailyPromptSub?.cancel();
    _dailyPromptSub = FirebaseService.streamFeatureDoc(spaceId, 'daily_prompt').listen((snap) {
      if (snap.exists && snap.data() != null) {
        _dailyPrompt = DailyPrompt.fromJson(snap.data()!);
        LocalCacheService.setCachedDailyPrompt(snap.data()!);
        notifyListeners();
      }
    });

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
            _drawingStrokes.add(DrawingStroke.fromJson(Map<String, dynamic>.from(s)));
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
          );
          _drawingStrokes.add(stroke);
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
    );
  }

  void _triggerPulseEffect() {
    _isPulsing = true;
    HapticFeedback.vibrate();
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 2000), () {
      _isPulsing = false;
      notifyListeners();
    });
  }

  void _syncWidget(String? partnerId) {
    String? thought;
    if (partnerId != null && _pinnedNotes.containsKey(partnerId)) {
      thought = _pinnedNotes[partnerId]?.text;
    }
    WidgetSyncService.syncWidget(
      partnerThought: thought,
      daysTogether: daysTogether,
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
    _drawingStrokes.add(stroke);
    notifyListeners();

    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'DRAW_STROKE',
      payload: {
        'senderId': userId,
        'stroke': stroke.toJson(),
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
    // If current prompt has answers, archive to history first
    if (_dailyPrompt != null && _dailyPrompt!.answers.isNotEmpty) {
      final historyItem = PromptHistoryItem(
        id: _dailyPrompt!.id,
        question: _dailyPrompt!.prompt,
        vibeTag: _dailyPrompt!.vibeTag,
        category: _dailyPrompt!.category,
        answers: _dailyPrompt!.answers,
        date: DateTime.now().toIso8601String().split('T').first,
      );
      _archivePromptHistory(spaceId, historyItem);
    }

    final newPrompt = DailyPrompt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      prompt: question,
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

    // 1. Dual save: Firestore & Supabase app_content
    await FirebaseService.saveFeatureDoc(spaceId, 'daily_prompt', newPrompt.toJson());
    await SupabaseService.upsertAppContent('daily_prompt_$spaceId', newPrompt.toJson());

    // 2. Broadcast to partner
    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'DAILY_PROMPT_UPDATE',
      payload: {
        'dailyPrompt': newPrompt.toJson(),
      },
    );
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
            notifyListeners();
            return;
          }
        }
      } catch (_) {}
    }
    if (_goals.isEmpty) {
      _goals = List.from(defaultPresetGoals);
      notifyListeners();
    }
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
    _pulseSub?.cancel();
    _touchStatsSub?.cancel();
    super.dispose();
  }
}
