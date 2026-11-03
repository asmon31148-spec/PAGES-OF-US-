import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─── Data Models ─────────────────────────────────────────────────────────────

class DriveRoute {
  final double distanceKm;
  final int durationMinutes;
  final String googleMapsUrl;

  const DriveRoute({
    required this.distanceKm,
    required this.durationMinutes,
    required this.googleMapsUrl,
  });
}

class TransitOption {
  final String type; // 'train' or 'flight'
  final String name; // e.g. "Indian Railways", "IndiGo"
  final int durationMinutes;
  final String priceEstimate; // e.g. "₹250 – ₹1,200"
  final String deepLink;
  final String? operatorCode;

  const TransitOption({
    required this.type,
    required this.name,
    required this.durationMinutes,
    required this.priceEstimate,
    required this.deepLink,
    this.operatorCode,
  });
}

class NearbyHotel {
  final String name;
  final double lat;
  final double lng;
  final double distanceKm; // from midpoint
  final int? stars;
  final String googleMapsUrl;

  const NearbyHotel({
    required this.name,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    this.stars,
    required this.googleMapsUrl,
  });
}

class CityPhoto {
  final String city;
  final String? photoUrl;
  final String? description;

  const CityPhoto({
    required this.city,
    this.photoUrl,
    this.description,
  });
}

class TravelRouteResult {
  final DriveRoute? drive;
  final List<TransitOption> transit;
  final List<NearbyHotel> hotels;
  final CityPhoto? myCity;
  final CityPhoto? partnerCity;
  final String? error;

  const TravelRouteResult({
    this.drive,
    this.transit = const [],
    this.hotels = const [],
    this.myCity,
    this.partnerCity,
    this.error,
  });
}

// ─── Service ─────────────────────────────────────────────────────────────────

class TravelRouteService {
  TravelRouteService._();
  static final instance = TravelRouteService._();

  /// Optional Rome2Rio API key (set this from your app config / env).
  /// If null, transit section falls back to Google Flights & IRCTC deep links.
  static String? rome2rioKey;

  /// Fetch all travel info between two coordinate pairs.
  Future<TravelRouteResult> fetchAll({
    required double myLat,
    required double myLng,
    required String myCity,
    required double partnerLat,
    required double partnerLng,
    required String partnerCity,
  }) async {
    // Run everything concurrently
    final results = await Future.wait([
      _fetchDrive(myLat, myLng, partnerLat, partnerLng),
      _fetchTransit(myLat, myLng, partnerLat, partnerLng, myCity, partnerCity),
      _fetchHotels(myLat, myLng, partnerLat, partnerLng),
      _fetchCityPhoto(myCity),
      _fetchCityPhoto(partnerCity),
    ]);

    return TravelRouteResult(
      drive: results[0] as DriveRoute?,
      transit: results[1] as List<TransitOption>,
      hotels: results[2] as List<NearbyHotel>,
      myCity: results[3] as CityPhoto?,
      partnerCity: results[4] as CityPhoto?,
    );
  }

