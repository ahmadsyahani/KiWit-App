/// A location chosen on the map or obtained from the device.
class InspectionLocation {
  const InspectionLocation({
    required this.latitude,
    required this.longitude,
    this.address = '',
  });

  final double latitude;
  final double longitude;
  final String address;

  bool get isValid => validInspectionCoordinates(latitude, longitude);

  String get label => address.trim().isNotEmpty
      ? address.trim()
      : 'Titik peta (${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)})';
}

bool validInspectionCoordinates(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;
