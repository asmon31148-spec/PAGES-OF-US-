import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/user_location_model.dart';
import '../data/models/pinned_place.dart';
import '../data/models/bucket_place.dart';
import '../data/models/geofence_event.dart';
import '../data/models/stay_point_model.dart';
import '../data/services/firebase_service.dart';
import '../data/services/supabase_service.dart';
import '../core/services/weather_service.dart';
import '../core/services/notification_service.dart';
import 'auth_provider.dart';

// ── Journey tracking data model ────────────────────────────────────────────────
class JourneyPoint {
  final double lat;
  final double lng;
  final DateTime timestamp;
  final String city;
  final double speedMps;

  const JourneyPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.city = '',
    this.speedMps = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'ts': timestamp.millisecondsSinceEpoch,
    'city': city,
    'sp': speedMps,
  };

  factory JourneyPoint.fromJson(Map<String, dynamic> j) => JourneyPoint(
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    timestamp: DateTime.fromMillisecondsSinceEpoch((j['ts'] as num).toInt()),
    city: j['city']?.toString() ?? '',
    speedMps: (j['sp'] as num?)?.toDouble() ?? 0.0,
  );
}

class WorldProvider extends ChangeNotifier {
  final Map<String, UserLocationData> _locations = {};
  List<PinnedPlace> _pinnedPlaces = [];
  List<BucketPlace> _bucketList = [];
  List<GeofenceEvent> _geofenceEvents = [];
  final Set<String> _partnerInsideZoneIds = {};
  bool _hasInitializedZones = false;
  bool _isSharing = true;
  bool _isLoading = false;
  String _gpsStatus = 'Standby';
  WeatherInfo? _partnerWeather;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  Timer? _cloudDebounce;
  StreamSubscription? _firestoreSub;
  StreamSubscription<Position>? _positionStreamSub;

  String? _spaceId;
  String? _currentUserId;
  String? _currentNickname;
  String? _currentAvatarUrl;
  String? _partnerId;

  double? _lastGeocodedLat;
  double? _lastGeocodedLng;
  DateTime? _lastGeocodedTime;
  String _cachedPlaceName = 'Nearby';
  String _cachedNeighborhood = '';
  String _cachedCity = '';
  String? _firstPlaceNameToday;
  String? _partnerFirstPlaceToday;

  // ── Stationary GPS Sleep (Battery saving & zero jitter) ─────────────────────
  double? _stationaryAnchorLat;
  double? _stationaryAnchorLng;
  DateTime? _stationaryAnchorTime;
  DateTime? _lastStationaryBroadcastTime;

  // ── Journey log — accumulated GPS points for travel stats ───────────────────
  List<JourneyPoint> _myJourneyLog = [];
  List<JourneyPoint> _partnerJourneyLog = [];
  Timer? _journeyPersistDebounce;
  String get _journeyPrefKey => _currentUserId != null ? 'journey_log_my_${_currentUserId!}' : 'journey_log_my_v2';

  Map<String, UserLocationData> get locations => Map.unmodifiable(_locations);
  List<PinnedPlace> get pinnedPlaces => List.unmodifiable(_pinnedPlaces);
  bool get isSharing => _isSharing;
  bool get isLoading => _isLoading;
  String get gpsStatus => _gpsStatus;
  WeatherInfo? get partnerWeather => _partnerWeather;
  DateTime get now => _now;
  String? get spaceId => _spaceId;
  String? get partnerId => _partnerId;
  bool _isTrackingInitializing = false;
  bool get isLiveTrackingActive => _positionStreamSub != null || _isTrackingInitializing;
  List<BucketPlace> get bucketList => List.unmodifiable(_bucketList);
  List<GeofenceEvent> get geofenceEvents => List.unmodifiable(_geofenceEvents);

  List<JourneyPoint> get partnerJourneyToday {
    final start = _startOfToday;
    return _partnerJourneyLog.where((p) => p.timestamp.isAfter(start)).toList();
  }

  String? get partnerMovementState {
    final pLoc = partnerLocation;
    if (pLoc == null) return null;
    final speedMps = pLoc.speedMps;
    if (speedMps == null) return null;
    if (speedMps < 0.6) return 'Stationary';
    if (speedMps < 2.4) return 'Walking • ${(speedMps * 3.6).toStringAsFixed(1)} km/h';
    return 'In Transit • ${(speedMps * 3.6).round()} km/h';
  }

  bool isInBucketList(String name, double lat, double lng) {
    final normName = name.trim().toLowerCase();
    return _bucketList.any((b) =>
        b.name.trim().toLowerCase() == normName ||
        ((b.lat - lat).abs() < 0.0005 && (b.lng - lng).abs() < 0.0005));
  }

  UserLocationData? get myLocation {
    if (_currentUserId != null && _locations.containsKey(_currentUserId)) {
      return _locations[_currentUserId];
    }
    for (final loc in _locations.values) {
      if (_currentUserId != null && loc.userId == _currentUserId) {
        return loc;
      }
    }
    return null;
  }

  UserLocationData? get partnerLocation {
    if (_partnerId != null && _partnerId!.isNotEmpty && _locations.containsKey(_partnerId)) {
      return _locations[_partnerId];
    }
    return null;
  }

  double? get liveDistanceKm {
    if (_partnerId == null || _partnerId!.isEmpty) return null;
    final me = myLocation;
    final partner = partnerLocation;
    if (me != null && partner != null) {
      if ((me.lat != 0.0 || me.lng != 0.0) && (partner.lat != 0.0 || partner.lng != 0.0)) {
        return calculateDistanceKm(me.lat, me.lng, partner.lat, partner.lng);
      }
    }
    return null;
  }

  void clearPartner() {
    if (_partnerId != null) {
      _locations.remove(_partnerId);
    }
    _partnerId = null;
    _partnerWeather = null;
    notifyListeners();
  }

  /// Wipes ALL in-memory and persisted-key state when user logs out.
  /// Called by AuthProvider.signOut() before FirebaseService.signOut().
  Future<void> resetState() async {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _firestoreSub?.cancel();
    _firestoreSub = null;
    _cloudDebounce?.cancel();
    _journeyPersistDebounce?.cancel();
    SupabaseService.removeLocationListener(_handleSupabaseLocationUpdate);

    _locations.clear();
    _pinnedPlaces.clear();
    _bucketList.clear();
    _geofenceEvents.clear();
    _partnerInsideZoneIds.clear();
    _hasInitializedZones = false;
    _myJourneyLog.clear();
    _partnerJourneyLog.clear();
    _geocodeCache.clear();
    _partnerWeather = null;
    _gpsStatus = 'Standby';
    _spaceId = null;
    _currentUserId = null;
    _currentNickname = null;
    _currentAvatarUrl = null;
    _partnerId = null;
    _lastGeocodedLat = null;
    _lastGeocodedLng = null;
    _lastGeocodedTime = null;
    _cachedPlaceName = 'Nearby';
    _cachedNeighborhood = '';
    _cachedCity = '';
    _stationaryAnchorLat = null;
    _stationaryAnchorLng = null;
    _stationaryAnchorTime = null;
    _lastStationaryBroadcastTime = null;
    _isSharing = true;
    _isTrackingInitializing = false;

    // Wipe journey log from SharedPreferences (user-scoped key cleaned separately)
    try {
      final prefs = await SharedPreferences.getInstance();
      // Remove ALL journey log keys (any userId variant)
      final keys = prefs.getKeys().where((k) => k.startsWith('journey_log_')).toList();
      for (final k in keys) { await prefs.remove(k); }
    } catch (_) {}

    notifyListeners();
  }

  String get formattedLiveDistance {
    final dist = liveDistanceKm;
    if (dist == null) {
      final pLoc = partnerLocation;
      if (myLocation != null && pLoc == null) {
        return 'Awaiting partner signal...';
      }
      return 'Connecting live tether...';
    }

    if (dist < 0.05) {
      return 'Together · Side by side ♥';
    } else if (dist < 1.0) {
      final m = (dist * 1000).round();
      return '$m meters apart · Walking distance';
    } else if (dist < 10.0) {
      final miles = (dist * 0.621371).toStringAsFixed(1);
      return '${dist.toStringAsFixed(2)} km ($miles mi) apart';
    } else {
      final miles = (dist * 0.621371).toStringAsFixed(1);
      return '${dist.toStringAsFixed(1)} km ($miles mi) apart';
    }
  }

  WorldProvider() {
    AuthProvider.registerSignOutHook(resetState);
    _loadJourneyLog();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _cloudDebounce?.cancel();
    _journeyPersistDebounce?.cancel();
    _firestoreSub?.cancel();
    _positionStreamSub?.cancel();
    SupabaseService.removeLocationListener(_handleSupabaseLocationUpdate);
    super.dispose();
  }

