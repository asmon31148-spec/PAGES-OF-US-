import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/weather_service.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/world_provider.dart';
import '../../../providers/auth_provider.dart';

class StageAtmosphereCard extends StatefulWidget {
  const StageAtmosphereCard({super.key});

  @override
  State<StageAtmosphereCard> createState() => _StageAtmosphereCardState();
}

class _StageAtmosphereCardState extends State<StageAtmosphereCard> {
  WeatherInfo? _weather;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWeather();
    });
  }

  Future<void> _loadWeather() async {
    try {
      final auth = context.read<AuthProvider>();
      final world = context.read<WorldProvider>();
      final partner = auth.partner;
      final isPaired = partner != null && partner.id.isNotEmpty;

      double? lat;
      double? lng;

      if (isPaired) {
        final partnerLoc = world.partnerLocation ??
            (partner.id.isNotEmpty ? world.getUserLocation(partner.id) : null);
        lat = partnerLoc?.lat;
        lng = partnerLoc?.lng;
      } else {
        // Fallback to my location only if in solo mode
        lat = world.myLocation?.lat;
        lng = world.myLocation?.lng;

        if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
          try {
            final pos = await Geolocator.getLastKnownPosition();
            if (pos != null) {
              lat = pos.latitude;
              lng = pos.longitude;
            }
          } catch (_) {}
        }
      }

      WeatherInfo? info;
      if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
        info = await WeatherService.fetchWeather(lat, lng);
      } else {
        info = isPaired ? world.partnerWeather : null;
      }

      if (mounted) {
        setState(() {
          _weather = info;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final auth = context.watch<AuthProvider>();
    final world = context.watch<WorldProvider>();

    final partner = auth.partner;
    final isPaired = partner != null && partner.id.isNotEmpty;
    final partnerLoc = isPaired
        ? (world.partnerLocation ?? (partner.id.isNotEmpty ? world.getUserLocation(partner.id) : null))
        : null;
    final myLoc = world.myLocation;

    if (_isLoading) {
      return Container(
        height: 64,
        margin: EdgeInsets.zero,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sageLight),
        ),
      );
    }

    final targetLoc = isPaired ? partnerLoc : myLoc;
    final hasGps = targetLoc != null && (targetLoc.lat != 0.0 || targetLoc.lng != 0.0);
    final WeatherInfo? liveWeather = isPaired ? world.partnerWeather : _weather;
    final bool hasRealWeather = hasGps && liveWeather != null;
    final weather = liveWeather;

    final title = isPaired
        ? "${partner.nickname}'s Atmosphere"
        : "Your Atmosphere";
    final locationSubtitle = isPaired
        ? (partnerLoc?.placeName?.isNotEmpty == true
            ? 'Over at ${partnerLoc!.placeName}'
            : 'Awaiting partner GPS signal')
        : (myLoc?.placeName?.isNotEmpty == true
            ? 'At ${myLoc!.placeName}'
            : 'Local sky & presence');

    // Living romantic atmosphere headline
    String romanticHook;
    final partnerName = partner?.nickname ?? 'Your partner';
    final city = partnerLoc?.placeName ?? '';
    if (isPaired) {
      if (!hasRealWeather || partnerLoc == null || (partnerLoc.lat == 0.0 && partnerLoc.lng == 0.0)) {
        romanticHook = 'Waiting for $partnerName to connect GPS atmosphere 🛰️';
      } else if ((weather!.weatherCode >= 51 && weather.weatherCode <= 67) || (weather.weatherCode >= 80 && weather.weatherCode <= 82)) {
        romanticHook = '$partnerName is resting under gentle rain ${city.isNotEmpty ? "in $city" : "today"} 🌧️';
      } else if (weather.weatherCode >= 95) {
        romanticHook = 'Thunderstorms rolling over $partnerName ${city.isNotEmpty ? "in $city" : ""} ⛈️';
      } else if (!weather.isDay) {
        romanticHook = '$partnerName is resting under the quiet night sky 🌙';
      } else if (weather.temperature >= 32.0) {
        romanticHook = '$partnerName is in warm afternoon sunshine ☀️';
      } else {
        romanticHook = '$partnerName is soaking in the calm daylight ${city.isNotEmpty ? "in $city" : "today"} 🌿';
      }
    } else {
      if (!hasRealWeather) {
        romanticHook = 'Enable GPS to connect to your local atmosphere 🌿';
      } else if (weather!.weatherCode >= 51) {
        romanticHook = 'Listening to soft rain falling outside 🌧️';
      } else if (!weather.isDay) {
        romanticHook = 'Resting under the calm night sky 🌙';
      } else {
        romanticHook = 'A peaceful, serene sanctuary day ☀️';
      }
    }

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Weather Emoji Icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.64),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.16) : Colors.white.withOpacity(0.75),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              hasRealWeather ? weather!.emoji : '🛰️',
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 12),

          // Detailed Weather & Atmosphere Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Tag: Partner's Atmosphere · Location
                Row(
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: isPaired ? AppColors.terra : AppColors.sage,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '· $locationSubtitle',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Primary Temp & Condition
                Text(
                  hasRealWeather
                      ? '${weather!.temperature.round()}°C · ${weather.condition}'
                      : '--°C · Awaiting Telemetry',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkInk : AppColors.lightInk,
                  ),
                ),
                const SizedBox(height: 2),

                // Emotional Romantic Headline
                Text(
                  romanticHook,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.terra.withOpacity(0.9) : AppColors.terra,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Detailed Weather Metrics: Feels Like, Humidity, Wind
                Text(
                  hasRealWeather
                      ? 'Feels like ${weather!.apparentTemperature.round()}°C  •  💧 ${weather.humidity}%  •  💨 ${weather.windSpeed.round()} km/h'
                      : 'Feels like --°C  •  💧 --%  •  💨 -- km/h',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Daylight / Nightfall Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.64),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.16) : Colors.white.withOpacity(0.75),
                width: 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasRealWeather
                      ? (weather!.isDay ? '☀️ Daylight' : '🌙 Nightfall')
                      : '🛰️ Standby',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.terra,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
