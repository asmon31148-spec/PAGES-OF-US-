import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// Data model for real, authentic places returned by Date Planner
class DatePlaceOption {
  final String id;
  final String name;
  final String category;
  final String categoryIcon;
  final double lat;
  final double lng;
  final String? photoUrl;
  final double? rating;
  final int? userRatingsTotal;
  final String priceLevel;
  final bool isOpenNow;
  final String openStatusText;
  final double distanceKmUser;
  final double distanceKmPartner;
  final String userTravelTime;
  final String partnerTravelTime;
  final bool isRecommended;
  final String recommendationReason;
  final String googleMapsUrl;
  final String address;
  final bool isGoogleVerified;

  const DatePlaceOption({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryIcon,
    required this.lat,
    required this.lng,
    this.photoUrl,
    this.rating,
    this.userRatingsTotal,
    required this.priceLevel,
    required this.isOpenNow,
    required this.openStatusText,
    required this.distanceKmUser,
    required this.distanceKmPartner,
    required this.userTravelTime,
    required this.partnerTravelTime,
    required this.isRecommended,
    required this.recommendationReason,
    required this.googleMapsUrl,
    required this.address,
    this.isGoogleVerified = false,
  });

  String get vicinity => address;
}

class DatePlannerResult {
  final String userQuery;
  final String mode; // 'near_user', 'near_partner', or 'meeting_halfway'
  final String modeDescription;
  final List<DatePlaceOption> places;
  final String? fairTravelNote;
  final String? error;
  final String? googleMapsSearchUrl;
  final bool isGooglePlacesVerified;

  const DatePlannerResult({
    required this.userQuery,
    required this.mode,
    required this.modeDescription,
    required this.places,
    this.fairTravelNote,
    this.error,
    this.googleMapsSearchUrl,
    this.isGooglePlacesVerified = false,
  });
}

/// Date Planner Live Authentic Service:
/// 1. Understands location intent ("near me", "near her", "between us").
/// 2. Fetches 100% REAL, verified places from Google Places API (New) or OpenStreetMap.
/// 3. Computes accurate Haversine travel distances & times for BOTH partners.
/// 4. ZERO fake, hallucinated, or synthesized places — ever.
class DatePlannerService {
  DatePlannerService._();
  static final instance = DatePlannerService._();

  final Map<String, DatePlannerResult> _cache = {};

