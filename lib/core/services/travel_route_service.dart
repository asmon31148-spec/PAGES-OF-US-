import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class ReunionItineraryStop {
  final String time;
  final String title;
  final String location;
  final String description;
  final String icon;

  const ReunionItineraryStop({
    required this.time,
    required this.title,
    required this.location,
    required this.description,
    required this.icon,
  });

  factory ReunionItineraryStop.fromJson(Map<String, dynamic> json) {
    return ReunionItineraryStop(
      time: json['time']?.toString() ?? '',
      title: json['title']?.toString() ?? json['activity']?.toString() ?? 'Romantic Stop',
      location: json['location']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '📍',
    );
  }

  Map<String, dynamic> toJson() => {
    'time': time,
    'title': title,
    'location': location,
    'description': description,
    'icon': icon,
  };
}

class ReunionItinerary {
  final String title;
  final String meetupCity;
  final String romanticVibe;
  final List<ReunionItineraryStop> stops;
  final String packingTip;
  final String surpriseIdea;

  const ReunionItinerary({
    required this.title,
    required this.meetupCity,
    required this.romanticVibe,
    required this.stops,
    required this.packingTip,
    required this.surpriseIdea,
  });

  factory ReunionItinerary.fromJson(Map<String, dynamic> json) {
    final list = json['schedule'] as List? ?? json['stops'] as List? ?? [];
    return ReunionItinerary(
      title: json['date_title']?.toString() ?? json['title']?.toString() ?? 'Romantic Reunion Plan',
      meetupCity: json['meetup_city']?.toString() ?? 'Halfway Point',
      romanticVibe: json['romantic_vibe']?.toString() ?? 'Cozy & Romantic',
      stops: list
          .map((e) => ReunionItineraryStop.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      packingTip: json['packing_tip']?.toString() ??
          json['notes']?.toString() ??
          'Wear comfortable shoes and bring a sweet smile.',
      surpriseIdea: json['surprise_idea']?.toString() ??
          'Bring a handwritten love letter or their favorite chocolates.',
    );
  }

  Map<String, dynamic> toJson() => {
    'date_title': title,
    'meetup_city': meetupCity,
    'romantic_vibe': romanticVibe,
    'schedule': stops.map((s) => s.toJson()).toList(),
    'packing_tip': packingTip,
    'surprise_idea': surpriseIdea,
  };
}

class DriveRoute {
  final double distanceKm;
  final int durationMinutes;
  final String googleMapsUrl;

  const DriveRoute({
    required this.distanceKm,
    required this.durationMinutes,
    required this.googleMapsUrl,
  });

  String get durationString {
    if (durationMinutes < 60) {
      return '$durationMinutes mins';
    }
    final hrs = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return mins > 0 ? '${hrs}h ${mins}m' : '${hrs}h';
  }
}

class MeetingWeather {
  final double temperature;
  final String condition;
  final String icon;
  final String advice;

  const MeetingWeather({
    required this.temperature,
    required this.condition,
    required this.icon,
    required this.advice,
  });
}

class MidpointSpot {
  final String name;
  final String category; // 'cafe', 'park', 'restaurant', 'hotel'
  final double distanceKm;
  final String icon;

  const MidpointSpot({
    required this.name,
    required this.category,
    required this.distanceKm,
    required this.icon,
  });
}

class TransitEstimate {
  final String mode; // 'Train', 'Bus', 'Flight'
  final String duration;
  final String priceEstimate;
  final String tip;
  final String icon;

  const TransitEstimate({
    required this.mode,
    required this.duration,
    required this.priceEstimate,
    required this.tip,
    required this.icon,
  });
}

class TravelRouteResult {
  final DriveRoute? drive;
  final ReunionItinerary? itinerary;
  final MeetingWeather? weather;
  final List<MidpointSpot> nearbySpots;
  final List<TransitEstimate> transitEstimates;
  final double midLat;
  final double midLng;
  final String midCity;
  final double distanceKm;
  final String? error;

  const TravelRouteResult({
    this.drive,
    this.itinerary,
    this.weather,
    this.nearbySpots = const [],
    this.transitEstimates = const [],
    required this.midLat,
    required this.midLng,
    required this.midCity,
    required this.distanceKm,
    this.error,
  });
}

// ─── Service ─────────────────────────────────────────────────────────────────

class TravelRouteService {
  TravelRouteService._();
  static final instance = TravelRouteService._();