  UserLocationData? getUserLocation(String? userId) {
    if (userId == null) return null;
    return _locations[userId];
  }

  // ── Journey tracking ────────────────────────────────────────────────────────

  // ── Stay Points (Timeline of stops throughout the day) ──────────────────────
  final List<StayPoint> _myStayPoints = [];
  final List<StayPoint> _partnerStayPoints = [];
  List<StayPoint> get myStayPoints => List.unmodifiable(_myStayPoints);
  List<StayPoint> get partnerStayPoints => List.unmodifiable(_partnerStayPoints);

  List<StayPoint> get myStayPointsToday {
    final start = _startOfToday;
    return _myStayPoints.where((p) => (p.departureTime ?? DateTime.now()).isAfter(start)).toList();
  }

  List<StayPoint> get partnerStayPointsToday {
    final start = _startOfToday;
    return _partnerStayPoints.where((p) => (p.departureTime ?? DateTime.now()).isAfter(start)).toList();
  }

  double? _candidateLat;
  double? _candidateLng;
  DateTime? _candidateArrivalTime;
  String? _candidatePlace;
  DateTime? _lastDepartureTime;

  String get _stayPointsPrefKey => 'pages_stay_points_${_currentUserId ?? "me"}';

  Future<void> _persistStayPoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_myStayPoints.map((p) => p.toJson()).toList());
      await prefs.setString(_stayPointsPrefKey, json);
    } catch (_) {}
  }

  Future<void> _loadStayPoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_stayPointsPrefKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _myStayPoints.clear();
        _myStayPoints.addAll(list.map((e) => StayPoint.fromJson(Map<String, dynamic>.from(e as Map))));
        final cutoff = DateTime.now().subtract(const Duration(hours: 24));
        _myStayPoints.removeWhere((p) => (p.departureTime ?? p.arrivalTime).isBefore(cutoff));
      }
    } catch (_) {}
  }

  void _recordMyStayPoint(double lat, double lng, String placeName) {
    if (lat == 0.0 && lng == 0.0) return;
    final now = DateTime.now();
    final cleanName = placeName.trim().isEmpty || placeName == 'Nearby'
        ? (_cachedNeighborhood.isNotEmpty ? _cachedNeighborhood : 'Current Spot')
        : placeName;

    if (_myStayPoints.isEmpty) {
      final newPoint = StayPoint(
        id: 'stay_${now.millisecondsSinceEpoch}',
        userId: _currentUserId ?? 'me',
        placeName: cleanName,
        lat: lat,
        lng: lng,
        arrivalTime: now.subtract(const Duration(minutes: 20)),
        isCurrent: true,
        icon: '🏡',
      );
      _myStayPoints.add(newPoint);
      _persistStayPoints();
      notifyListeners();
      return;
    }

    final current = _myStayPoints.lastWhere((p) => p.isCurrent, orElse: () => _myStayPoints.last);
    final distFromCurrentM = calculateDistanceKm(current.lat, current.lng, lat, lng) * 1000;

    // Inside current spot (within 30m)
    if (distFromCurrentM < 30) {
      _candidateLat = null;
      _candidateLng = null;
      _candidateArrivalTime = null;
      if (cleanName != 'Current Spot' && cleanName != 'Nearby' && current.placeName != cleanName) {
        final idx = _myStayPoints.indexOf(current);
        _myStayPoints[idx] = StayPoint(
          id: current.id,
          userId: current.userId,
          placeName: cleanName,
          lat: current.lat,
          lng: current.lng,
          arrivalTime: current.arrivalTime,
          departureTime: current.departureTime,
          isCurrent: current.isCurrent,
          icon: current.icon,
          tripDistanceKm: current.tripDistanceKm,
          fromPlaceName: current.fromPlaceName,
          tripStartTime: current.tripStartTime,
        );
        _persistStayPoints();
        notifyListeners();
      }
      return;
    }

    // User moved away by >= 100m from current stop
    if (distFromCurrentM >= 100) {
      if (current.isCurrent) {
        current.departureTime = now;
        current.isCurrent = false;
        _lastDepartureTime = now;
      }

      // Check candidate stop location (inside 25m)
      if (_candidateLat == null || _candidateLng == null) {
        _candidateLat = lat;
        _candidateLng = lng;
        _candidateArrivalTime = now;
        _candidatePlace = cleanName;
        return;
      }

      final distFromCandidateM = calculateDistanceKm(_candidateLat!, _candidateLng!, lat, lng) * 1000;
      if (distFromCandidateM > 25) {
        // Still moving/traveling, reset candidate to current position
        _candidateLat = lat;
        _candidateLng = lng;
        _candidateArrivalTime = now;
        _candidatePlace = cleanName;
        return;
      }

      // User has stopped and stayed inside candidate 25m circle
      final stayedMinutes = now.difference(_candidateArrivalTime!).inMinutes;
      final speed = _locations[_currentUserId]?.speedMps ?? 0.0;
      // Confirm stop if stayed >= 15 min OR stationary (< 0.6 m/s)
      if (stayedMinutes >= 15 || speed < 0.6) {
        String icon = '📍';
        final lower = cleanName.toLowerCase();
        if (lower.contains('cafe') || lower.contains('coffee')) {
          icon = '☕';
        } else if (lower.contains('home') || lower.contains('house')) {
          icon = '🏡';
        } else if (lower.contains('park') || lower.contains('garden')) {
          icon = '🌿';
        } else if (lower.contains('market') || lower.contains('mall') || lower.contains('shop')) {
          icon = '🛍️';
        }

        final tripDistKm = calculateDistanceKm(current.lat, current.lng, lat, lng);
        final tripStart = current.departureTime ?? _lastDepartureTime ?? _candidateArrivalTime!.subtract(const Duration(minutes: 10));

        final newPoint = StayPoint(
          id: 'stay_${now.millisecondsSinceEpoch}',
          userId: _currentUserId ?? 'me',
          placeName: cleanName,
          lat: lat,
          lng: lng,
          arrivalTime: _candidateArrivalTime!,
          isCurrent: true,
          icon: icon,
          tripDistanceKm: tripDistKm >= 0.1 ? tripDistKm : null,
          fromPlaceName: current.placeName,
          tripStartTime: tripDistKm >= 0.1 ? tripStart : null,
        );

        _myStayPoints.add(newPoint);
        _persistStayPoints();
        _candidateLat = null;
        _candidateLng = null;
        _candidateArrivalTime = null;
        notifyListeners();
      }
    }
  }

  void _recordPartnerStayPoint(double lat, double lng, String placeName) {
    if (lat == 0.0 && lng == 0.0 || _partnerId == null) return;
    final now = DateTime.now();
    final cleanName = placeName.trim().isEmpty || placeName == 'Nearby' ? 'Current Spot' : placeName;

    if (_partnerStayPoints.isEmpty) {
      _partnerStayPoints.add(
        StayPoint(
          id: 'pstay_${now.millisecondsSinceEpoch}',
          userId: _partnerId!,
          placeName: cleanName,
          lat: lat,
          lng: lng,
          arrivalTime: now.subtract(const Duration(minutes: 25)),
          isCurrent: true,
          icon: '🏡',
        ),
      );
      notifyListeners();
      return;
    }

    final current = _partnerStayPoints.lastWhere((p) => p.isCurrent, orElse: () => _partnerStayPoints.last);
    final distM = calculateDistanceKm(current.lat, current.lng, lat, lng) * 1000;

    if (distM < 60) {
      if (cleanName != 'Current Spot' && cleanName != 'Nearby' && current.placeName != cleanName) {
        final idx = _partnerStayPoints.indexOf(current);
        _partnerStayPoints[idx] = StayPoint(
          id: current.id,
          userId: current.userId,
          placeName: cleanName,
          lat: current.lat,
          lng: current.lng,
          arrivalTime: current.arrivalTime,
          departureTime: current.departureTime,
          isCurrent: current.isCurrent,
          icon: current.icon,
        );
        notifyListeners();
      }
    } else if (distM >= 120) {
      if (current.isCurrent) {
        current.departureTime = now;
        current.isCurrent = false;
      }
      String icon = '📍';
      final lower = cleanName.toLowerCase();
      if (lower.contains('cafe') || lower.contains('coffee')) {
        icon = '☕';
      } else if (lower.contains('home') || lower.contains('house')) {
        icon = '🏡';
      } else if (lower.contains('park')) {
        icon = '🌿';
      }

      _partnerStayPoints.add(
        StayPoint(
          id: 'pstay_${now.millisecondsSinceEpoch}',
          userId: _partnerId!,
          placeName: cleanName,
          lat: lat,
          lng: lng,
          arrivalTime: now,
          isCurrent: true,
          icon: icon,
        ),
      );
      notifyListeners();
    }
  }

  /// Accumulates a GPS position into the personal journey log with indoor noise filtering.
  void _appendMyPoint(Position position) {
    final point = JourneyPoint(
      lat: position.latitude,
      lng: position.longitude,
      timestamp: DateTime.now(),
      city: _cachedCity,
      speedMps: position.speed >= 0 ? position.speed : 0.0,
    );

    // Filter out indoor GPS drift (< 35m displacement when stationary / speed < 0.6 m/s)
    if (_myJourneyLog.isNotEmpty) {
      final last = _myJourneyLog.last;
      final distM = calculateDistanceKm(last.lat, last.lng, point.lat, point.lng) * 1000;
      if (distM < 35 && position.speed < 0.6) return;
    }

    _myJourneyLog.add(point);

    // Prune log older than 31 days to cap memory usage
    final cutoff = DateTime.now().subtract(const Duration(days: 31));
    _myJourneyLog.removeWhere((p) => p.timestamp.isBefore(cutoff));

    // Debounced persist to SharedPreferences (max 1 write every 30 s)
    _journeyPersistDebounce?.cancel();
    _journeyPersistDebounce = Timer(const Duration(seconds: 30), _persistJourneyLog);
  }

  /// Accumulates the partner's incoming location into their journey log (session only).
  void _appendPartnerPoint(double lat, double lng, {double speedMps = 0.0}) {
    if (lat == 0.0 && lng == 0.0) return;
    final point = JourneyPoint(lat: lat, lng: lng, timestamp: DateTime.now(), speedMps: speedMps);

    if (_partnerJourneyLog.isNotEmpty) {
      final last = _partnerJourneyLog.last;
      final distM = calculateDistanceKm(last.lat, last.lng, point.lat, point.lng) * 1000;
      if (distM < 35) return;
    }
    _partnerJourneyLog.add(point);

    // Prune to last 24 h (partner log is session-only, not persisted)
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    _partnerJourneyLog.removeWhere((p) => p.timestamp.isBefore(cutoff));
  }

  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  double _calcJourneyKmSince(List<JourneyPoint> log, DateTime since) {
    final filtered = log.where((p) => p.timestamp.isAfter(since)).toList();
    if (filtered.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 1; i < filtered.length; i++) {
      final d = calculateDistanceKm(
        filtered[i - 1].lat, filtered[i - 1].lng,
        filtered[i].lat, filtered[i].lng,
      );
      if (d > 0.035) {
        total += d;
      }
    }
    return total;
  }

  double _calcWalkingKmSince(List<JourneyPoint> log, DateTime since) {
    final filtered = log.where((p) => p.timestamp.isAfter(since)).toList();
    if (filtered.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 1; i < filtered.length; i++) {
      final p1 = filtered[i - 1];
      final p2 = filtered[i];
      if (p2.speedMps > 5.0 || p1.speedMps > 5.0) continue;
      final d = calculateDistanceKm(
        p1.lat, p1.lng,
        p2.lat, p2.lng,
      );
      if (d > 0.035 && d < 1.0) {
        total += d;
      }
    }
    return total;
  }

  int _countAreasSince(List<JourneyPoint> log, DateTime since) {
    final cities = log
        .where((p) => p.timestamp.isAfter(since) && p.city.isNotEmpty)
        .map((p) => p.city)
        .toSet();
    return cities.isEmpty ? 0 : cities.length;
  }

  double _calcJourneyKm(List<JourneyPoint> log, Duration period) {
    final since = DateTime.now().subtract(period);
    final filtered = log.where((p) => p.timestamp.isAfter(since)).toList();
    if (filtered.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 1; i < filtered.length; i++) {
      final d = calculateDistanceKm(
        filtered[i - 1].lat, filtered[i - 1].lng,
        filtered[i].lat, filtered[i].lng,
      );
      // Filter out small jitter (< 0.035 km = 35m)
      if (d > 0.035) {
        total += d;
      }
    }
    return total;
  }

  double _calcWalkingKm(List<JourneyPoint> log, Duration period) {
    final since = DateTime.now().subtract(period);
    final filtered = log.where((p) => p.timestamp.isAfter(since)).toList();
    if (filtered.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 1; i < filtered.length; i++) {
      final p1 = filtered[i - 1];
      final p2 = filtered[i];
      // Skip high-speed vehicle transit (> 5.0 m/s = ~18 km/h) from walking distance
      if (p2.speedMps > 5.0 || p1.speedMps > 5.0) continue;
      final d = calculateDistanceKm(
        p1.lat, p1.lng,
        p2.lat, p2.lng,
      );
      if (d > 0.035 && d < 1.0) {
        total += d;
      }
    }
    return total;
  }

  int _countAreas(List<JourneyPoint> log, Duration period) {
    final since = DateTime.now().subtract(period);
    final cities = log
        .where((p) => p.timestamp.isAfter(since) && p.city.isNotEmpty)
        .map((p) => p.city)
        .toSet();
    return cities.isEmpty ? 0 : cities.length;
  }

  // ── Public journey getters (Refreshes each day at 12:00 AM midnight) ────────
  double get myJourneyKmToday     => _calcJourneyKmSince(_myJourneyLog, _startOfToday);
  double get myJourneyKmThisWeek  => _calcJourneyKm(_myJourneyLog, const Duration(days: 7));
  double get myJourneyKmThisMonth => _calcJourneyKm(_myJourneyLog, const Duration(days: 30));

  double get myWalkingKmToday     => _calcWalkingKmSince(_myJourneyLog, _startOfToday);
  double get myWalkingKmThisWeek  => _calcWalkingKm(_myJourneyLog, const Duration(days: 7));
  double get myWalkingKmThisMonth => _calcWalkingKm(_myJourneyLog, const Duration(days: 30));

  int get myAreasVisitedToday     => _countAreasSince(_myJourneyLog, _startOfToday);
  int get myAreasVisitedThisWeek  => _countAreas(_myJourneyLog, const Duration(days: 7));
  int get myAreasVisitedThisMonth => _countAreas(_myJourneyLog, const Duration(days: 30));

  double get partnerJourneyKmToday     => _calcJourneyKmSince(_partnerJourneyLog, _startOfToday);
  double get partnerJourneyKmThisWeek  => _calcJourneyKm(_partnerJourneyLog, const Duration(days: 7));
  double get partnerJourneyKmThisMonth => _calcJourneyKm(_partnerJourneyLog, const Duration(days: 30));

  int get myStepsToday => (myWalkingKmToday * 1300).round();
  int get myActiveMinutesToday => (myWalkingKmToday / 4.5 * 60).round();

  /// True ONLY when currently physically traveling (> 3 km/h or recent displacement)
  bool get isMyMoving {
    final my = myLocation;
    if (my == null) return false;
    if ((my.speedMps ?? 0.0) >= 0.8) return true;
    if (_myJourneyLog.length >= 2) {
      final now = DateTime.now();
      final recent = _myJourneyLog.where((p) => now.difference(p.timestamp).inMinutes <= 3).toList();
      if (recent.length >= 2) {
        final d = calculateDistanceKm(recent.first.lat, recent.first.lng, recent.last.lat, recent.last.lng) * 1000;
        if (d >= 35.0) return true;
      }
    }
    return false;
  }

  /// True ONLY when partner is currently physically moving
  bool get isPartnerMoving {
    final pLoc = partnerLocation;
    if (pLoc == null) return false;
    if ((pLoc.speedMps ?? 0.0) >= 0.8) return true;
    if (_partnerJourneyLog.length >= 2) {
      final now = DateTime.now();
      final recent = _partnerJourneyLog.where((p) => now.difference(p.timestamp).inMinutes <= 3).toList();
      if (recent.length >= 2) {
        final d = calculateDistanceKm(recent.first.lat, recent.first.lng, recent.last.lat, recent.last.lng) * 1000;
        if (d >= 35.0) return true;
      }
    }
    return false;
  }

  double get effectivePartnerJourneyKm {
    if (_partnerId != null && _locations[_partnerId]?.journeyKmToday != null) {
      return _locations[_partnerId]!.journeyKmToday!;
    }
    return partnerJourneyKmToday;
  }

  int get effectivePartnerSteps {
    if (_partnerId != null && _locations[_partnerId]?.stepsToday != null) {
      return _locations[_partnerId]!.stepsToday!;
    }
    return (effectivePartnerJourneyKm * 1300).round();
  }

  int get effectivePartnerActiveMinutes {
    if (_partnerId != null && _locations[_partnerId]?.activeMinutesToday != null) {
      return _locations[_partnerId]!.activeMinutesToday!;
    }
    return (effectivePartnerJourneyKm / 4.5 * 60).round();
  }

  String get effectivePartnerDeparturePlace {
    final fromModel = _locations[_partnerId]?.departurePlace;
    if (fromModel != null && fromModel.isNotEmpty && fromModel != 'Nearby' && fromModel != 'Starting Point') {
      return fromModel;
    }
    if (_partnerFirstPlaceToday != null && _partnerFirstPlaceToday!.isNotEmpty && _partnerFirstPlaceToday != 'Nearby') {
      return _partnerFirstPlaceToday!;
    }
    return _locations[_partnerId]?.neighborhood ?? _locations[_partnerId]?.city ?? 'Starting Point';
  }

  String get myDeparturePlace => (_firstPlaceNameToday != null && _firstPlaceNameToday != 'Nearby')
      ? _firstPlaceNameToday!
      : (_cachedNeighborhood.isNotEmpty ? _cachedNeighborhood : 'Starting Point');

  // ── Convenience methods called by journey_stats_card ───────────────────────
  double myJourneyKm(dynamic period) {
    final name = period?.toString() ?? '';
    if (name.contains('week')) return myJourneyKmThisWeek;
    if (name.contains('month')) return myJourneyKmThisMonth;
    return myJourneyKmToday;
  }

  double partnerJourneyKm(dynamic period) {
    final name = period?.toString() ?? '';
    if (name.contains('week')) return partnerJourneyKmThisWeek;
    if (name.contains('month')) return partnerJourneyKmThisMonth;
    return partnerJourneyKmToday;
  }

  int myAreasVisited(dynamic period) {
    final name = period?.toString() ?? '';
    if (name.contains('week')) return myAreasVisitedThisWeek;
    if (name.contains('month')) return myAreasVisitedThisMonth;
    return myAreasVisitedToday;
  }

  // ── Persist / load journey log ──────────────────────────────────────────────
  Future<void> _persistJourneyLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_myJourneyLog.map((p) => p.toJson()).toList());
      await prefs.setString(_journeyPrefKey, json);
    } catch (_) {}
  }

  Future<void> _loadJourneyLog() async {
    _loadStayPoints();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_journeyPrefKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _myJourneyLog = list
            .map((e) => JourneyPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        // Prune stale entries immediately on load
        final cutoff = DateTime.now().subtract(const Duration(days: 31));
        _myJourneyLog.removeWhere((p) => p.timestamp.isBefore(cutoff));
      }
    } catch (_) {}
  }

  double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  Future<void> initWorldSync({
    required String spaceId,
    required String currentUserId,
    String? partnerId,
  }) async {
    if (spaceId.isEmpty) return;

    _spaceId = spaceId;
    _currentUserId = currentUserId;
    _partnerId = (partnerId != null && partnerId.isNotEmpty) ? partnerId : null;
    _loadJourneyLog();

    if (_partnerId == null) {
      // Solo mode: purge any stale non-self locations
      _locations.removeWhere((key, _) => key != currentUserId);
      _partnerWeather = null;
    }

    // 1. Listen to Realtime WebSocket via unified space channel
    SupabaseService.addLocationListener(_handleSupabaseLocationUpdate);

    // 2. Initial cloud fetch (Supabase app_content)
    _fetchCloudData(spaceId);

    // 3. Firestore live listener (using dot-notation-safe feature doc)
    _firestoreSub?.cancel();
    _firestoreSub = FirebaseService.streamFeatureDoc(spaceId, 'locations').listen((snap) {
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        if (data['locations'] != null && data['locations'] is Map) {
          final map = Map<String, dynamic>.from(data['locations'] as Map);
          bool hasChanges = false;
          map.forEach((key, val) {
            if (val is Map) {
              final loc = UserLocationData.fromJson(Map<String, dynamic>.from(val));
              // Don't overwrite local high-frequency GPS with older Firestore data for self
              if (key == currentUserId) {
                if (!_locations.containsKey(key)) {
                  _locations[key] = loc;
                  hasChanges = true;
                }
              } else if (key != currentUserId && key != 'updatedAt') {
                if (_partnerId == null || _partnerId!.isEmpty) {
                  _partnerId = key;
                }
                if (key == _partnerId) {
                  _locations[key] = loc;
                  hasChanges = true;
                  if (loc.lat != 0.0 || loc.lng != 0.0) {
                    if (loc.placeName == null || loc.placeName == 'Nearby' || loc.placeName!.trim().isEmpty) {
                      _reverseGeocodePartner(key, loc.lat, loc.lng);
                    }
                  }
                }
              }
            }
          });

          if (hasChanges) {
            if (_partnerId != null && _locations[_partnerId] != null) {
              final pLoc = _locations[_partnerId]!;
              _fetchPartnerWeather(pLoc.lat, pLoc.lng);
              _checkPartnerGeofence(pLoc);
              if (pLoc.lat != 0.0 || pLoc.lng != 0.0) {
                if (pLoc.placeName == null || pLoc.placeName == 'Nearby' || pLoc.placeName!.trim().isEmpty) {
                  _reverseGeocodePartner(_partnerId!, pLoc.lat, pLoc.lng);
                }
              }
            }
            notifyListeners();
          }
        }

        if (data['places'] != null && data['places'] is List) {
          final list = List<dynamic>.from(data['places'] as List);
          _pinnedPlaces = list
              .map((e) => PinnedPlace.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          notifyListeners();
        }
      }
    });

    if (_partnerId != null && _locations[_partnerId] != null) {
      final pLoc = _locations[_partnerId]!;
      _fetchPartnerWeather(pLoc.lat, pLoc.lng);
      if (pLoc.lat != 0.0 || pLoc.lng != 0.0) {
        if (pLoc.placeName == null || pLoc.placeName == 'Nearby' || pLoc.placeName!.trim().isEmpty) {
          _reverseGeocodePartner(_partnerId!, pLoc.lat, pLoc.lng);
        }
      }
    }
  }

  void _handleSupabaseLocationUpdate(Map<String, dynamic> data) {
    if (data['location'] != null && data['location'] is Map) {
      final loc = UserLocationData.fromJson(Map<String, dynamic>.from(data['location'] as Map));
      if (loc.userId != _currentUserId) {
        if (_partnerId == null || _partnerId!.isEmpty) {
          _partnerId = loc.userId;
        }
        _locations[loc.userId] = loc;
        if (_partnerFirstPlaceToday == null && loc.placeName != null && loc.placeName!.isNotEmpty && loc.placeName != 'Nearby') {
          _partnerFirstPlaceToday = loc.placeName;
        }
        // Accumulate partner's position into their journey log
        _appendPartnerPoint(loc.lat, loc.lng, speedMps: loc.speedMps ?? 0.0);
        if (loc.stayPoints != null && loc.stayPoints!.isNotEmpty) {
          _partnerStayPoints.clear();
          _partnerStayPoints.addAll(loc.stayPoints!.map((m) => StayPoint.fromJson(m)));
        } else {
          _recordPartnerStayPoint(loc.lat, loc.lng, loc.placeName ?? '');
        }
        _syncSameRoofAddresses();
        _checkPartnerGeofence(loc);
        if (_partnerWeather == null) {
          _fetchPartnerWeather(loc.lat, loc.lng);
        }
        if (loc.lat != 0.0 || loc.lng != 0.0) {
          if (loc.placeName == null || loc.placeName == 'Nearby' || loc.placeName!.trim().isEmpty || loc.placeName!.toLowerCase() == 'baruipur, baruipur') {
            _reverseGeocodePartner(loc.userId, loc.lat, loc.lng);
          }
        }
        notifyListeners();
      }
    }
  }

  Future<void> _fetchCloudData(String spaceId) async {
    final supabase = SupabaseService.client;
    if (supabase == null) return;

    try {
      final res = await supabase
          .from('app_content')
          .select('content')
          .eq('id', 'location_$spaceId')
          .maybeSingle();

      if (res != null && res['content'] != null && res['content'] is Map) {
        final content = Map<String, dynamic>.from(res['content'] as Map);
        content.forEach((key, val) {
          if (val is Map) {
            final loc = UserLocationData.fromJson(Map<String, dynamic>.from(val));
            if (key == _currentUserId) {
              if (!_locations.containsKey(key)) {
                _locations[key] = loc;
              }
            } else if (_partnerId != null && key == _partnerId) {
              _locations[key] = loc;
              if (loc.lat != 0.0 || loc.lng != 0.0) {
                if (loc.placeName == null || loc.placeName == 'Nearby' || loc.placeName!.trim().isEmpty) {
                  _reverseGeocodePartner(key, loc.lat, loc.lng);
                }
              }
            }
          }
        });
        notifyListeners();
      }
    } catch (_) {}

    try {
      final placesRes = await supabase
          .from('app_content')
          .select('content')
          .eq('id', 'places_$spaceId')
          .maybeSingle();

      if (placesRes != null && placesRes['content'] != null && placesRes['content'] is List) {
        final list = List<dynamic>.from(placesRes['content'] as List);
        _pinnedPlaces = list
            .map((e) => PinnedPlace.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        notifyListeners();
      }
    } catch (_) {}

    // Fetch Shared Date Bucket List from Supabase app_content
    try {
      final bucketRes = await supabase
          .from('app_content')
          .select('content')
          .eq('id', 'bucket_list_$spaceId')
          .maybeSingle();

      if (bucketRes != null && bucketRes['content'] != null && bucketRes['content'] is Map) {
        final content = Map<String, dynamic>.from(bucketRes['content'] as Map);
        final list = content['items'] as List<dynamic>?;
        if (list != null) {
          _bucketList = list
              .map((e) => BucketPlace.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          notifyListeners();
        }
      }
    } catch (_) {}

    // Realtime listener for partner's Bucket List changes
    SupabaseService.setBucketListListener((data) {
      final list = data['items'] as List<dynamic>?;
      if (list != null) {
        _bucketList = list
            .map((e) => BucketPlace.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        notifyListeners();
      }
    });

    // Fetch Genuine Geofence Arrival/Departure Event Log from Supabase app_content
    try {
      final geoRes = await supabase
          .from('app_content')
          .select('content')
          .eq('id', 'geofence_log_$spaceId')
          .maybeSingle();

      if (geoRes != null && geoRes['content'] != null && geoRes['content'] is Map) {
        final content = Map<String, dynamic>.from(geoRes['content'] as Map);
        final list = content['events'] as List<dynamic>?;
        if (list != null) {
          _geofenceEvents = list
              .map((e) => GeofenceEvent.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          notifyListeners();
        }
      }
    } catch (_) {}

    SupabaseService.setGeofenceEventListener((data) {
      final list = data['events'] as List<dynamic>?;
      if (list != null) {
        _geofenceEvents = list
            .map((e) => GeofenceEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        notifyListeners();
      }
    });
  }

  Future<void> _recordGeofenceTransition({
    required PinnedPlace place,
    required String eventType,
    required UserLocationData pLoc,
  }) async {
    final spaceId = _spaceId;
    if (spaceId == null || spaceId.isEmpty) return;

    final ev = GeofenceEvent(
      id: 'geo_${DateTime.now().millisecondsSinceEpoch}_${place.id}',
      placeId: place.id,
      placeName: place.name,
      placeIcon: place.icon,
      eventType: eventType,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      lat: pLoc.lat,
      lng: pLoc.lng,
    );

    _geofenceEvents.insert(0, ev);
    if (_geofenceEvents.length > 40) {
      _geofenceEvents = _geofenceEvents.take(40).toList();
    }
    notifyListeners();

    final eventsJson = _geofenceEvents.map((e) => e.toJson()).toList();
    try {
      await SupabaseService.upsertAppContent('geofence_log_$spaceId', {
        'events': eventsJson,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await SupabaseService.broadcastEvent(
        spaceId: spaceId,
        eventType: 'GEOFENCE_EVENT',
        payload: {'events': eventsJson},
      );
    } catch (_) {}
  }

  void _checkPartnerGeofence(UserLocationData pLoc) {
    if (_pinnedPlaces.isEmpty || pLoc.lat == 0.0 || pLoc.lng == 0.0) return;
    final pName = pLoc.nickname.isNotEmpty ? pLoc.nickname : 'Your Partner';

    // First sync snapshot initializes inside/outside zones without firing false departure spam
    if (!_hasInitializedZones) {
      _hasInitializedZones = true;
      for (final place in _pinnedPlaces) {
        final radiusKm = (place.radiusMeters / 1000.0).clamp(0.15, 2.0);
        final dist = calculateDistanceKm(pLoc.lat, pLoc.lng, place.lat, place.lng);
        if (dist <= radiusKm) {
          _partnerInsideZoneIds.add(place.id);
        }
      }
      return;
    }

    for (final place in _pinnedPlaces) {
      final radiusKm = (place.radiusMeters / 1000.0).clamp(0.15, 2.0);
      final dist = calculateDistanceKm(pLoc.lat, pLoc.lng, place.lat, place.lng);
      final wasInside = _partnerInsideZoneIds.contains(place.id);
      final isNowInside = dist <= radiusKm;

      if (!wasInside && isNowInside) {
        _partnerInsideZoneIds.add(place.id);
        _recordGeofenceTransition(place: place, eventType: 'arrived', pLoc: pLoc);
        NotificationService.showPartnerArrivedPlaceNotification(
          partnerNickname: pName,
          placeName: place.name,
          placeTag: place.icon,
        );
      } else if (wasInside && dist > (radiusKm + 0.08)) {
        // 80m hysteresis buffer prevents GPS jitter false departures
        _partnerInsideZoneIds.remove(place.id);
        _recordGeofenceTransition(place: place, eventType: 'departed', pLoc: pLoc);
        NotificationService.showPartnerDepartedPlaceNotification(
          partnerNickname: pName,
          placeName: place.name,
          placeTag: place.icon,
        );
      }
    }
  }

  Future<void> _fetchPartnerWeather(double lat, double lng) async {
    try {
      final weather = await WeatherService.fetchWeather(lat, lng);
      _partnerWeather = weather;
      if (weather != null) {
        if (weather.isUnnatural) {
          NotificationService.showUnnaturalWeatherAlert(
            partnerNickname: partnerLocation?.nickname ?? 'Your Partner',
            condition: weather.condition,
            tempC: weather.temperature,
          );
        } else if ((weather.weatherCode >= 51 && weather.weatherCode <= 67) ||
            (weather.weatherCode >= 80 && weather.weatherCode <= 82)) {
          // Romantic Rain & Showers Atmospheric Empathy Alert!
          NotificationService.showPartnerRainEmpathyNotification(
            partnerNickname: partnerLocation?.nickname ?? 'Your Partner',
            condition: weather.condition,
          );
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  final Map<String, Map<String, String>> _geocodeCache = {};
  int _lastGeocodeTimestamp = 0;

  /// Starts continuous real-time high-accuracy GPS movement tracking
  Future<void> startLiveTracking({
    required String spaceId,
    required String currentUserId,
    required String nickname,
    String? avatarUrl,
  }) async {
    if (spaceId.isEmpty || currentUserId.isEmpty) return;
    if (_isTrackingInitializing || _positionStreamSub != null) return;
    _isTrackingInitializing = true;

    try {
      _spaceId = spaceId;
      _currentUserId = currentUserId;
      _currentNickname = nickname;
      _currentAvatarUrl = avatarUrl;

      // Check location service toggle on device
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _gpsStatus = 'Location Service Off';
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          _gpsStatus = 'Permission Denied';
          notifyListeners();
          return;
        }
      }

      if (_gpsStatus != 'Location Service Off') {
        _gpsStatus = 'Acquiring GPS...';
      }
      notifyListeners();

      // 1. Immediate initial fix
      try {
        final initialPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        await _handleNewPosition(initialPosition);
      } catch (_) {
        try {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            await _handleNewPosition(lastKnown);
          }
        } catch (_) {}
      }

      // 2. High-precision continuous position stream (15m filter prevents jitter & optimizes battery)
      _positionStreamSub?.cancel();
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      );

      _positionStreamSub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (Position position) {
          _handleNewPosition(position);
        },
        onError: (err) {
          _gpsStatus = 'GPS Error';
          notifyListeners();
        },
      );
    } finally {
      _isTrackingInitializing = false;
    }
  }

  void stopLiveTracking() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _gpsStatus = 'Standby';
    notifyListeners();
  }

  Future<void> _handleNewPosition(Position position) async {
    if (_currentUserId == null || _spaceId == null) return;

    final now = DateTime.now();

    // Smart stationary GPS sleep: suppress micro-jitter & save battery when stationary
    if (_stationaryAnchorLat == null || _stationaryAnchorLng == null) {
      _stationaryAnchorLat = position.latitude;
      _stationaryAnchorLng = position.longitude;
      _stationaryAnchorTime = now;
    } else {
      final driftMeters = calculateDistanceKm(
        _stationaryAnchorLat!,
        _stationaryAnchorLng!,
        position.latitude,
        position.longitude,
      ) * 1000.0;

      if (driftMeters < 18.0) {
        // User is stationary (within 18m drift zone)
        final stationaryMin = _stationaryAnchorTime != null
            ? now.difference(_stationaryAnchorTime!).inMinutes
            : 0;

        // After 2 minutes of staying stationary, throttle broadcasts to once every 4 minutes
        if (stationaryMin >= 2) {
          if (_lastStationaryBroadcastTime != null &&
              now.difference(_lastStationaryBroadcastTime!).inMinutes < 4) {
            // Sleep mode: do not churn CPU or flood WebSocket
            return;
          }
          _lastStationaryBroadcastTime = now;
        }
      } else {
        // User has moved > 18 meters: wake up live tracking
        _stationaryAnchorLat = position.latitude;
        _stationaryAnchorLng = position.longitude;
        _stationaryAnchorTime = now;
        _lastStationaryBroadcastTime = null;
      }
    }

    // Accumulate position into journey log
    _appendMyPoint(position);

    _gpsStatus = (_partnerId != null && _partnerId!.isNotEmpty) ? 'Live Tethered' : 'Live Presence';

    // Reverse geocoding only when moved > 20m or > 1 minute
    bool shouldGeocode = false;
    if (_lastGeocodedLat == null || _lastGeocodedLng == null || _lastGeocodedTime == null) {
      shouldGeocode = true;
    } else {
      final dist = calculateDistanceKm(
        _lastGeocodedLat!,
        _lastGeocodedLng!,
        position.latitude,
        position.longitude,
      );
      if (dist > 0.02 || now.difference(_lastGeocodedTime!).inMinutes >= 1) {
        shouldGeocode = true;
      }
    }

    if (shouldGeocode) {
      _lastGeocodedLat = position.latitude;
      _lastGeocodedLng = position.longitude;
      _lastGeocodedTime = now;
      _reverseGeocode(position.latitude, position.longitude);
    }

    final walkingKm = myWalkingKmToday;
    final journeyKm = myJourneyKmToday;
    final steps = (walkingKm * 1300).round();
    final activeMinutes = (walkingKm / 4.5 * 60).round();

    if (_firstPlaceNameToday == null && _cachedPlaceName.isNotEmpty && _cachedPlaceName != 'Nearby') {
      _firstPlaceNameToday = _cachedPlaceName;
    }

    _recordMyStayPoint(position.latitude, position.longitude, _cachedPlaceName);

    final myLocation = UserLocationData(
      userId: _currentUserId!,
      nickname: _currentNickname ?? 'You',
      avatarUrl: _currentAvatarUrl,
      lat: position.latitude,
      lng: position.longitude,
      placeName: _cachedPlaceName,
      neighborhood: _cachedNeighborhood,
      city: _cachedCity,
      customLabel: _locations[_currentUserId]?.customLabel,
      accuracy: position.accuracy,
      isSharingEnabled: _isSharing,
      updatedAt: now.toUtc().toIso8601String(),
      journeyKmToday: journeyKm,
      stepsToday: steps,
      activeMinutesToday: activeMinutes,
      departurePlace: _firstPlaceNameToday ?? _cachedPlaceName,
      timeZoneOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      speedMps: position.speed >= 0 ? position.speed : 0.0,
      stayPoints: _myStayPoints.map((s) => s.toJson()).toList(),
    );

    _locations[_currentUserId!] = myLocation;
    _syncSameRoofAddresses();
    notifyListeners();

    // Instant WebSocket broadcast to partner (0-50ms)
    if (!_spaceId!.startsWith('solo_')) {
      SupabaseService.broadcastEvent(
        spaceId: _spaceId!,
        eventType: 'LOCATION_UPDATE',
        payload: {'location': myLocation.toJson()},
      );
    }

    // Debounced Firestore sync to preserve free quotas
    _scheduleCloudPersist(myLocation);
  }

  void _scheduleCloudPersist(UserLocationData location) {
    _cloudDebounce?.cancel();
    _cloudDebounce = Timer(const Duration(seconds: 4), () async {
      if (_spaceId == null || _spaceId!.isEmpty || _spaceId!.startsWith('solo_')) return;

      try {
        // Multi-device safe dot-notation update: never clobbers partner!
        await FirebaseService.saveNestedFeatureField(
          _spaceId!,
          'locations',
          'locations.${location.userId}',
          location.toJson(),
          rootDefaults: {'locations': {}},
        );

        // Supabase app_content merge
        final supabase = SupabaseService.client;
        if (supabase != null) {
          final map = _locations.map((k, v) => MapEntry(k, v.toJson()));
          await supabase.from('app_content').upsert({
            'id': 'location_$_spaceId',
            'content': map,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (_) {}
    });
  }

  String _buildFormattedPlaceName({
    String? landmark,
    String? road,
    String? suburb,
    String? city,
    String? state,
    String? rawDisplayName,
  }) {
    final cleanLandmark = (landmark ?? '').trim();
    final cleanRoad = (road ?? '').trim();
    final cleanSuburb = (suburb ?? '').trim();
    final cleanCity = (city ?? '').trim();
    final cleanState = (state ?? '').trim();

    String specific = '';
    if (cleanLandmark.isNotEmpty) {
      specific = cleanLandmark;
    } else if (cleanRoad.isNotEmpty) {
      specific = cleanRoad;
    } else if (cleanSuburb.isNotEmpty) {
      specific = cleanSuburb;
    }

    String broad = '';
    if (specific.isNotEmpty && specific.toLowerCase() == cleanSuburb.toLowerCase()) {
      broad = cleanCity.isNotEmpty ? cleanCity : cleanState;
    } else if (cleanSuburb.isNotEmpty && cleanSuburb.toLowerCase() != specific.toLowerCase()) {
      broad = cleanSuburb;
    } else if (cleanCity.isNotEmpty && cleanCity.toLowerCase() != specific.toLowerCase()) {
      broad = cleanCity;
    } else if (cleanState.isNotEmpty) {
      broad = cleanState;
    }

    if (specific.isEmpty && broad.isEmpty) {
      if (rawDisplayName != null && rawDisplayName.isNotEmpty) {
        final parts = rawDisplayName.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(2).toList();
        return _deduplicateAddressParts(parts);
      }
      return 'Nearby';
    }

    if (specific.isEmpty) return broad;
    if (broad.isEmpty) return specific;

    if (specific.toLowerCase() == broad.toLowerCase()) {
      if (cleanState.isNotEmpty && cleanState.toLowerCase() != specific.toLowerCase()) {
        return '$specific, $cleanState';
      }
      return specific;
    }

    if (specific.toLowerCase().contains(broad.toLowerCase())) return specific;
    if (broad.toLowerCase().contains(specific.toLowerCase())) return broad;

    return '$specific, $broad';
  }

  String _deduplicateAddressParts(List<String> parts) {
    final seen = <String>{};
    final unique = <String>[];
    for (final p in parts) {
      final lower = p.toLowerCase().trim();
      if (lower.isNotEmpty && !seen.contains(lower)) {
        seen.add(lower);
        unique.add(p.trim());
      }
    }
    return unique.isNotEmpty ? unique.join(', ') : 'Nearby';
  }

  void _syncSameRoofAddresses() {
    if (_currentUserId == null || _partnerId == null) return;
    final myLoc = _locations[_currentUserId];
    final partnerLoc = _locations[_partnerId];
    if (myLoc == null || partnerLoc == null) return;
    if (myLoc.lat == 0.0 || partnerLoc.lat == 0.0) return;

    final distKm = calculateDistanceKm(myLoc.lat, myLoc.lng, partnerLoc.lat, partnerLoc.lng);
    if (distKm <= 0.06) {
      final myPlace = myLoc.placeName ?? '';
      final pPlace = partnerLoc.placeName ?? '';

      final myIsSpecific = myPlace.contains(',') && !myPlace.contains('Nearby') && !myPlace.toLowerCase().contains('baruipur, baruipur');
      final pIsSpecific = pPlace.contains(',') && !pPlace.contains('Nearby') && !pPlace.toLowerCase().contains('baruipur, baruipur');

      if (myIsSpecific && !pIsSpecific) {
        _locations[_partnerId!] = partnerLoc.copyWith(
          placeName: myPlace,
          neighborhood: myLoc.neighborhood,
          city: myLoc.city,
        );
      } else if (pIsSpecific && !myIsSpecific) {
        _locations[_currentUserId!] = myLoc.copyWith(
          placeName: pPlace,
          neighborhood: partnerLoc.neighborhood,
          city: partnerLoc.city,
        );
        _cachedPlaceName = pPlace;
      }
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    final cacheKey = '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
    if (_geocodeCache.containsKey(cacheKey)) {
      final cached = _geocodeCache[cacheKey]!;
      _cachedPlaceName = cached['place'] ?? '';
      _cachedNeighborhood = cached['neighborhood'] ?? '';
      _cachedCity = cached['city'] ?? '';
      if (_currentUserId != null && _locations.containsKey(_currentUserId)) {
        _locations[_currentUserId!] = _locations[_currentUserId!]!.copyWith(
          placeName: _cachedPlaceName,
          neighborhood: _cachedNeighborhood,
          city: _cachedCity,
        );
        _syncSameRoofAddresses();
        notifyListeners();
      }
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastGeocodeTimestamp < 2500 && _cachedPlaceName.isNotEmpty) {
      return;
    }
    _lastGeocodeTimestamp = nowMs;

    try {
      final geoUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final resp = await http.get(geoUrl, headers: {'User-Agent': 'PagesOfUsApp/1.0 (contact@pagesofus.app)'}).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final geoData = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr = geoData['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final road = (addr['road'] ?? addr['pedestrian'] ?? addr['street'] ?? addr['footway'] ?? '').toString().trim();
          final landmark = (addr['amenity'] ?? addr['building'] ?? addr['shop'] ?? addr['leisure'] ?? addr['tourism'] ?? '').toString().trim();
          final suburb = (addr['suburb'] ?? addr['neighbourhood'] ?? addr['residential'] ?? addr['quarter'] ?? '').toString().trim();
          final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? addr['state_district'] ?? '').toString().trim();
          final state = (addr['state'] ?? '').toString().trim();

          _cachedNeighborhood = suburb.isNotEmpty ? suburb : (road.isNotEmpty ? road : city);
          _cachedCity = city;
          _cachedPlaceName = _buildFormattedPlaceName(
            landmark: landmark,
            road: road,
            suburb: suburb,
            city: city,
            state: state,
            rawDisplayName: geoData['display_name']?.toString(),
          );

          _geocodeCache[cacheKey] = {
            'place': _cachedPlaceName,
            'neighborhood': _cachedNeighborhood,
            'city': _cachedCity,
          };

          if (_currentUserId != null && _locations.containsKey(_currentUserId)) {
            _locations[_currentUserId!] = _locations[_currentUserId!]!.copyWith(
              placeName: _cachedPlaceName,
              neighborhood: _cachedNeighborhood,
              city: _cachedCity,
            );
            _syncSameRoofAddresses();
            notifyListeners();
          }
        }
      } else {
        await _fallbackBigDataCloud(lat, lng, cacheKey);
      }
    } catch (_) {
      await _fallbackBigDataCloud(lat, lng, cacheKey);
    }
  }

  Future<void> _fallbackBigDataCloud(double lat, double lng, String cacheKey) async {
    try {
      final url = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=en',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final locality = data['locality']?.toString().trim() ?? '';
        final city = (data['city'] ?? data['principalSubdivision'] ?? '').toString().trim();
        final state = (data['principalSubdivision'] ?? '').toString().trim();
        _cachedNeighborhood = locality;
        _cachedCity = city;
        _cachedPlaceName = _buildFormattedPlaceName(
          suburb: locality,
          city: city,
          state: state,
        );

        _geocodeCache[cacheKey] = {
          'place': _cachedPlaceName,
          'neighborhood': _cachedNeighborhood,
          'city': _cachedCity,
        };
        if (_currentUserId != null && _locations.containsKey(_currentUserId)) {
          _locations[_currentUserId!] = _locations[_currentUserId!]!.copyWith(
            placeName: _cachedPlaceName,
            neighborhood: _cachedNeighborhood,
            city: _cachedCity,
          );
          _syncSameRoofAddresses();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Reverse geocodes the partner's coordinates with full zoom=18 detail
  Future<void> _reverseGeocodePartner(String partnerId, double lat, double lng) async {
    if (lat == 0.0 && lng == 0.0) return;
    final cacheKey = 'partner_${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
    if (_geocodeCache.containsKey(cacheKey)) {
      final cached = _geocodeCache[cacheKey]!;
      final place = cached['place'] ?? '';
      if (place.isNotEmpty && _locations.containsKey(partnerId)) {
        _locations[partnerId] = _locations[partnerId]!.copyWith(
          placeName: place,
          neighborhood: cached['neighborhood'],
          city: cached['city'],
        );
        _syncSameRoofAddresses();
        notifyListeners();
      }
      return;
    }

    // 1. Try Nominatim OpenStreetMap at zoom=18 for full neighborhood accuracy
    try {
      final geoUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final resp = await http.get(geoUrl, headers: {
        'User-Agent': 'PagesOfUsApp/1.0 (contact@pagesofus.app)',
      }).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final geoData = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr = geoData['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final road = (addr['road'] ?? addr['pedestrian'] ?? addr['street'] ?? addr['footway'] ?? '').toString().trim();
          final landmark = (addr['amenity'] ?? addr['building'] ?? addr['shop'] ?? addr['leisure'] ?? addr['tourism'] ?? '').toString().trim();
          final suburb = (addr['suburb'] ?? addr['neighbourhood'] ?? addr['residential'] ?? addr['town'] ?? addr['village'] ?? '').toString().trim();
          final city = (addr['city'] ?? addr['county'] ?? addr['state_district'] ?? '').toString().trim();
          final state = (addr['state'] ?? '').toString().trim();

          final place = _buildFormattedPlaceName(
            landmark: landmark,
            road: road,
            suburb: suburb,
            city: city,
            state: state,
            rawDisplayName: geoData['display_name']?.toString(),
          );

          _geocodeCache[cacheKey] = {
            'place': place,
            'neighborhood': suburb.isNotEmpty ? suburb : (road.isNotEmpty ? road : city),
            'city': city,
          };
          if (_locations.containsKey(partnerId)) {
            _locations[partnerId] = _locations[partnerId]!.copyWith(
              placeName: place,
              neighborhood: suburb.isNotEmpty ? suburb : (road.isNotEmpty ? road : city),
              city: city,
            );
            _syncSameRoofAddresses();
            notifyListeners();
          }
          return;
        }
      }
    } catch (_) {}

    // 2. Try Photon reverse geocode
    try {
      final photonUrl = Uri.parse('https://photon.komoot.io/reverse?lat=$lat&lon=$lng');
      final resp = await http.get(photonUrl).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          final props = features.first['properties'] as Map<String, dynamic>?;
          if (props != null) {
            final name = (props['name'] ?? '').toString().trim();
            final street = (props['street'] ?? '').toString().trim();
            final city = (props['city'] ?? props['county'] ?? props['district'] ?? '').toString().trim();
            final state = (props['state'] ?? '').toString().trim();

            final placeName = _buildFormattedPlaceName(
              landmark: street.isNotEmpty ? name : '',
              road: street,
              suburb: street.isEmpty ? name : '',
              city: city,
              state: state,
            );

            if (placeName.isNotEmpty) {
              _geocodeCache[cacheKey] = {
                'place': placeName,
                'neighborhood': name.isNotEmpty ? name : street,
                'city': city,
              };
              if (_locations.containsKey(partnerId)) {
                _locations[partnerId] = _locations[partnerId]!.copyWith(
                  placeName: placeName,
                  neighborhood: name.isNotEmpty ? name : street,
                  city: city,
                );
                _syncSameRoofAddresses();
                notifyListeners();
              }
              return;
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Manual force-refresh triggered by "Update GPS"
  Future<void> updateMyPosition({
    required String spaceId,
    required String currentUserId,
    required String nickname,
    String? avatarUrl,
    String? customTag,
  }) async {
    if (spaceId.isEmpty || currentUserId.isEmpty) return;

    _isLoading = true;
    _gpsStatus = 'Locating GPS...';
    notifyListeners();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      _spaceId = spaceId;
      _currentUserId = currentUserId;
      _currentNickname = nickname;
      _currentAvatarUrl = avatarUrl;

      if (customTag != null) {
        if (_locations.containsKey(currentUserId)) {
          _locations[currentUserId] = _locations[currentUserId]!.copyWith(customLabel: customTag);
        }
      }

      await _handleNewPosition(position);
    } catch (e) {
      _gpsStatus = 'GPS Unavailable';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPinnedPlace({
    required String spaceId,
    required String name,
    required String icon,
    required double lat,
    required double lng,
    required double radiusMeters,
    required String currentUserId,
  }) async {
    if (spaceId.isEmpty) return;

    final newPlace = PinnedPlace(
      id: 'place_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      icon: icon,
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      createdById: currentUserId,
      createdAt: DateTime.now().toIso8601String(),
    );

    _pinnedPlaces.add(newPlace);
    notifyListeners();

    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('app_content').upsert({
          'id': 'places_$spaceId',
          'content': _pinnedPlaces.map((e) => e.toJson()).toList(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('features')
          .doc('locations')
          .set({
        'places': _pinnedPlaces.map((e) => e.toJson()).toList(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> deletePinnedPlace({
    required String spaceId,
    required String placeId,
  }) async {
    if (spaceId.isEmpty) return;

    _pinnedPlaces.removeWhere((p) => p.id == placeId);
    notifyListeners();

    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('app_content').upsert({
          'id': 'places_$spaceId',
          'content': _pinnedPlaces.map((e) => e.toJson()).toList(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('features')
          .doc('locations')
          .set({
        'places': _pinnedPlaces.map((e) => e.toJson()).toList(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> toggleSharing({
    required String spaceId,
    required String currentUserId,
  }) async {
    if (spaceId.isEmpty || currentUserId.isEmpty) return;

    _isSharing = !_isSharing;
    if (_locations.containsKey(currentUserId)) {
      final updated = _locations[currentUserId]!.copyWith(isSharingEnabled: _isSharing);
      _locations[currentUserId] = updated;
      _scheduleCloudPersist(updated);
      SupabaseService.broadcastEvent(
        spaceId: spaceId,
        eventType: 'LOCATION_UPDATE',
        payload: {'location': updated.toJson()},
      );
    }
    notifyListeners();
  }

  Future<void> clearLocationHistory(String spaceId) async {
    if (spaceId.isEmpty) return;

    _locations.clear();
    notifyListeners();

    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.from('app_content').upsert({
          'id': 'location_$spaceId',
          'content': {},
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('features')
          .doc('locations')
          .delete();
    } catch (_) {}
  }

  // ── Shared Date Bucket List ────────────────────────────────────────────────
  Future<void> _persistBucketList(String spaceId) async {
    if (spaceId.isEmpty) return;
    final itemsJson = _bucketList.map((e) => e.toJson()).toList();
    try {
      await SupabaseService.upsertAppContent('bucket_list_$spaceId', {
        'items': itemsJson,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await SupabaseService.broadcastEvent(
        spaceId: spaceId,
        eventType: 'BUCKET_LIST_UPDATE',
        payload: {'items': itemsJson},
      );
    } catch (_) {}
  }

  Future<void> addToBucketList({
    required String spaceId,
    required String name,
    required String category,
    required String icon,
    required String address,
    required double lat,
    required double lng,
    required String googleMapsUrl,
    required String addedById,
    required String addedByNickname,
  }) async {
    if (spaceId.isEmpty || name.trim().isEmpty) return;
    if (isInBucketList(name, lat, lng)) return;

    final item = BucketPlace(
      id: 'bkt_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      category: category,
      icon: icon,
      address: address,
      lat: lat,
      lng: lng,
      googleMapsUrl: googleMapsUrl.isNotEmpty
          ? googleMapsUrl
          : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      addedById: addedById,
      addedByNickname: addedByNickname,
      addedAt: DateTime.now().toIso8601String(),
    );

    _bucketList.insert(0, item);
    notifyListeners();
    await _persistBucketList(spaceId);
  }

  Future<void> toggleBucketVisited({
    required String spaceId,
    required String placeId,
    String? note,
  }) async {
    final idx = _bucketList.indexWhere((b) => b.id == placeId);
    if (idx == -1) return;
    final current = _bucketList[idx];
    final nextVisited = !current.isVisited;
    _bucketList[idx] = current.copyWith(
      isVisited: nextVisited,
      visitedAt: nextVisited ? DateTime.now().toIso8601String() : null,
      note: note ?? current.note,
    );
    notifyListeners();
    await _persistBucketList(spaceId);
  }

  Future<void> removeFromBucketList({
    required String spaceId,
    required String placeId,
  }) async {
    _bucketList.removeWhere((b) => b.id == placeId);
    notifyListeners();
    await _persistBucketList(spaceId);
  }

  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    final rawClean = query.trim();
    if (rawClean.isEmpty) return [];

    // Check if user entered direct lat, lng coordinates e.g. "28.6139, 77.2090"
    final coordMatch = RegExp(r'^([-+]?[0-9]*\.?[0-9]+)[\s,]+([-+]?[0-9]*\.?[0-9]+)$').firstMatch(rawClean);
    if (coordMatch != null) {
      final lat = coordMatch.group(1);
      final lon = coordMatch.group(2);
      return [
        {
          'display_name': 'Coordinates: $lat, $lon',
          'lat': lat,
          'lon': lon,
          'name': 'Direct Coordinates',
        }
      ];
    }

    // Normalize "nearby me" / "near me" & common typos so OpenStreetMap APIs actually find nearby POIs
    final lower = rawClean.toLowerCase();
    final wantsNearby = lower.contains('nearby') ||
        lower.contains('near me') ||
        lower.contains('around me') ||
        lower.contains('close to me') ||
        lower.contains('close by') ||
        lower.contains('near here');

    String clean = rawClean
        .replaceAll(
          RegExp(
            r'\b(nearby me|near me|around me|close to me|close by|near here|nearby)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.toLowerCase() == 'caffe' || clean.toLowerCase() == 'coffeeshop') {
      clean = 'cafe';
    } else if (clean.toLowerCase() == 'resturant' || clean.toLowerCase() == 'restorant') {
      clean = 'restaurant';
    } else if (clean.toLowerCase() == 'cinma') {
      clean = 'cinema';
    }
    if (clean.isEmpty) clean = rawClean;

    final myLoc = myLocation;
    final hasLoc = myLoc != null && (myLoc.lat != 0.0 || myLoc.lng != 0.0);
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addCandidate({
      required String name,
      required String displayName,
      required double lat,
      required double lng,
      String? type,
    }) {
      final key = '${name.toLowerCase()}_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
      if (seen.contains(key)) return;
      seen.add(key);

      final distKm = hasLoc ? calculateDistanceKm(myLoc.lat, myLoc.lng, lat, lng) : null;
      results.add({
        'display_name': displayName.isNotEmpty ? displayName : name,
        'lat': lat.toString(),
        'lon': lng.toString(),
        'name': name.isNotEmpty ? name : 'Place',
        if (type != null) 'type': type,
        if (distKm != null) 'distance_km': distKm,
      });
    }

    // Run Photon (with live coordinate bias!) + Nominatim bounded/global in parallel
    final futures = <Future<void>>[];

    futures.add(() async {
      try {
        final locBias = hasLoc ? '&lat=${myLoc.lat}&lon=${myLoc.lng}' : '';
        final photonUrl = Uri.parse(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(clean)}$locBias&limit=12',
        );
        final res = await http.get(photonUrl, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          final features = data['features'] as List<dynamic>? ?? [];
          for (final f in features) {
            final props = f['properties'] as Map<String, dynamic>?;
            final coords = f['geometry']?['coordinates'] as List<dynamic>?;
            if (props != null && coords != null && coords.length >= 2) {
              final lon = (coords[0] as num).toDouble();
              final lat = (coords[1] as num).toDouble();
              if (wantsNearby && hasLoc && calculateDistanceKm(myLoc.lat, myLoc.lng, lat, lon) > 45.0) {
                continue;
              }
              final name = (props['name'] ?? '').toString();
              final street = (props['street'] ?? '').toString();
              final city = (props['city'] ?? props['county'] ?? props['district'] ?? '').toString();
              final state = (props['state'] ?? '').toString();
              final country = (props['country'] ?? '').toString();

              final parts = [name, street, city, state, country]
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList();
              addCandidate(
                name: name.isNotEmpty ? name : (city.isNotEmpty ? city : clean),
                displayName: parts.join(', '),
                lat: lat,
                lng: lon,
                type: props['osm_value']?.toString(),
              );
            }
          }
        }
      } catch (_) {}
    }());

    futures.add(() async {
      try {
        String nomQueryUrl = 'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(clean)}&addressdetails=1&limit=10';
        if (hasLoc && wantsNearby) {
          const delta = 0.25;
          final west = (myLoc.lng - delta).toStringAsFixed(5);
          final east = (myLoc.lng + delta).toStringAsFixed(5);
          final north = (myLoc.lat + delta).toStringAsFixed(5);
          final south = (myLoc.lat - delta).toStringAsFixed(5);
          nomQueryUrl += '&viewbox=$west,$north,$east,$south&bounded=1';
        }
        final res = await http.get(
          Uri.parse(nomQueryUrl),
          headers: {'User-Agent': 'PagesOfUsApp/1.0 (contact@pagesofus.app)'},
        ).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
          for (final item in list) {
            final m = Map<String, dynamic>.from(item as Map);
            final lat = double.tryParse(m['lat']?.toString() ?? '');
            final lon = double.tryParse(m['lon']?.toString() ?? '');
            if (lat == null || lon == null) continue;
            final display = m['display_name']?.toString() ?? '';
            final rawName = (m['name']?.toString() ?? '').trim();
            final name = rawName.isNotEmpty
                ? rawName
                : (display.contains(',') ? display.split(',').first.trim() : display);
            addCandidate(
              name: name,
              displayName: display,
              lat: lat,
              lng: lon,
              type: m['type']?.toString(),
            );
          }
        }
      } catch (_) {}
    }());

    await Future.wait(futures);

    if (hasLoc && results.isNotEmpty) {
      results.sort((a, b) => ((a['distance_km'] as double?) ?? 99999.0).compareTo((b['distance_km'] as double?) ?? 99999.0));
    }

    return results.take(15).toList();
  }
}