  // ── OSRM — Free, no key needed ────────────────────────────────────────────
  Future<DriveRoute?> _fetchDrive(
    double lat1, double lng1,
    double lat2, double lng2,
  ) async {
    try {
      // OSRM coordinate order: longitude,latitude
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$lng1,$lat1;$lng2,$lat2?overview=false',
      );
      final resp = await http
          .get(url, headers: {'User-Agent': 'PagesOfUsApp/1.0'})
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final distanceM = (route['distance'] as num?)?.toDouble() ?? 0;
      final durationS = (route['duration'] as num?)?.toDouble() ?? 0;

      final googleUrl =
          'https://www.google.com/maps/dir/?api=1&origin=$lat1,$lng1&destination=$lat2,$lng2&travelmode=driving';

      return DriveRoute(
        distanceKm: distanceM / 1000,
        durationMinutes: (durationS / 60).round(),
        googleMapsUrl: googleUrl,
      );
    } catch (e) {
      debugPrint('[TravelRoute] OSRM error: $e');
      return null;
    }
  }

  // ── Rome2Rio or graceful fallback ─────────────────────────────────────────
  Future<List<TransitOption>> _fetchTransit(
    double lat1, double lng1,
    double lat2, double lng2,
    String city1, String city2,
  ) async {
    if (rome2rioKey != null && rome2rioKey!.isNotEmpty) {
      return _rome2rio(lat1, lng1, lat2, lng2);
    }
    // Fallback: build helpful deep links without API key
    return _buildFallbackTransit(lat1, lng1, lat2, lng2, city1, city2);
  }

  Future<List<TransitOption>> _rome2rio(
    double lat1, double lng1,
    double lat2, double lng2,
  ) async {
    try {
      final url = Uri.parse(
        'https://free.rome2rio.com/api/1.4/json/Search'
        '?key=${rome2rioKey!}'
        '&oPos=$lat1,$lng1'
        '&dPos=$lat2,$lng2'
        '&currencyCode=INR',
      );
      final resp = await http
          .get(url, headers: {'User-Agent': 'PagesOfUsApp/1.0'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return _buildFallbackTransit(lat1, lng1, lat2, lng2, '', '');

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = data['routes'] as List? ?? [];
      final List<TransitOption> options = [];

      for (final r in routes.take(6)) {
        final rMap = r as Map<String, dynamic>;
        final name = rMap['name']?.toString() ?? 'Route';
        final dur = (rMap['duration'] as num?)?.toInt() ?? 0;
        final segments = rMap['segments'] as List? ?? [];

        // Determine type by looking at segment vehicles
        bool hasFlight = segments.any((s) {
          final v = (s as Map)['vehicle'] as Map?;
          return v?['kind'] == 'plane' || v?['kind'] == 'flight';
        });
        final type = hasFlight ? 'flight' : 'train';

        // Price from indicative fare
        final indicative = rMap['indicativePrice'] as Map<String, dynamic>?;
        final low = indicative?['low'];
        final high = indicative?['high'];
        final priceStr = (low != null && high != null)
            ? '₹${_fmt(low)} – ₹${_fmt(high)}'
            : 'See site';

        final bookLink = 'https://www.rome2rio.com/';
        options.add(TransitOption(
          type: type,
          name: name,
          durationMinutes: dur,
          priceEstimate: priceStr,
          deepLink: bookLink,
        ));
      }
      return options;
    } catch (e) {
      debugPrint('[TravelRoute] Rome2Rio error: $e');
      return _buildFallbackTransit(lat1, lng1, lat2, lng2, '', '');
    }
  }

  List<TransitOption> _buildFallbackTransit(
    double lat1, double lng1,
    double lat2, double lng2,
    String city1, String city2,
  ) {
    // IRCTC deep link for train
    final irctcLink =
        'https://www.irctc.co.in/nget/train-search';

    // Google Flights deep link
    final flightsLink =
        'https://www.google.com/travel/flights?q=Flights+from+${Uri.encodeComponent(city1)}+to+${Uri.encodeComponent(city2)}';

    // RedBus for buses
    final redbusLink =
        'https://www.redbus.in/';

    return [
      TransitOption(
        type: 'train',
        name: 'Indian Railways (IRCTC)',
        durationMinutes: 0, // unknown without API
        priceEstimate: 'Tap to check',
        deepLink: irctcLink,
      ),
      TransitOption(
        type: 'flight',
        name: 'Google Flights',
        durationMinutes: 0,
        priceEstimate: 'Tap to search',
        deepLink: flightsLink,
      ),
      TransitOption(
        type: 'bus',
        name: 'RedBus',
        durationMinutes: 0,
        priceEstimate: 'Tap to check',
        deepLink: redbusLink,
      ),
    ];
  }

  // ── Overpass (OpenStreetMap) — free hotels near midpoint ─────────────────
  Future<List<NearbyHotel>> _fetchHotels(
    double lat1, double lng1,
    double lat2, double lng2,
  ) async {
    try {
      // Geographic midpoint
      final midLat = (lat1 + lat2) / 2;
      final midLng = (lng1 + lng2) / 2;

      // Overpass QL: hotels within 15 km of midpoint
      final query =
          '[out:json][timeout:10];'
          'node[tourism=hotel](around:15000,$midLat,$midLng);'
          'out 8;';
      final url = Uri.parse('https://overpass-api.de/api/interpreter');
      final resp = await http
          .post(url, body: {'data': query})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final elements = data['elements'] as List? ?? [];
      final List<NearbyHotel> hotels = [];

      for (final el in elements) {
        final m = el as Map<String, dynamic>;
        final hLat = (m['lat'] as num?)?.toDouble() ?? 0;
        final hLng = (m['lon'] as num?)?.toDouble() ?? 0;
        final tags = m['tags'] as Map<String, dynamic>? ?? {};
        final name = tags['name']?.toString() ?? tags['brand']?.toString() ?? 'Hotel';
        final stars = int.tryParse(tags['stars']?.toString() ?? '');
        final dist = _haversineKm(midLat, midLng, hLat, hLng);

        hotels.add(NearbyHotel(
          name: name,
          lat: hLat,
          lng: hLng,
          distanceKm: dist,
          stars: stars,
          googleMapsUrl:
              'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}&center=$hLat,$hLng',
        ));
      }

      // Sort by distance from midpoint
      hotels.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return hotels;
    } catch (e) {
      debugPrint('[TravelRoute] Overpass error: $e');
      return [];
    }
  }

  // ── Wikimedia — city header photo (free, no key) ──────────────────────────
  Future<CityPhoto?> _fetchCityPhoto(String city) async {
    if (city.isEmpty || city == 'Nearby') return CityPhoto(city: city);
    try {
      // Grab just the city portion (first segment)
      final cityOnly = city.split(',').first.trim();
      final url = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(cityOnly)}',
      );
      final resp = await http
          .get(url, headers: {'User-Agent': 'PagesOfUsApp/1.0'})
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return CityPhoto(city: cityOnly);

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final thumb = data['thumbnail'] as Map<String, dynamic>?;
      final photoUrl = thumb?['source']?.toString();
      final description = data['description']?.toString();

      return CityPhoto(
        city: cityOnly,
        photoUrl: photoUrl,
        description: description,
      );
    } catch (e) {
      debugPrint('[TravelRoute] Wikimedia error: $e');
      return CityPhoto(city: city);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    return n > 999 ? '${(n / 1000).toStringAsFixed(0)}k' : '$n';
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lng2 - lng1) * p)) / 2;
    return 12742 * asin(sqrt(a.clamp(0.0, 1.0)));
  }
}
