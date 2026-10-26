import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  StreamSubscription? _goalsSub;

  String? get anniversaryDate => _anniversaryDate;
  MoodAura? get myMood => _myMood;
  MoodAura? get partnerMood => _partnerMood;
  DailyPrompt? get dailyPrompt => _dailyPrompt;
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

    // 2. Listen to Mood Aura
    _moodSub?.cancel();
    _moodSub = FirebaseService.streamFeatureDoc(spaceId, 'mood_aura').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final moods = snap.data()!['mood'] as Map<String, dynamic>? ?? {};
        if (moods.containsKey(userId)) {
          final myData = moods[userId] as Map<String, dynamic>?;
          _myMood = myData != null ? MoodAura.fromJson(myData) : null;
          LocalCacheService.setCachedMyMood(myData);
        }
        if (partnerId != null && moods.containsKey(partnerId)) {
          final pData = moods[partnerId] as Map<String, dynamic>?;
          _partnerMood = pData != null ? MoodAura.fromJson(pData) : null;
          LocalCacheService.setCachedPartnerMood(pData);
        } else {
          // Resilient fallback: find partner entry if partnerId is null or differing
          final partnerEntry = moods.entries.firstWhere(
            (e) => e.key != userId,
            orElse: () => const MapEntry('', null),
          );
          if (partnerEntry.key.isNotEmpty && partnerEntry.value != null) {
            final pData = Map<String, dynamic>.from(partnerEntry.value as Map);
            _partnerMood = MoodAura.fromJson(pData);
            LocalCacheService.setCachedPartnerMood(pData);
          }
        }
        notifyListeners();
      }
    });

    // 3. Listen to Pinned Notes
    _noteSub?.cancel();
    _noteSub = FirebaseService.streamFeatureDoc(spaceId, 'pinned_note').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final rawNotes = snap.data()!['notes'] as Map<String, dynamic>? ?? {};
        _pinnedNotes = rawNotes.map(
          (k, v) => MapEntry(k, PinnedNote.fromJson(Map<String, dynamic>.from(v as Map))),
        );
        LocalCacheService.setCachedPinnedNotes(rawNotes);
        notifyListeners();
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

    // 5. Fetch Goals
    fetchGoals(spaceId);

    // 6. Supabase Realtime Broadcast for Live Touch, Pulses & Prompts
    SupabaseService.subscribeToSpaceEvents(
      spaceId,
      onPulse: (data) {
        final sender = data['senderId'] as String?;
        if (sender != userId) {
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
        if (sender != userId && data['notes'] != null) {
          final rawNotes = Map<String, dynamic>.from(data['notes'] as Map);
          _pinnedNotes = rawNotes.map(
            (k, v) => MapEntry(k, PinnedNote.fromJson(Map<String, dynamic>.from(v as Map))),
          );
          LocalCacheService.setCachedPinnedNotes(rawNotes);
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
    _triggerPulseEffect();
    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'PULSE',
      payload: {
        'senderId': userId,
        'senderNickname': nickname,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
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

    // Broadcast count to partner
    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'TOUCH_COUNT_SYNC',
      payload: {'senderId': userId, 'count': _myDailyTouches, 'date': todayStr},
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
  }

  Future<void> clearDrawing(String spaceId, String userId) async {
    _drawingStrokes.clear();
    notifyListeners();

    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'CLEAR_DRAWING',
      payload: {'senderId': userId},
    );
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

    await FirebaseService.saveFeatureDoc(spaceId, 'mood_aura', {
      'mood': {
        userId: mood?.toJson(),
      }
    });

    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'MOOD_UPDATE',
      payload: {
        'senderId': userId,
        'mood': mood?.toJson(),
      },
    );
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

    // 1. Dual save: Firestore & Supabase app_content
    await FirebaseService.saveFeatureDoc(spaceId, 'daily_prompt', updatedPrompt.toJson());
    await SupabaseService.upsertAppContent('daily_prompt_$spaceId', updatedPrompt.toJson());

    // 2. Realtime broadcast to partner
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
    final allNotesJson = _pinnedNotes.map((k, v) => MapEntry(k, v.toJson()));
    await LocalCacheService.setCachedPinnedNotes(allNotesJson);
    _syncWidget(null);
    notifyListeners();

    await FirebaseService.saveFeatureDoc(spaceId, 'pinned_note', {
      'notes': allNotesJson,
    });
    await SupabaseService.upsertAppContent('pinned_note_$spaceId', {
      'notes': allNotesJson,
    });
    await SupabaseService.broadcastEvent(
      spaceId: spaceId,
      eventType: 'PINNED_NOTE_CHANGED',
      payload: {
        'senderId': userId,
        'notes': allNotesJson,
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
    _anniversarySub?.cancel();
    _moodSub?.cancel();
    _noteSub?.cancel();
    _dailyPromptSub?.cancel();
    _goalsSub?.cancel();
    super.dispose();
  }
}
