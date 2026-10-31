import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/user_location_model.dart';
import '../data/models/pinned_place.dart';
import '../data/services/firebase_service.dart';
import '../data/services/supabase_service.dart';
import '../core/services/weather_service.dart';
import '../core/services/notification_service.dart';

class WorldProvider extends ChangeNotifier {
  final Map<String, UserLocationData> _locations = {};
  List<PinnedPlace> _pinnedPlaces = [];
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

  Map<String, UserLocationData> get locations => Map.unmodifiable(_locations);
  List<PinnedPlace> get pinnedPlaces => List.unmodifiable(_pinnedPlaces);
  bool get isSharing => _isSharing;
  bool get isLoading => _isLoading;
  String get gpsStatus => _gpsStatus;
  WeatherInfo? get partnerWeather => _partnerWeather;
  DateTime get now => _now;
  bool _isTrackingInitializing = false;
  bool get isLiveTrackingActive => _positionStreamSub != null || _isTrackingInitializing;

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
    _startClockTimer();
  }

  void _startClockTimer() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _now = DateTime.now();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _cloudDebounce?.cancel();
    _firestoreSub?.cancel();
    _positionStreamSub?.cancel();
    SupabaseService.removeLocationListener(_handleSupabaseLocationUpdate);
    super.dispose();
  }

  UserLocationData? getUserLocation(String? userId) {
    if (userId == null) return null;
    return _locations[userId];
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
              } else if (_partnerId != null && key == _partnerId) {
                _locations[key] = loc;
                hasChanges = true;
              }
            }
          });

          if (hasChanges) {
            if (_partnerId != null && _locations[_partnerId] != null) {
              final pLoc = _locations[_partnerId]!;
              _fetchPartnerWeather(pLoc.lat, pLoc.lng);
              _checkPartnerGeofence(pLoc);
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
    }
  }

  void _handleSupabaseLocationUpdate(Map<String, dynamic> data) {
    if (data['location'] != null && data['location'] is Map) {
      final loc = UserLocationData.fromJson(Map<String, dynamic>.from(data['location'] as Map));
      if (_partnerId != null && loc.userId == _partnerId) {
        _locations[loc.userId] = loc;
        _checkPartnerGeofence(loc);
        if (_partnerWeather == null) {
          _fetchPartnerWeather(loc.lat, loc.lng);
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
  }

  void _checkPartnerGeofence(UserLocationData pLoc) {
    if (_pinnedPlaces.isEmpty || pLoc.lat == 0.0 || pLoc.lng == 0.0) return;
    for (final place in _pinnedPlaces) {
      final dist = calculateDistanceKm(pLoc.lat, pLoc.lng, place.lat, place.lng);
      // Within 300 meters
      if (dist <= 0.3) {
        NotificationService.showPartnerArrivedPlaceNotification(
          partnerNickname: pLoc.nickname.isNotEmpty ? pLoc.nickname : 'Your Partner',
          placeName: place.name,
          placeTag: place.icon,
        );
        break;
      }
    }
  }

  Future<void> _fetchPartnerWeather(double lat, double lng) async {
    try {
      final weather = await WeatherService.fetchWeather(lat, lng);
      _partnerWeather = weather;
      if (weather != null && weather.isUnnatural) {
        NotificationService.showUnnaturalWeatherAlert(
          partnerNickname: partnerLocation?.nickname ?? 'Your Partner',
          condition: weather.condition,
          tempC: weather.temperature,
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  final Map<String, Map<String, String>> _geocodeCache = {};

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

      // 2. High-performance continuous position stream (fires on 25m movement for battery & quota safety)
      _positionStreamSub?.cancel();
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
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

    _gpsStatus = (_partnerId != null && _partnerId!.isNotEmpty) ? 'Live Tethered' : 'Live Presence';

    // Reverse geocoding only when moved > 60m or > 2 minutes
    final now = DateTime.now();
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
      if (dist > 0.06 || now.difference(_lastGeocodedTime!).inMinutes >= 2) {
        shouldGeocode = true;
      }
    }

    if (shouldGeocode) {
      _lastGeocodedLat = position.latitude;
      _lastGeocodedLng = position.longitude;
      _lastGeocodedTime = now;
      _reverseGeocode(position.latitude, position.longitude);
    }

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
      updatedAt: now.toIso8601String(),
    );

    _locations[_currentUserId!] = myLocation;
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
        notifyListeners();
      }
      return;
    }

    try {
      final geoUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final resp = await http.get(geoUrl, headers: {'User-Agent': 'PagesOfUsApp/1.0 (contact@pagesofus.app)'});
      if (resp.statusCode == 200) {
        final geoData = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr = geoData['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final road = (addr['road'] ?? addr['pedestrian'] ?? addr['street'] ?? addr['footway'] ?? '').toString().trim();
          final landmark = (addr['amenity'] ?? addr['building'] ?? addr['shop'] ?? addr['leisure'] ?? addr['tourism'] ?? '').toString().trim();
          final suburb = (addr['suburb'] ?? addr['neighbourhood'] ?? addr['residential'] ?? addr['quarter'] ?? '').toString().trim();
          final city = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? addr['state_district'] ?? addr['state'] ?? '').toString().trim();

          _cachedNeighborhood = suburb.isNotEmpty ? suburb : (road.isNotEmpty ? road : city);
          _cachedCity = city;

          if (landmark.isNotEmpty) {
            _cachedPlaceName = suburb.isNotEmpty ? '$landmark, $suburb' : landmark;
          } else if (road.isNotEmpty) {
            _cachedPlaceName = suburb.isNotEmpty ? '$road, $suburb' : (city.isNotEmpty ? '$road, $city' : road);
          } else if (suburb.isNotEmpty) {
            _cachedPlaceName = city.isNotEmpty ? '$suburb, $city' : suburb;
          } else {
            final displayName = geoData['display_name']?.toString() ?? '';
            final parts = displayName.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).take(2).toList();
            _cachedPlaceName = parts.isNotEmpty ? parts.join(', ') : 'Nearby';
          }

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
            notifyListeners();
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

  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=5',
      );
      final res = await http.get(url, headers: {'User-Agent': 'PagesOfUs/1.0'});
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }
}
