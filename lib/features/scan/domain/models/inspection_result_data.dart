class InspectionResultData {
  final String imagePath;
  final int healthScore;
  final String riskStatus;
  final double ronggaBatang;
  final double sudutKemiringan;
  final double diameter;
  final bool isJamurPelapuk;
  final String inspectionId;
  final String treeSpecies;
  final String detectedCondition;
  final String locationAddress;
  final DateTime scanTimestamp;
  final double? latitude;
  final double? longitude;

  // Spesifikasi AI & ISA TRAQ (requirements.md)
  final double persentaseLuka;
  final String failurePotential; // 'Improbable', 'Possible', 'Probable', 'Imminent'
  final String environmentalImpact; // 'Low', 'Medium', 'High'
  final String riskAction; // 'Aman', 'Perlu Dipantau', 'Tindak Lanjuti', 'Tebang Segera!'
  final int healthyPixelCount;
  final int defectPixelCount;

  InspectionResultData({
    required this.imagePath,
    required this.healthScore,
    required this.riskStatus,
    required this.ronggaBatang,
    required this.sudutKemiringan,
    required this.diameter,
    required this.isJamurPelapuk,
    required this.inspectionId,
    this.treeSpecies = 'Pohon Mahoni',
    required this.detectedCondition,
    required this.locationAddress,
    required this.scanTimestamp,
    this.latitude,
    this.longitude,
    double? persentaseLuka,
    this.failurePotential = 'Improbable',
    this.environmentalImpact = 'Medium',
    this.riskAction = 'Aman',
    this.healthyPixelCount = 0,
    this.defectPixelCount = 0,
  }) : persentaseLuka = persentaseLuka ?? ronggaBatang;

  InspectionResultData copyWith({
    String? imagePath,
    int? healthScore,
    String? riskStatus,
    double? ronggaBatang,
    double? sudutKemiringan,
    double? diameter,
    bool? isJamurPelapuk,
    String? inspectionId,
    String? treeSpecies,
    String? detectedCondition,
    String? locationAddress,
    DateTime? scanTimestamp,
    double? latitude,
    double? longitude,
    double? persentaseLuka,
    String? failurePotential,
    String? environmentalImpact,
    String? riskAction,
    int? healthyPixelCount,
    int? defectPixelCount,
  }) {
    return InspectionResultData(
      imagePath: imagePath ?? this.imagePath,
      healthScore: healthScore ?? this.healthScore,
      riskStatus: riskStatus ?? this.riskStatus,
      ronggaBatang: ronggaBatang ?? this.ronggaBatang,
      sudutKemiringan: sudutKemiringan ?? this.sudutKemiringan,
      diameter: diameter ?? this.diameter,
      isJamurPelapuk: isJamurPelapuk ?? this.isJamurPelapuk,
      inspectionId: inspectionId ?? this.inspectionId,
      treeSpecies: treeSpecies ?? this.treeSpecies,
      detectedCondition: detectedCondition ?? this.detectedCondition,
      locationAddress: locationAddress ?? this.locationAddress,
      scanTimestamp: scanTimestamp ?? this.scanTimestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      persentaseLuka: persentaseLuka ?? this.persentaseLuka,
      failurePotential: failurePotential ?? this.failurePotential,
      environmentalImpact: environmentalImpact ?? this.environmentalImpact,
      riskAction: riskAction ?? this.riskAction,
      healthyPixelCount: healthyPixelCount ?? this.healthyPixelCount,
      defectPixelCount: defectPixelCount ?? this.defectPixelCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'healthScore': healthScore,
    'riskStatus': riskStatus,
    'ronggaBatang': ronggaBatang,
    'sudutKemiringan': sudutKemiringan,
    'diameter': diameter,
    'isJamurPelapuk': isJamurPelapuk,
    'inspectionId': inspectionId,
    'treeSpecies': treeSpecies,
    'detectedCondition': detectedCondition,
    'locationAddress': locationAddress,
    'scanTimestamp': scanTimestamp.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'persentaseLuka': persentaseLuka,
    'failurePotential': failurePotential,
    'environmentalImpact': environmentalImpact,
    'riskAction': riskAction,
    'healthyPixelCount': healthyPixelCount,
    'defectPixelCount': defectPixelCount,
  };

  factory InspectionResultData.fromJson(Map<String, dynamic> json) {
    final timestamp = DateTime.tryParse(json['scanTimestamp'] as String? ?? '');
    if (timestamp == null) {
      throw const FormatException('Waktu inspeksi tidak valid.');
    }
    return InspectionResultData(
      imagePath: json['imagePath'] as String? ?? '',
      healthScore: (json['healthScore'] as num).toInt(),
      riskStatus: json['riskStatus'] as String,
      ronggaBatang: (json['ronggaBatang'] as num).toDouble(),
      sudutKemiringan: (json['sudutKemiringan'] as num).toDouble(),
      diameter: (json['diameter'] as num).toDouble(),
      isJamurPelapuk: json['isJamurPelapuk'] as bool,
      inspectionId: json['inspectionId'] as String,
      treeSpecies: json['treeSpecies'] as String,
      detectedCondition: json['detectedCondition'] as String,
      locationAddress: json['locationAddress'] as String,
      scanTimestamp: timestamp.toLocal(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      persentaseLuka: (json['persentaseLuka'] as num?)?.toDouble(),
      failurePotential: json['failurePotential'] as String? ?? 'Improbable',
      environmentalImpact: json['environmentalImpact'] as String? ?? 'Medium',
      riskAction: json['riskAction'] as String? ?? 'Aman',
      healthyPixelCount: (json['healthyPixelCount'] as num?)?.toInt() ?? 0,
      defectPixelCount: (json['defectPixelCount'] as num?)?.toInt() ?? 0,
    );
  }
}