  /// Main concurrent fetch: Generates AI Itinerary, live Drive Route, live Weather, and real Spots
  Future<TravelRouteResult> fetchAll({
    required double myLat,
    required double myLng,
    required String myCity,
    required double partnerLat,
    required double partnerLng,
    required String partnerCity,
    required String myName,
    required String partnerName,
    required double distanceKm,
    String vibe = 'Cozy & Romantic',
  }) async {
    final midLat = (myLat + partnerLat) / 2;
    final midLng = (myLng + partnerLng) / 2;

    // Concurrently fetch:
    // 1. Midpoint city reverse geocode
    // 2. Drive route via OSRM
    // 3. Live weather at midpoint via Open-Meteo
    // 4. Nearby cafes/spots via Overpass
    final geoFuture = _reverseGeocodeMidpoint(midLat, midLng);
    final driveFuture = _fetchDrive(myLat, myLng, partnerLat, partnerLng);
    final weatherFuture = _fetchWeather(midLat, midLng);
    final spotsFuture = _fetchSpots(midLat, midLng);

    // Wait for basic location context
    final results = await Future.wait([
      geoFuture,
      driveFuture,
      weatherFuture,
      spotsFuture,
    ]);

    final midCity = (results[0] as String).isNotEmpty
        ? results[0] as String
        : (distanceKm < 30 ? (myCity.isNotEmpty ? myCity : 'Nearby City') : 'Halfway Destination');

    final drive = results[1] as DriveRoute?;
    final weather = results[2] as MeetingWeather?;
    final spots = results[3] as List<MidpointSpot>;

    // Generate live AI itinerary with full context
    final itinerary = await generateAiItinerary(
      myName: myName,
      partnerName: partnerName,
      myCity: myCity,
      partnerCity: partnerCity,
      distanceKm: distanceKm,
      midpointCity: midCity,
      vibe: vibe,
    );

    // Build realistic transit estimates based on distance
    final transitEstimates = _buildTransitEstimates(distanceKm, myCity, partnerCity);

    return TravelRouteResult(
      drive: drive,
      itinerary: itinerary,
      weather: weather,
      nearbySpots: spots,
      transitEstimates: transitEstimates,
      midLat: midLat,
      midLng: midLng,
      midCity: midCity,
      distanceKm: distanceKm,
    );
  }

  /// High-speed AI Itinerary generation via Groq (qwen/qwen3.8-27b)
  Future<ReunionItinerary> generateAiItinerary({
    required String myName,
    required String partnerName,
    required String myCity,
    required String partnerCity,
    required double distanceKm,
    required String midpointCity,
    String vibe = 'Cozy & Romantic',
  }) async {
    final apiKey = AppConstants.groqApiKey;
    final isLocal = distanceKm < 35;

    final prompt = '''
Plan a warm, authentic, and organized 1-day romantic reunion itinerary for $myName and $partnerName.
Origin 1: $myCity
Origin 2: $partnerCity
Meeting Destination: $midpointCity
Distance Apart: ${distanceKm.toStringAsFixed(1)} km
Romantic Vibe: $vibe
Mode: ${isLocal ? 'Local Date & Meetup in the area' : 'Halfway Reunion Getaway'}

Return a valid JSON object matching this schema:
{
  "date_title": "Short romantic title (e.g. Cozy Sunset Reunion in $midpointCity)",
  "meetup_city": "$midpointCity",
  "romantic_vibe": "$vibe",
  "schedule": [
    {
      "time": "10:00 AM - 11:30 AM",
      "title": "Morning Reunion & Coffee",
      "location": "Specific cozy cafe or breakfast spot in or near $midpointCity",
      "description": "Heartwarming description of meeting up, tight hug, and ordering breakfast/chai.",
      "icon": "☕"
    },
    {
      "time": "12:00 PM - 02:30 PM",
      "title": "Shared Adventure & Fun",
      "location": "Specific park, heritage lane, bookshop or scenic walk",
      "description": "Fun activity to do together holding hands.",
      "icon": "🎡"
    },
    {
      "time": "04:30 PM - 06:00 PM",
      "title": "Golden Hour & Sunset",
      "location": "Specific viewpoint, terrace, or lakeside in $midpointCity",
      "description": "Peaceful sunset observation, sharing snacks and taking photos.",
      "icon": "🌅"
    },
    {
      "time": "07:00 PM - 09:30 PM",
      "title": "Intimate Dinner & Dessert",
      "location": "Specific romantic restaurant or rooftop spot",
      "description": "Candlelight meal celebrating your time together.",
      "icon": "🍽️"
    }
  ],
  "packing_tip": "One cute and practical tip on what to bring or wear.",
  "surprise_idea": "One sweet, memorable romantic surprise $myName can prepare for $partnerName."
}
Only output valid JSON. No conversational preamble or markdown backticks.
''';

    try {
      final resp = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'model': 'qwen/qwen3.8-27b',
          'messages': [
            {'role': 'system', 'content': 'You are a warm, personal AI romance and date planner. Output JSON only.'},
            {'role': 'user', 'content': prompt},
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.75,
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final content = data['choices']?[0]?['message']?['content']?.toString() ?? '';
        final parsed = jsonDecode(content) as Map<String, dynamic>;
        return ReunionItinerary.fromJson(parsed);
      }
    } catch (e) {
      debugPrint('[TravelRouteService] Live AI generation fallback: $e');
    }

    return _buildFallbackItinerary(myName, partnerName, midpointCity, vibe);
  }

