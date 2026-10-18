import 'dart:convert';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import '../../domain/models/inspection_location.dart';

Future<InspectionLocation?> resolveScanLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8),
      ),
    );
    var location = InspectionLocation(latitude: position.latitude, longitude: position.longitude);
    if (!location.isValid) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'json', 'lat': position.latitude.toString(),
        'lon': position.longitude.toString(), 'zoom': '18',
      });
      // Reverse geocoding must not hold usable GPS coordinates behind a slow
      // network request. Its entire budget is two seconds.
      final address = await (() async {
        final request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.userAgentHeader, 'KiWit/1.0 (Tree Inspection)');
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          return (jsonDecode(body) as Map<String, dynamic>)['display_name'] as String?;
        }
        return null;
      })().timeout(const Duration(seconds: 2));
      if (address != null && address.trim().isNotEmpty) {
        location = InspectionLocation(latitude: position.latitude,
            longitude: position.longitude, address: address);
      }
    } catch (_) {
      // GPS coordinates remain usable without an internet connection.
    } finally {
      client.close(force: true);
    }
    return location;
  } catch (_) {
    return null;
  }
}
