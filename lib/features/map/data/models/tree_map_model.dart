import '../../../../core/widgets/risk_badge.dart';

class TreeMapModel {
  final String id;
  final String treeCode;
  final String speciesName;
  final String latinName;
  final double latitude;
  final double longitude;
  final String address;
  final String rayon;
  final RiskLevel riskLevel;
  final String healthStatus;
  final double heightMeters;
  final double diameterCm;
  final double dangerRadiusMeters;
  final String lastInspected;

  const TreeMapModel({
    required this.id,
    required this.treeCode,
    required this.speciesName,
    required this.latinName,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.rayon,
    required this.riskLevel,
    required this.healthStatus,
    required this.heightMeters,
    required this.diameterCm,
    this.dangerRadiusMeters = 18.0,
    required this.lastInspected,
  });

  factory TreeMapModel.fromJson(Map<String, dynamic> json) {
    RiskLevel parsedRisk = RiskLevel.rendah;
    final riskStr = (json['risk_level'] as String? ?? 'Low').toLowerCase();
    if (riskStr.contains('kritis') || riskStr.contains('critical')) {
      parsedRisk = RiskLevel.kritis;
    } else if (riskStr.contains('tinggi') || riskStr.contains('high')) {
      parsedRisk = RiskLevel.tinggi;
    } else if (riskStr.contains('sedang') || riskStr.contains('medium')) {
      parsedRisk = RiskLevel.sedang;
    }

    return TreeMapModel(
      id: json['id'] as String? ?? '',
      treeCode: json['tree_code'] as String? ?? 'TR-001',
      speciesName: json['species_name'] as String? ?? 'Pohon Pelindung',
      latinName: json['latin_name'] as String? ?? '',
      latitude: (json['lat'] ?? json['latitude'] ?? -7.2850) as double,
      longitude: (json['lng'] ?? json['longitude'] ?? 112.7950) as double,
      address: json['address'] as String? ?? 'Surabaya',
      rayon: json['rayon'] as String? ?? 'Rayon 3 — Sukolilo',
      riskLevel: parsedRisk,
      healthStatus: json['health_status'] as String? ?? 'Sehat',
      heightMeters: (json['height_meters'] as num?)?.toDouble() ?? 12.0,
      diameterCm: (json['diameter_cm'] as num?)?.toDouble() ?? 45.0,
      dangerRadiusMeters: (json['danger_radius_meters'] as num?)?.toDouble() ?? 18.0,
      lastInspected: json['last_inspected'] as String? ?? 'Baru saja',
    );
  }
}
