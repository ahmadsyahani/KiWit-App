import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class WeatherData {
  final double windSpeedKmH;
  final double temperature;
  final int humidity;
  final int weatherCode;
  final String condition;
  final DateTime updatedAt;

  const WeatherData({
    required this.windSpeedKmH,
    required this.temperature,
    required this.humidity,
    required this.weatherCode,
    required this.condition,
    required this.updatedAt,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    if (current is! Map) {
      throw const FormatException('Data cuaca tidak tersedia.');
    }
    final wind = current['wind_speed_10m'];
    final temperature = current['temperature_2m'];
    final humidity = current['relative_humidity_2m'];
    final weatherCode = current['weather_code'];
    if (wind is! num ||
        temperature is! num ||
        humidity is! num ||
        weatherCode is! num ||
        ![wind, temperature, humidity, weatherCode].every((n) => n.isFinite) ||
        wind < 0 ||
        humidity < 0 ||
        humidity > 100 ||
        humidity != humidity.round() ||
        weatherCode < 0 ||
        weatherCode != weatherCode.round()) {
      throw const FormatException('Data cuaca tidak lengkap atau tidak valid.');
    }
    final windSpeed = wind.toDouble();
    final temp = temperature.toDouble();
    final hum = humidity.toInt();
    final code = weatherCode.toInt();

    String parseCondition(int code) {
      if (code == 0) return 'Cerah';
      if (code == 1 || code == 2) return 'Cerah Berawan';
      if (code == 3) return 'Berawan';
      if (code >= 45 && code <= 48) return 'Berkabut';
      if (code >= 51 && code <= 57) return 'Gerimis';
      if (code >= 61 && code <= 67) return 'Hujan';
      if (code >= 71 && code <= 77 || code == 85 || code == 86) return 'Salju';
      if (code >= 80 && code <= 82) return 'Hujan Ringan';
      if (code >= 95) return 'Hujan Badai';
      return 'Kondisi cuaca belum dikenali';
    }

    return WeatherData(
      windSpeedKmH: windSpeed,
      temperature: temp,
      humidity: hum,
      weatherCode: code,
      condition: parseCondition(code),
      updatedAt: DateTime.now(),
    );
  }
}

class WeatherService {
  /// Fetch real-time weather & wind data for Surabaya from Open-Meteo API
  static Future<WeatherData?> fetchSurabayaWeather({
    double latitude = -7.2575,
    double longitude = 112.7521,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code&wind_speed_unit=kmh',
    );

    try {
      return await (() async {
        final request = await client.getUrl(uri);
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();
        if (response.statusCode != 200) return null;
        return WeatherData.fromJson(
          jsonDecode(responseBody) as Map<String, dynamic>,
        );
      })().timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WeatherService] Error fetching Open-Meteo weather: $e');
      }
    } finally {
      client.close(force: true);
    }

    return null;
  }
}
