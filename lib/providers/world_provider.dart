import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/user_location_model.dart';
import '../data/models/pinned_place.dart';
import '../data/services/supabase_service.dart';
import '../core/services/weather_service.dart';

class WorldProvider extends ChangeNotifier {
  Map<String, UserLocationData> _locations = {};
  List<PinnedPlace> _pinnedPlaces = [];
  bool _isSharing = true;
  bool _isLoading = false;
  String _gpsStatus = 'Standby';
  WeatherInfo? _partnerWeather;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  StreamSubscription? _firestoreSub;
  RealtimeChannel? _supabaseChannel;

  Map<String, UserLocationData> get locations => _locations;
  List<PinnedPlace> get pinnedPlaces => _pinnedPlaces;
  bool get isSharing => _isSharing;
  bool get isLoading => _isLoading;
  String get gpsStatus => _gpsStatus;
  WeatherInfo? get partnerWeather => _partnerWeather;
  DateTime get now => _now;

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
    _firestoreSub?.cancel();
    if (_supabaseChannel != null) {
      SupabaseService.client?.removeChannel(_supabaseChannel!);
    }
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
    _fetchCloudData(spaceId);

    // 1. Supabase Realtime channel
    final supabase = SupabaseService.client;
    if (supabase != null) {
      _supabaseChannel = supabase
          .channel('locations_space_$spaceId')
          .onBroadcast(
            event: 'LOCATION_UPDATE',
            callback: (payload) {
              if (payload['location'] != null) {
                final loc = UserLocationData.fromJson(
                    Map<String, dynamic>.from(payload['location']));
                _locations[loc.userId] = loc;
                notifyListeners();
              }
            },
          )
          .subscribe();
    }

    // 2. Firestore real-time snapshot
    try {
      _firestoreSub = FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('features')
          .doc('locations')
          .snapshots()
          .listen((snap) {
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          if (data['locations'] != null) {
            final map = Map<String, dynamic>.from(data['locations']);
            map.forEach((key, val) {
              _locations[key] =
                  UserLocationData.fromJson(Map<String, dynamic>.from(val));
            });
            if (partnerId != null && _locations[partnerId] != null) {
              final pLoc = _locations[partnerId]!;
              _fetchPartnerWeather(pLoc.lat, pLoc.lng);
            }
            notifyListeners();
          }
          if (data['places'] != null) {
            final list = List<dynamic>.from(data['places']);
            _pinnedPlaces = list
                .map((e) => PinnedPlace.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            notifyListeners();
          }
        }
      });
    } catch (_) {}

    // Check weather for partner if location exists
    if (partnerId != null && _locations[partnerId] != null) {
      final pLoc = _locations[partnerId]!;
      _fetchPartnerWeather(pLoc.lat, pLoc.lng);
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

      if (res != null && res['content'] != null) {
        final content = Map<String, dynamic>.from(res['content']);
        content.forEach((key, val) {
          _locations[key] =
              UserLocationData.fromJson(Map<String, dynamic>.from(val));
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

      if (placesRes != null && placesRes['content'] != null) {
        final list = List<dynamic>.from(placesRes['content']);
        _pinnedPlaces = list
            .map((e) => PinnedPlace.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _fetchPartnerWeather(double lat, double lng) async {
    try {
      final weather = await WeatherService.fetchWeather(lat, lng);
      _partnerWeather = weather;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateMyPosition({
    required String spaceId,
    required String currentUserId,
    required String nickname,
    String? avatarUrl,
    String? customTag,
  }) async {
    _isLoading = true;
    _gpsStatus = 'Acquiring GPS...';
    notifyListeners();

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _gpsStatus = 'Permission Denied';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _gpsStatus = 'Locating place...';
      notifyListeners();

      // Reverse geocode via Nominatim
      String placeName = 'Nearby';
      String city = '';
      String neighborhood = '';

      try {
        final geoUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}',
        );
        final resp = await http.get(geoUrl, headers: {'User-Agent': 'PagesOfUs/1.0'});
        if (resp.statusCode == 200) {
          final geoData = jsonDecode(resp.body) as Map<String, dynamic>;
          final addr = geoData['address'] as Map<String, dynamic>?;
          if (addr != null) {
            neighborhood = addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? '';
            city = addr['city'] ?? addr['town'] ?? addr['state'] ?? '';
            placeName = neighborhood.isNotEmpty
                ? '$neighborhood, $city'
                : (geoData['display_name']?.toString().split(',').first ?? 'Nearby');
          }
        }
      } catch (_) {}

      final myLocation = UserLocationData(
        userId: currentUserId,
        nickname: nickname,
        avatarUrl: avatarUrl,
        lat: position.latitude,
        lng: position.longitude,
        placeName: placeName,
        neighborhood: neighborhood,
        city: city,
        customLabel: customTag ?? _locations[currentUserId]?.customLabel,
        accuracy: position.accuracy,
        isSharingEnabled: _isSharing,
        updatedAt: DateTime.now().toIso8601String(),
      );

      _locations[currentUserId] = myLocation;
      _gpsStatus = 'Live Tethered';
      notifyListeners();

      await _broadcastLocation(spaceId, myLocation);
    } catch (e) {
      _gpsStatus = 'GPS Unavailable';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _broadcastLocation(String spaceId, UserLocationData location) async {
    // 1. Supabase app_content upsert
    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        final currentMap = _locations.map((k, v) => MapEntry(k, v.toJson()));
        await supabase.from('app_content').upsert({
          'id': 'location_$spaceId',
          'content': currentMap,
          'updated_at': DateTime.now().toIso8601String(),
        });

        _supabaseChannel?.sendBroadcastMessage(
          event: 'LOCATION_UPDATE',
          payload: {'location': location.toJson()},
        );
      }
    } catch (_) {}

    // 2. Firestore sync (Safe update with dot notation so partner location is never erased)
    try {
      final docRef = FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .collection('features')
          .doc('locations');

      try {
        await docRef.update({
          'locations.${location.userId}': location.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        await docRef.set({
          'locations': {
            location.userId: location.toJson(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
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
    _isSharing = !_isSharing;
    if (_locations.containsKey(currentUserId)) {
      final updated = _locations[currentUserId]!.copyWith(isSharingEnabled: _isSharing);
      _locations[currentUserId] = updated;
      await _broadcastLocation(spaceId, updated);
    }
    notifyListeners();
  }

  Future<void> clearLocationHistory(String spaceId) async {
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
