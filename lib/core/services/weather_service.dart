import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class WeatherData {
  final double windSpeedKmH;
  final double temperature;
  final int humidity;
  final int weatherCode;
  final String condition;

  const WeatherData({
    required this.windSpeedKmH,
    required this.temperature,
    required this.humidity,
    required this.weatherCode,
    required this.condition,
  });

  factory WeatherData.defaultSurabaya() {
    return const WeatherData(
      windSpeedKmH: 18.5,
      temperature: 31.0,
      humidity: 68,
      weatherCode: 1,
      condition: 'Cerah Berawan',
    );
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? {};
    final windSpeed = (current['wind_speed_10m'] as num?)?.toDouble() ?? 18.5;
    final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 31.0;
    final hum = (current['relative_humidity_2m'] as num?)?.toInt() ?? 68;
    final code = (current['weather_code'] as num?)?.toInt() ?? 1;

    String parseCondition(int code) {
      if (code == 0) return 'Cerah';
      if (code == 1 || code == 2) return 'Cerah Berawan';
      if (code == 3) return 'Berawan';
      if (code >= 45 && code <= 48) return 'Berkabut';
      if (code >= 51 && code <= 67) return 'Gerimis';
      if (code >= 80 && code <= 82) return 'Hujan Ringan';
      if (code >= 95) return 'Hujan Badai';
      return 'Cerah Berawan';
    }

    return WeatherData(
      windSpeedKmH: windSpeed,
      temperature: temp,
      humidity: hum,
      weatherCode: code,
      condition: parseCondition(code),
    );
  }
}

class WeatherService {
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);

  /// Fetch real-time weather & wind data for Surabaya from Open-Meteo API
  static Future<WeatherData> fetchSurabayaWeather({
    double latitude = -7.2575,
    double longitude = 112.7521,
  }) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code&wind_speed_unit=kmh',
    );

    try {
      final request = await _client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        return WeatherData.fromJson(json);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WeatherService] Error fetching Open-Meteo weather: $e');
      }
    }

    return WeatherData.defaultSurabaya();
  }
}