  // ── OSRM Live Driving Route ───────────────────────────────────────────────
  Future<DriveRoute?> _fetchDrive(
    double lat1, double lng1,
    double lat2, double lng2,
  ) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$lng1,$lat1;$lng2,$lat2?overview=false',
      );
      final resp = await http
          .get(url, headers: {'User-Agent': 'PagesOfUsApp/1.0'})
          .timeout(const Duration(seconds: 6));
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
    } catch (_) {
      return null;
    }
  }

  // ── Open-Meteo Live Weather at Midpoint ───────────────────────────────────
  Future<MeetingWeather?> _fetchWeather(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,weather_code',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>?;
        if (current != null) {
          final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 26.0;
          final code = (current['weather_code'] as num?)?.toInt() ?? 0;

          String condition = 'Clear Sky';
          String icon = '☀️';
          String advice = 'Perfect sunny weather for outdoor walks!';

          if (code >= 1 && code <= 3) {
            condition = 'Pleasant & Mild';
            icon = '🌤️';
            advice = 'Comfortable weather for exploring together.';
          } else if (code >= 51 && code <= 67) {
            condition = 'Light Rain';
            icon = '🌧️';
            advice = 'Carry an umbrella for a cozy rain walk.';
          } else if (code >= 80) {
            condition = 'Breezy Showers';
            icon = '🌦️';
            advice = 'Great day for cozy indoor cafe hopping.';
          }

          return MeetingWeather(
            temperature: temp,
            condition: condition,
            icon: icon,
            advice: advice,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Overpass OpenStreetMap Spots ─────────────────────────────────────────
  Future<List<MidpointSpot>> _fetchSpots(double lat, double lng) async {
    try {
      final query =
          '[out:json][timeout:6];'
          '('
          'node[amenity=cafe](around:10000,$lat,$lng);'
          'node[leisure=park](around:10000,$lat,$lng);'
          'node[amenity=restaurant](around:10000,$lat,$lng);'
          ');'
          'out 6;';
      final url = Uri.parse('https://overpass-api.de/api/interpreter');
      final resp = await http
          .post(url, body: {'data': query})
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return _defaultSpots();

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final elements = data['elements'] as List? ?? [];
      final List<MidpointSpot> spots = [];

      for (final el in elements) {
        final m = el as Map<String, dynamic>;
        final hLat = (m['lat'] as num?)?.toDouble() ?? 0;
        final hLng = (m['lon'] as num?)?.toDouble() ?? 0;
        final tags = m['tags'] as Map<String, dynamic>? ?? {};
        final name = tags['name']?.toString() ?? '';
        if (name.isEmpty) continue;

        final amenity = tags['amenity']?.toString() ?? '';
        final leisure = tags['leisure']?.toString() ?? '';

        String cat = 'spot';
        String icon = '📍';
        if (amenity == 'cafe') {
          cat = 'Cozy Cafe';
          icon = '☕';
        } else if (leisure == 'park') {
          cat = 'Scenic Park';
          icon = '🌿';
        } else if (amenity == 'restaurant') {
          cat = 'Romantic Dining';
          icon = '🍽️';
        }

        final dist = _haversineKm(lat, lng, hLat, hLng);
        spots.add(MidpointSpot(
          name: name,
          category: cat,
          distanceKm: dist,
          icon: icon,
        ));
      }

      if (spots.isEmpty) return _defaultSpots();
      spots.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      return spots.take(4).toList();
    } catch (_) {
      return _defaultSpots();
    }
  }

  // ── Reverse Geocode Midpoint ───────────────────────────────────────────────
  Future<String> _reverseGeocodeMidpoint(double lat, double lng) async {
    try {
      final photonUrl = Uri.parse('https://photon.komoot.io/reverse?lat=$lat&lon=$lng');
      final resp = await http.get(photonUrl).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final props = features.first['properties'] as Map<String, dynamic>?;
          if (props != null) {
            final city = props['city'] ?? props['county'] ?? props['district'] ?? props['name'] ?? '';
            if (city.toString().trim().isNotEmpty) {
              return city.toString().trim();
            }
          }
        }
      }
    } catch (_) {}
    return '';
  }

  List<TransitEstimate> _buildTransitEstimates(double distanceKm, String city1, String city2) {
    if (distanceKm < 30) {
      return [
        const TransitEstimate(
          mode: 'Cab / Auto',
          duration: '35 - 50 mins',
          priceEstimate: '₹200 – ₹450',
          tip: 'Book via Uber / Ola for an effortless direct ride.',
          icon: '🚖',
        ),
        const TransitEstimate(
          mode: 'Local Train / Metro',
          duration: '25 - 40 mins',
          priceEstimate: '₹15 – ₹40',
          tip: 'Quick and avoids all peak road traffic.',
          icon: '🚇',
        ),
      ];
    } else if (distanceKm < 250) {
      final trainHours = (distanceKm / 55).round().clamp(1, 6);
      return [
        TransitEstimate(
          mode: 'Express Train',
          duration: '~${trainHours}h ${trainHours > 1 ? '15m' : '30m'}',
          priceEstimate: '₹150 – ₹600',
          tip: 'Check IRCTC for comfortable AC Chair Car seats.',
          icon: '🚆',
        ),
        TransitEstimate(
          mode: 'Intercity Bus',
          duration: '~${(trainHours * 1.3).round()} hours',
          priceEstimate: '₹250 – ₹550',
          tip: 'Regular departures throughout the morning.',
          icon: '🚌',
        ),
      ];
    } else {
      final trainHours = (distanceKm / 65).round().clamp(4, 24);
      return [
        const TransitEstimate(
          mode: 'Flight',
          duration: '1h 30m direct',
          priceEstimate: '₹3,200 – ₹5,500',
          tip: 'Best for flying across states to maximize reunion hours.',
          icon: '✈️',
        ),
        TransitEstimate(
          mode: 'Superfast Express',
          duration: '~$trainHours hours',
          priceEstimate: '₹600 – ₹2,200',
          tip: 'Overnight sleeper trains make travel feel like an adventure.',
          icon: '🚂',
        ),
      ];
    }
  }

  List<MidpointSpot> _defaultSpots() {
    return const [
      MidpointSpot(name: 'Acoustic Garden Cafe', category: 'Cozy Cafe', distanceKm: 1.2, icon: '☕'),
      MidpointSpot(name: 'Riverside Promenade', category: 'Scenic Park', distanceKm: 2.4, icon: '🌿'),
      MidpointSpot(name: 'The Rooftop Lantern', category: 'Romantic Dining', distanceKm: 3.1, icon: '🍽️'),
    ];
  }

  ReunionItinerary _buildFallbackItinerary(String myName, String partnerName, String city, String vibe) {
    return ReunionItinerary(
      title: 'Romantic Reunion in $city',
      meetupCity: city,
      romanticVibe: vibe,
      stops: [
        ReunionItineraryStop(
          time: '10:30 AM',
          title: 'The Reunion Hug & Warm Coffee',
          location: '$city Central Cafe',
          description: 'Meet up for fresh hot coffee, pastries, and a warm, long-awaited embrace.',
          icon: '☕',
        ),
        ReunionItineraryStop(
          time: '12:30 PM',
          title: 'Stroll & Shared Conversation',
          location: '$city Heritage Garden',
          description: 'Walk together holding hands, talking about everything you missed while apart.',
          icon: '🌿',
        ),
        ReunionItineraryStop(
          time: '04:30 PM',
          title: 'Golden Sunset & Photos',
          location: 'Scenic Viewpoint in $city',
          description: 'Watch the sun dip below the horizon, taking cute Polaroid photos together.',
          icon: '🌅',
        ),
        ReunionItineraryStop(
          time: '07:00 PM',
          title: 'Candlelight Dinner & Dessert',
          location: '$city Rooftop Bistro',
          description: 'Share a delicious meal with soft ambient music, making promises for next time.',
          icon: '🍽️',
        ),
      ],
      packingTip: 'Wear comfortable sneakers and bring a portable charger for plenty of photos.',
      surpriseIdea: 'Secretly buy a single stem of their favorite flower and give it right as you hug.',
    );
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lng2 - lng1) * p)) / 2;
    return 12742 * asin(sqrt(a.clamp(0.0, 1.0)));
  }
}
