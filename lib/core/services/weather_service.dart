import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherInfo {
  final double temperature;
  final int weatherCode;
  final bool isDay;
  final String condition;
  final String emoji;

  WeatherInfo({
    required this.temperature,
    required this.weatherCode,
    required this.isDay,
    required this.condition,
    required this.emoji,
  });

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? {};
    final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 22.0;
    final code = (current['weather_code'] as num?)?.toInt() ?? 0;
    final isDay = (current['is_day'] as num?)?.toInt() == 1;

    String condition = 'Clear Sky';
    String emoji = isDay ? '☀️' : '🌙';

    if (code >= 1 && code <= 3) {
      condition = 'Partly Cloudy';
      emoji = isDay ? '⛅' : '☁️';
    } else if (code >= 45 && code <= 48) {
      condition = 'Misty Fog';
      emoji = '🌫️';
    } else if (code >= 51 && code <= 67) {
      condition = 'Gentle Rain';
      emoji = '🌧️';
    } else if (code >= 71 && code <= 77) {
      condition = 'Soft Snow';
      emoji = '❄️';
    } else if (code >= 80 && code <= 82) {
      condition = 'Passing Showers';
      emoji = '🌦️';
    } else if (code >= 95) {
      condition = 'Thunderstorm';
      emoji = '⛈️';
    }

    return WeatherInfo(
      temperature: temp,
      weatherCode: code,
      isDay: isDay,
      condition: condition,
      emoji: emoji,
    );
  }
}

class WeatherService {
  static Future<WeatherInfo?> fetchWeather(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,weather_code,is_day',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return WeatherInfo.fromJson(data);
      }
    } catch (_) {}
    return null;
  }
}
