import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/weather_service.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/world_provider.dart';

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
      final world = context.read<WorldProvider>();
      double? lat = world.myLocation?.lat;
      double? lng = world.myLocation?.lng;

      if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
        try {
          final pos = await Geolocator.getLastKnownPosition();
          if (pos != null) {
            lat = pos.latitude;
            lng = pos.longitude;
          }
        } catch (_) {}
      }

      WeatherInfo? info;
      if (lat != null && lng != null && (lat != 0.0 || lng != 0.0)) {
        info = await WeatherService.fetchWeather(lat, lng);
      } else {
        info = world.partnerWeather ??
            WeatherInfo(
              temperature: 24.0,
              weatherCode: 0,
              isDay: DateTime.now().hour >= 6 && DateTime.now().hour < 19,
              condition: 'Sanctuary Calm',
              emoji: '✨',
            );
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

    if (_isLoading) {
      return Container(
        height: 64,
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(
            top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sageLight),
        ),
      );
    }

    final weather = _weather ??
        WeatherInfo(
          temperature: 24.0,
          weatherCode: 0,
          isDay: true,
          condition: 'Sanctuary Calm',
          emoji: '🌿',
        );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                weather.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${weather.temperature.round()}°C · ${weather.condition}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                    ),
                  ),
                  Text(
                    'Our shared atmosphere',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              weather.isDay ? 'Daylight ✦' : 'Nightfall ✦',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.terra,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
