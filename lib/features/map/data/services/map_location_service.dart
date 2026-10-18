import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../scan/domain/models/inspection_location.dart';

/// Requests permission only when the map needs the device's current position.
Future<LatLng> resolveMapLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const FormatException('Aktifkan GPS, lalu tekan Lokasi saya.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const FormatException(
      'Izinkan lokasi melalui pengaturan aplikasi, lalu tekan Lokasi saya.',
    );
  }
  if (permission != LocationPermission.always &&
      permission != LocationPermission.whileInUse) {
    throw const FormatException(
      'Izin lokasi belum diberikan. Tekan Lokasi saya untuk mencoba lagi.',
    );
  }
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 10),
    ),
  );
  if (!validInspectionCoordinates(position.latitude, position.longitude)) {
    throw const FormatException('Lokasi belum valid. Coba Lokasi saya lagi.');
  }
  return LatLng(position.latitude, position.longitude);
}