  Future<DatePlannerResult> planDate({
    required String query,
    required double userLat,
    required double userLng,
    required String userCity,
    required double partnerLat,
    required double partnerLng,
    required String partnerCity,
    required String partnerNickname,
    bool forceHalfwayMode = false,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return const DatePlannerResult(
        userQuery: '',
        mode: 'meeting_halfway',
        modeDescription: '',
        places: [],
        error: 'Please enter what you are looking for (e.g. library, quiet cafe, scenic park).',
      );
    }

    final cacheKey =
        '${cleanQuery.toLowerCase()}_${userLat.toStringAsFixed(2)}_${partnerLat.toStringAsFixed(2)}_$forceHalfwayMode';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // Step 1: Live AI Intent & Location Anchor Parsing
      final parsedIntent = await _understandIntentWithAi(
        query: cleanQuery,
        userCity: userCity.isNotEmpty ? userCity : 'Your location',
        partnerCity: partnerCity.isNotEmpty ? partnerCity : 'Partner location',
        partnerNickname: partnerNickname,
      );

      final target = forceHalfwayMode ? 'midpoint' : parsedIntent['target'] ?? 'midpoint';
      final category = parsedIntent['category'] ?? 'cafe';
      final searchTerm = parsedIntent['searchTerm'] ?? cleanQuery;
      final categoryIcon = parsedIntent['icon'] ?? '📍';
      final radiusMeters = int.tryParse(parsedIntent['radiusMeters'] ?? '5000') ?? 5000;

      double anchorLat;
      double anchorLng;
      String anchorCity;
      String mode;
      String modeDescription;
      String? fairTravelNote;

      final straightDistance = _calculateHaversineKm(userLat, userLng, partnerLat, partnerLng);

      if (target == 'user' && userLat != 0.0) {
        anchorLat = userLat;
        anchorLng = userLng;
        anchorCity = userCity.isNotEmpty ? userCity : 'Your City';
        mode = 'near_user';
        modeDescription = 'Searching near you in $anchorCity 📍';
      } else if (target == 'partner' && partnerLat != 0.0) {
        anchorLat = partnerLat;
        anchorLng = partnerLng;
        anchorCity = partnerCity.isNotEmpty ? partnerCity : 'Partner City';
        mode = 'near_partner';
        modeDescription = 'Searching near $partnerNickname in $anchorCity 📍';
      } else {
        // Default: Midpoint between both partners
        anchorLat = (userLat != 0.0 && partnerLat != 0.0)
            ? (userLat + partnerLat) / 2
            : (userLat != 0.0 ? userLat : partnerLat);
        anchorLng = (userLng != 0.0 && partnerLng != 0.0)
            ? (userLng + partnerLng) / 2
            : (userLng != 0.0 ? userLng : partnerLng);
        anchorCity = userCity.isNotEmpty && partnerCity.isNotEmpty
            ? '$userCity & $partnerCity'
            : 'Between you both';
        mode = 'meeting_halfway';
        modeDescription = 'Meeting halfway between $userCity and $partnerCity ✦';
        if (straightDistance > 5) {
          fairTravelNote = 'Midpoint date spot ~${(straightDistance / 2).round()} km for each of you.';
        }
      }

      final gMapsSearchUrl =
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$searchTerm near $anchorCity')}';

      // Step 2: Try Google Places API (New) for 100% verified Google Maps places
      bool isGoogleVerified = false;
      List<Map<String, dynamic>> rawPlaces = await _fetchPlacesGooglePlaces(
        lat: anchorLat,
        lng: anchorLng,
        category: category,
        searchTerm: searchTerm,
        radiusMeters: radiusMeters,
      );

      if (rawPlaces.isNotEmpty) {
        isGoogleVerified = true;
      } else {
        // Step 3: Fallback to real OpenStreetMap Overpass (with expanding radius up to 35km)
        rawPlaces = await _fetchRealPlacesOSM(
          lat: anchorLat,
          lng: anchorLng,
          category: category,
          searchTerm: searchTerm,
          cityName: anchorCity,
          radiusMeters: radiusMeters,
        );
      }

      // CRITICAL: Under NO circumstance do we synthesize or invent places with AI.
      // If no verified places exist in local radius, return empty with live Google Maps search link.
      if (rawPlaces.isEmpty) {
        final emptyResult = DatePlannerResult(
          userQuery: cleanQuery,
          mode: mode,
          modeDescription: modeDescription,
          places: [],
          fairTravelNote: fairTravelNote,
          googleMapsSearchUrl: gMapsSearchUrl,
          isGooglePlacesVerified: false,
          error: 'No registered spots found nearby in local registry.',
        );
        _cache[cacheKey] = emptyResult;
        return emptyResult;
      }

      // Step 4: Map to DatePlaceOption with genuine Haversine distances for BOTH partners
      final placeOptions = <DatePlaceOption>[];
      for (final p in rawPlaces) {
        final pLat = (p['lat'] as num?)?.toDouble() ?? 0.0;
        final pLng = (p['lng'] as num?)?.toDouble() ?? 0.0;
        if (pLat == 0.0 || pLng == 0.0) continue;

        final name = p['name']?.toString() ?? 'Venue';
        final address = p['address']?.toString() ?? anchorCity;

        final distUser = _calculateHaversineKm(userLat, userLng, pLat, pLng);
        final distPartner = _calculateHaversineKm(partnerLat, partnerLng, pLat, pLng);

        final mapsUrl = p['google_maps_url']?.toString() ??
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$name $address')}';

        final isOpen = p['is_open'] as bool? ?? true;
        final placeIsGoogle = p['is_google_verified'] as bool? ?? false;

        placeOptions.add(DatePlaceOption(
          id: p['id']?.toString() ?? 'place_${pLat}_$pLng',
          name: name,
          category: p['type']?.toString() ?? category,
          categoryIcon: categoryIcon,
          lat: pLat,
          lng: pLng,
          photoUrl: p['photo_url']?.toString(),
          rating: (p['rating'] as num?)?.toDouble(), // Genuine rating or null (NO fake random ratings!)
          userRatingsTotal: (p['reviews'] as num?)?.toInt(), // Genuine reviews or null
          priceLevel: p['price_level']?.toString() ?? 'Moderate',
          isOpenNow: isOpen,
          openStatusText: isOpen ? 'Open now' : 'Closed',
          distanceKmUser: distUser,
          distanceKmPartner: distPartner,
          userTravelTime: _formatTravelTime(distUser),
          partnerTravelTime: _formatTravelTime(distPartner),
          isRecommended: false,
          recommendationReason: p['reason']?.toString() ?? 'Real venue for quality time together.',
          googleMapsUrl: mapsUrl,
          address: address,
          isGoogleVerified: placeIsGoogle,
        ));
      }

      if (placeOptions.isEmpty) {
        final emptyResult = DatePlannerResult(
          userQuery: cleanQuery,
          mode: mode,
          modeDescription: modeDescription,
          places: [],
          fairTravelNote: fairTravelNote,
          googleMapsSearchUrl: gMapsSearchUrl,
          isGooglePlacesVerified: false,
          error: 'No registered spots found nearby.',
        );
        _cache[cacheKey] = emptyResult;
        return emptyResult;
      }

      // Step 5: Rank genuine places with AI (only selects best pick among REAL spots)
      final rankedPlaces = await _rankPlacesWithAi(
        places: placeOptions,
        query: cleanQuery,
        partnerNickname: partnerNickname,
        mode: mode,
      );

      final result = DatePlannerResult(
        userQuery: cleanQuery,
        mode: mode,
        modeDescription: modeDescription,
        places: rankedPlaces,
        fairTravelNote: fairTravelNote,
        googleMapsSearchUrl: gMapsSearchUrl,
        isGooglePlacesVerified: isGoogleVerified,
      );

      _cache[cacheKey] = result;
      return result;
    } catch (e) {
      debugPrint('[DatePlannerService] planDate error: $e');
      return DatePlannerResult(
        userQuery: cleanQuery,
        mode: 'meeting_halfway',
        modeDescription: 'Date search',
        places: [],
        error: 'Unable to reach places service. Please check connection and try again.',
        googleMapsSearchUrl:
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$cleanQuery near me')}',
      );
    }
  }

  /// AI Intent & Target Parsing via Groq (Categorization only, NEVER generates places)
  Future<Map<String, String>> _understandIntentWithAi({
    required String query,
    required String userCity,
    required String partnerCity,
    required String partnerNickname,
  }) async {
    final apiKey = AppConstants.groqApiKey;
    if (apiKey.isEmpty) {
      return _ruleBasedParse(query);
    }

    try {
      final prompt = '''
You are an AI place and date query parser for Pages of Us.
User City: "$userCity", Partner ($partnerNickname) City: "$partnerCity".
User query: "$query"

Extract JSON:
{
  "target": "user" | "partner" | "midpoint", // "user" if query mentions "near me", "around me", "my location", "here"; "partner" if query mentions "near her", "near partner", "around her", "$partnerCity"; "midpoint" if between us/halfway or if no location preference given
  "category": string, // e.g. "library", "cafe", "restaurant", "park", "bookstore", "hotel", "rooftop"
  "searchTerm": string, // clean place search term
  "radiusMeters": string, // e.g. 100 meters -> "200", 500m -> "500", default "5000"
  "icon": string // emoji
}
Output JSON only.
''';

      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'qwen/qwen3.8-27b',
          'temperature': 0.1,
          'max_tokens': 150,
          'messages': [
            {'role': 'system', 'content': prompt},
            {'role': 'user', 'content': 'Parse query now.'},
          ],
          'response_format': {'type': 'json_object'},
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final content = data['choices'][0]['message']['content']?.toString() ?? '';
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        return {
          'target': decoded['target']?.toString() ?? 'midpoint',
          'category': decoded['category']?.toString() ?? 'place',
          'searchTerm': decoded['searchTerm']?.toString() ?? query,
          'radiusMeters': decoded['radiusMeters']?.toString() ?? '5000',
          'icon': decoded['icon']?.toString() ?? '📍',
        };
      }
    } catch (e) {
      debugPrint('[DatePlannerService] _understandIntentWithAi fallback: $e');
    }

    return _ruleBasedParse(query);
  }

  Map<String, String> _ruleBasedParse(String query) {
    final q = query.toLowerCase();
    String target = 'midpoint';
    if (q.contains('near me') ||
        q.contains('around me') ||
        q.contains('from me') ||
        q.contains('my city') ||
        q.contains('close to me')) {
      target = 'user';
    } else if (q.contains('near her') ||
        q.contains('around her') ||
        q.contains('near him') ||
        q.contains('her city') ||
        q.contains('near partner')) {
      target = 'partner';
    }

    String category = 'cafe';
    String icon = '☕';
    if (q.contains('library') || q.contains('book')) {
      category = 'library';
      icon = '📚';
    } else if (q.contains('park') || q.contains('garden')) {
      category = 'park';
      icon = '🌿';
    } else if (q.contains('dinner') || q.contains('food') || q.contains('restaurant')) {
      category = 'restaurant';
      icon = '🍷';
    } else if (q.contains('beach') || q.contains('sea')) {
      category = 'beach';
      icon = '🏖️';
    } else if (q.contains('hotel') || q.contains('stay')) {
      category = 'hotel';
      icon = '🏨';
    }

    String radius = '5000';
    if (q.contains('100m') || q.contains('100 meters')) {
      radius = '200';
    } else if (q.contains('500m') || q.contains('500 meters')) {
      radius = '500';
    } else if (q.contains('1km') || q.contains('1 km')) {
      radius = '1200';
    }

    return {
      'target': target,
      'category': category,
      'searchTerm': category,
      'radiusMeters': radius,
      'icon': icon,
    };
  }

  /// 1. Google Places API (New) verified places
  Future<List<Map<String, dynamic>>> _fetchPlacesGooglePlaces({
    required double lat,
    required double lng,
    required String category,
    required String searchTerm,
    required int radiusMeters,
  }) async {
    final apiKey = AppConstants.firebaseApiKey;
    if (apiKey.isEmpty || lat == 0.0 || lng == 0.0) return [];

    try {
      List<String> includedTypes = ['cafe', 'coffee_shop'];
      final catLower = category.toLowerCase();
      if (catLower.contains('park') || catLower.contains('garden')) {
        includedTypes = ['park', 'garden', 'national_park'];
      } else if (catLower.contains('restaurant') ||
          catLower.contains('dinner') ||
          catLower.contains('food')) {
        includedTypes = ['restaurant', 'fine_dining_restaurant', 'indian_restaurant'];
      } else if (catLower.contains('library') || catLower.contains('book')) {
        includedTypes = ['library', 'book_store'];
      } else if (catLower.contains('movie') || catLower.contains('cinema')) {
        includedTypes = ['movie_theater'];
      }

      final url = Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.priceLevel,places.currentOpeningHours,places.googleMapsUri',
        },
        body: jsonEncode({
          'includedTypes': includedTypes,
          'maxResultCount': 8,
          'locationRestriction': {
            'circle': {
              'center': {
                'latitude': lat,
                'longitude': lng,
              },
              'radius': math.min(50000.0, radiusMeters.toDouble().clamp(3000.0, 50000.0)),
            },
          },
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final rawPlaces = data['places'] as List?;
        if (rawPlaces != null && rawPlaces.isNotEmpty) {
          final results = <Map<String, dynamic>>[];
          for (final item in rawPlaces) {
            final m = item as Map<String, dynamic>;
            final loc = m['location'] as Map<String, dynamic>?;
            final pLat = (loc?['latitude'] as num?)?.toDouble();
            final pLng = (loc?['longitude'] as num?)?.toDouble();
            final name = m['displayName']?['text']?.toString();
            if (pLat == null || pLng == null || name == null || name.isEmpty) continue;

            final address = m['formattedAddress']?.toString() ?? '';
            final rating = (m['rating'] as num?)?.toDouble();
            final userRatingCount = (m['userRatingCount'] as num?)?.toInt();
            final priceLevelRaw = m['priceLevel']?.toString() ?? '';
            String priceLevel = 'Moderate';
            if (priceLevelRaw.contains('FREE') || priceLevelRaw.contains('INEXPENSIVE')) {
              priceLevel = 'Budget-friendly';
            } else if (priceLevelRaw.contains('EXPENSIVE') || priceLevelRaw.contains('VERY_EXPENSIVE')) {
              priceLevel = 'Fine Dining';
            }

            final isOpen = m['currentOpeningHours']?['openNow'] as bool? ?? true;
            final googleUri = m['googleMapsUri']?.toString() ??
                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$name $address')}';

            results.add({
              'id': m['id']?.toString() ?? 'g_${pLat}_$pLng',
              'name': name,
              'type': category.toUpperCase(),
              'lat': pLat,
              'lng': pLng,
              'rating': rating,
              'reviews': userRatingCount,
              'price_level': priceLevel,
              'address': address,
              'is_open': isOpen,
              'google_maps_url': googleUri,
              'is_google_verified': true,
            });
          }
          if (results.isNotEmpty) return results;
        }
      }
    } catch (e) {
      debugPrint('[DatePlannerService] Google Places API note: $e');
    }

    return [];
  }

  /// 2. Real place lookup using OpenStreetMap Overpass (with expanding radius up to 35km)
  Future<List<Map<String, dynamic>>> _fetchRealPlacesOSM({
    required double lat,
    required double lng,
    required String category,
    required String searchTerm,
    required String cityName,
    required int radiusMeters,
  }) async {
    final places = <Map<String, dynamic>>[];
    if (lat == 0.0 || lng == 0.0) return places;

    // Search radii: try local radius first, then widen to 35km if in rural/suburban area
    final searchRadii = [
      radiusMeters.clamp(5000, 15000),
      35000,
    ];

    for (final radius in searchRadii) {
      try {
        final query = '''
[out:json][timeout:8];
(
  node["amenity"~"cafe|restaurant|fast_food|tea|ice_cream|library"](around:$radius,$lat,$lng);
  node["leisure"~"park|garden"](around:$radius,$lat,$lng);
);
out center 12;
''';
        final res = await http.post(
          Uri.parse('https://overpass-api.de/api/interpreter'),
          headers: {
            'User-Agent': 'PagesOfUs/1.0 (https://pagesofus.app; support@pagesofus.app)',
            'Accept': 'application/json',
          },
          body: {'data': query},
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          final elements = (data['elements'] as List? ?? []);
          for (final el in elements) {
            final tags = el['tags'] as Map<String, dynamic>? ?? {};
            final name = tags['name']?.toString()?.trim();
            if (name == null || name.isEmpty) continue;

            final pLat = (el['lat'] ?? el['center']?['lat'] as num?)?.toDouble();
            final pLng = (el['lon'] ?? el['center']?['lon'] as num?)?.toDouble();
            if (pLat == null || pLng == null) continue;

            // Avoid duplicates
            if (!places.any((p) => p['name'] == name)) {
              final street = tags['addr:street']?.toString();
              final city = tags['addr:city']?.toString() ?? tags['addr:suburb']?.toString();
              final addr = (street != null && city != null)
                  ? '$street, $city'
                  : (city ?? street ?? cityName);

              places.add({
                'id': 'osm_${el['id']}',
                'name': name,
                'type': tags['amenity'] ?? tags['leisure'] ?? category,
                'lat': pLat,
                'lng': pLng,
                'rating': null, // NO FAKE RATINGS
                'reviews': null, // NO FAKE REVIEWS
                'price_level': tags['cuisine'] != null ? 'Moderate' : 'Budget-friendly',
                'address': addr,
                'is_open': true,
                'google_maps_url':
                    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$name $addr')}',
                'is_google_verified': false,
              });
            }
          }
        }
      } catch (e) {
        debugPrint('[DatePlannerService] Overpass query error: $e');
      }

      if (places.length >= 3) break;
    }

    return places;
  }

  /// AI Ranking & Romantic Reason (purely analyzes the REAL candidates, never invents places)
  Future<List<DatePlaceOption>> _rankPlacesWithAi({
    required List<DatePlaceOption> places,
    required String query,
    required String partnerNickname,
    required String mode,
  }) async {
    if (places.isEmpty) return [];

    final apiKey = AppConstants.groqApiKey;
    if (apiKey.isEmpty || places.length == 1) {
      final updated = List<DatePlaceOption>.from(places);
      updated[0] = _copyOptionWithRecommended(
        updated[0],
        true,
        'Top recommended spot for $partnerNickname and you ✦',
      );
      return updated;
    }

    try {
      final summaryList = places.map((p) => {
        'name': p.name,
        'category': p.category,
        'rating': p.rating,
        'address': p.address,
      }).toList();

      final prompt = '''
For a loving couple using "Pages of Us", pick the single best recommendation from this list of real places:
Query: "$query", Mode: "$mode", Partner: "$partnerNickname"
Options: ${jsonEncode(summaryList)}

Output JSON:
{
  "best_name": "Name of best venue",
  "reason": "1 short evocative sentence on why it's the most romantic pick"
}
''';

      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'qwen/qwen3.8-27b',
          'temperature': 0.2,
          'max_tokens': 120,
          'messages': [
            {'role': 'system', 'content': prompt},
            {'role': 'user', 'content': 'Pick best venue.'},
          ],
          'response_format': {'type': 'json_object'},
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final content = data['choices'][0]['message']['content']?.toString() ?? '';
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        final bestName = decoded['best_name']?.toString() ?? '';
        final reason = decoded['reason']?.toString() ?? 'Most intimate pick for you two.';

        final updated = <DatePlaceOption>[];
        for (int i = 0; i < places.length; i++) {
          final p = places[i];
          final isBest = (bestName.isNotEmpty && p.name.toLowerCase().contains(bestName.toLowerCase())) ||
              (i == 0 && !places.any((x) => x.name.toLowerCase().contains(bestName.toLowerCase())));

          updated.add(_copyOptionWithRecommended(p, isBest, isBest ? reason : p.recommendationReason));
        }

        updated.sort((a, b) => (b.isRecommended ? 1 : 0).compareTo(a.isRecommended ? 1 : 0));
        return updated;
      }
    } catch (_) {}

    final updated = List<DatePlaceOption>.from(places);
    updated[0] = _copyOptionWithRecommended(
      updated[0],
      true,
      'Ideal spot for quality time with $partnerNickname ✦',
    );
    return updated;
  }

  DatePlaceOption _copyOptionWithRecommended(DatePlaceOption p, bool isRec, String reason) {
    return DatePlaceOption(
      id: p.id,
      name: p.name,
      category: p.category,
      categoryIcon: p.categoryIcon,
      lat: p.lat,
      lng: p.lng,
      photoUrl: p.photoUrl,
      rating: p.rating,
      userRatingsTotal: p.userRatingsTotal,
      priceLevel: p.priceLevel,
      isOpenNow: p.isOpenNow,
      openStatusText: p.openStatusText,
      distanceKmUser: p.distanceKmUser,
      distanceKmPartner: p.distanceKmPartner,
      userTravelTime: p.userTravelTime,
      partnerTravelTime: p.partnerTravelTime,
      isRecommended: isRec,
      recommendationReason: reason,
      googleMapsUrl: p.googleMapsUrl,
      address: p.address,
      isGoogleVerified: p.isGoogleVerified,
    );
  }

  double _calculateHaversineKm(double lat1, double lon1, double lat2, double lon2) {
    if (lat1 == 0.0 || lon1 == 0.0 || lat2 == 0.0 || lon2 == 0.0) return 0.0;
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  String _formatTravelTime(double distanceKm) {
    if (distanceKm <= 0.1) return 'Steps away';
    if (distanceKm < 1.0) return '~${(distanceKm * 1000).round()}m';
    if (distanceKm < 2.0) return '~${(distanceKm * 15).round()} min walk';
    final carMinutes = (distanceKm / 40.0 * 60).round();
    if (carMinutes < 60) return '~$carMinutes mins by car';
    final hours = carMinutes ~/ 60;
    final rem = carMinutes % 60;
    return rem > 0 ? '~${hours}h ${rem}m' : '~${hours}h drive';
  }
}
